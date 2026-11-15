; boot.asm - ブートセクタ + 保護モード移行スタブ
; =========================================================
; Learning objectives:
;   - ブートセクタ構造 (0x7C00 ロード, 0xAA55 署名)
;   - セグメント/スタック初期化とブートドライブ番号 (DL) の保存
;   - INT 13h AH=02h による CHS 指定ディスク読み込み (1 セクタずつ + 再試行)
;   - A20 (port 0x92) と GDT による 32-bit 保護モード移行
;   - リンカシンボル (__bss_start/__bss_end) を使った .bss のゼロ初期化
;
; 配置 (linker.ld の ASSERT が保証):
;   0x7C00-0x7DFF  section .boot  ブートセクタ (16-bit, 署名は 0x7DFE)
;   0x7E00-0x7FFF  section .stub  移行スタブ (16-bit で開始し途中から 32-bit)
;   0x8000-        section .text  シナリオ本体 (_start)
;
; ビルド: nasm -f elf32 boot.asm -o boot.o
; リンク: ld.lld -m elf_i386 -T linker.ld -o <S>.bin boot.o <S>.o

cpu 386

extern _start           ; シナリオのエントリポイント (linker.ld が 0x8000 に配置)
extern __bss_start      ; .bss 先頭 (linker.ld 定義)
extern __bss_end        ; .bss 終端 (linker.ld 定義)

; --- 1.44MB フロッピーのジオメトリ ---
SECTORS_PER_TRACK equ 18       ; 1 トラックのセクタ数
HEADS             equ 2        ; ヘッド数
; LBA と CHS の対応 (LBA 0 = シリンダ 0 / ヘッド 0 / セクタ 1):
;   cyl  = LBA / (HEADS * SECTORS_PER_TRACK) = LBA / 36   (0 始まり)
;   head = (LBA / SECTORS_PER_TRACK) % HEADS = (LBA / 18) % 2
;   sec  = LBA % SECTORS_PER_TRACK + 1 = LBA % 18 + 1     (セクタ番号だけ 1 始まり)
LBA_START  equ 1               ; 読み込み開始 LBA (= ディスク上のセクタ 2)
LBA_COUNT  equ 64              ; 読み込みセクタ数 (64 x 512 = 32KB)

; ----------------------------------------------------------------
; section .boot: 16-bit ブートコード (0x7C00)
; ----------------------------------------------------------------
section .boot
bits 16
boot_entry:
    ; SeaBIOS は 512 バイトを 0000:7C00 (BIOS により 07C0:0000 の場合もあり)
    ; にロードし、DL = ブートドライブ番号で跳んでくる。
    ; far jmp で CS を 0 に正規化してから各セグメントを初期化する。
    jmp  0x0000:.init
.init:
    cli                        ; 割り込み禁止
    xor  ax, ax
    mov  ds, ax                ; DS = 0
    mov  es, ax                ; ES = 0 (INT 13h バッファのセグメント)
    mov  ss, ax                ; SS = 0
    mov  sp, 0x7C00            ; SP = ブートセクタ直下 (下方成長)
    cld                        ; DF = 0 (文字列操作は正向き)
    mov  [boot_drive], dl      ; BIOS から受け取ったブートドライブ番号を保存

    ; --- INT 13h AH=02h: セクタ 2 から 64 セクタを 0000:7E00 へロード ---
    ; 1 回の INT 13h で 1 セクタだけ読み、CHS を自前で計算して更新する。
    mov  word [lba], LBA_START ; 次に読む LBA
    mov  word [remain], LBA_COUNT ; 残りセクタ数
    mov  bx, 0x7E00            ; ES:BX = 0000:7E00 (転送先)
.read_next:
    cmp  word [remain], 0
    je   .loaded               ; 指定セクタ数を読み終えた
    mov  si, 4                 ; SI = 残り試行回数 (初回 + 再試行 3 回)
.read_try:
    ; LBA → CHS 変換。INT 13h が AX/CX/DX を壊すため毎回再計算する。
    mov  ax, [lba]
    xor  dx, dx
    mov  cx, HEADS * SECTORS_PER_TRACK  ; 36
    div  cx                    ; AX = cyl, DX = LBA % 36
    push ax                    ; シリンダを保存 (下の div が CX ごと CH を壊すため)
    mov  ax, dx
    xor  dx, dx
    mov  cx, SECTORS_PER_TRACK ; 18
    div  cx                    ; AX = head, DX = LBA % 18
    mov  dh, al                ; DH = ヘッド
    inc  dx                    ; セクタ番号は 1 始まり
    mov  cl, dl                ; CL = セクタ番号 (1 始まり)
    pop  ax                    ; AX = シリンダ
    mov  ch, al                ; CH = シリンダ (0 始まり)
    mov  dl, [boot_drive]      ; DL = ドライブ番号
    mov  ah, 0x02              ; AH = 機能番号: セクタ読み込み
    mov  al, 1                 ; AL = 読み込むセクタ数 (毎回 1 セクタ)
    int  0x13
    jnc  .read_ok              ; CF = 0 なら成功
    xor  ah, ah                ; AH = 0: ディスクリセット (エラー回復)
    mov  dl, [boot_drive]      ; 読み込み失敗後も対象ドライブを再指定
    int  0x13
    dec  si
    jnz  .read_try             ; 試行回数が残っていればリトライ
    jmp  disk_error            ; 初回 + 再試行 3 回すべて失敗: 通知して停止
.read_ok:
    add  bx, 512               ; 転送先を 1 セクタ分進める
    inc  word [lba]
    dec  word [remain]
    jmp  .read_next
.loaded:
    ; 読み込んだ移行スタブ (0000:7E00) へ far jmp。
    ; .stub の配置先 0x7E00 は linker.ld の ASSERT が保証する。
    jmp  0x0000:0x7E00

; --- ディスク読み込み失敗: COM1 へエラーメッセージを出力して停止 ---
disk_error:
    mov  si, msg_disk_error
.print:
    lodsb                      ; AL = [DS:SI], SI++
    or   al, al                ; NULL 終端?
    jz   .halt
    call uart_putc16
    jmp  .print
.halt:
    cli
    hlt                        ; 停止 (以後戻らない)
    jmp  .halt                 ; NMI で再開しても再度停止

; uart_putc16: AL の 1 文字を COM1 (16550, I/O 0x3F8) へ出力 (16-bit 版)
uart_putc16:
    push dx
    push ax
    mov  dx, 0x3FD             ; LSR (ラインステータスレジスタ)
.wait:
    in   al, dx
    test al, 0x20              ; bit 5 = THRE (送信保持レジスタ空)
    jz   .wait
    mov  dx, 0x3F8             ; THR (送信保持レジスタ)
    pop  ax
    out  dx, al
    pop  dx
    ret

; --- .boot 内データ (DS = 0 でアクセス) ---
boot_drive     db 0            ; ブートドライブ番号 (DL) の保存先
lba            dw 0            ; 次に読む LBA
remain         dw 0            ; 残りセクタ数
msg_disk_error db "DISK LOAD ERROR", 13, 10, 0

times 510-($-$$) db 0          ; 510 バイトまでゼロ埋め
dw 0xAA55                      ; ブートシグネチャ (0x7DFE に配置)

; ----------------------------------------------------------------
; section .stub: 保護モード移行スタブ (0x7E00, 最大 512 バイト)
; ----------------------------------------------------------------
section .stub
bits 16
stub_entry:
    ; --- A20 を有効化 (Fast Gate, port 0x92) ---
    ; bit 1 = A20 enable。bit 0 はファストリセットビットなので絶対に立てない。
    in   al, 0x92
    or   al, 0x02
    and  al, 0xFE
    out  0x92, al

    cli                        ; 割り込み禁止 (IDT 未構築 — 以後 STI しない)
    lgdt [gdt_descriptor]      ; GDT をロード
    mov  eax, cr0
    or   eax, 1                ; CR0.PE = 1: 保護モード有効化
    mov  cr0, eax
    jmp  0x08:stub_pm          ; far jmp: CS をコードセレクタへ + パイプライン flush

bits 32
stub_pm:
    mov  ax, 0x10              ; データセグメントセレクタ
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  esp, 0x90000          ; スタックトップ (0x90000 から下方成長)
    cld                        ; DF = 0

    ; --- .bss をゼロ初期化 (リンカシンボル __bss_start .. __bss_end) ---
    mov  edi, __bss_start
    mov  ecx, __bss_end
    sub  ecx, edi              ; ECX = .bss のバイト数
    xor  al, al
    rep  stosb                 ; [ES:EDI] = AL を ECX 回書き込み (ES はフラット)

    jmp  _start                ; 0x8000 のシナリオエントリへ

; --- GDT: null + コードセグメント (0x08, 32-bit) + データセグメント (0x10) ---
align 8
gdt:
    dq 0x0000000000000000      ; 0x00: null セグメント
    dq 0x00CF9A000000FFFF      ; 0x08: コード base=0 limit=4G G=1 D=1 P=1 実行/読出
    dq 0x00CF92000000FFFF      ; 0x10: データ base=0 limit=4G G=1 B=1 P=1 読出/書込
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt - 1       ; GDT リミット (バイト数 - 1)
    dd gdt                     ; GDT の線形アドレス (リンカが 0x7Exx に確定)
