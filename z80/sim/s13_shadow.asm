; s13_shadow.asm - Scenario 13: Shadow Registers (Alternate Register Set)
; ================================================================
; Z80はメインレジスタとは別に「裏レジスタ（shadow/alternate）」を持つ:
;
;   メイン:  A  F  B  C  D  E  H  L
;   裏  :  A' F' B' C' D' E' H' L'
;
; 2つの命令で瞬時に入れ替え可能:
;   EXX         → BC↔BC', DE↔DE', HL↔HL' (同時swap)
;   EX AF,AF'   → AF↔AF'
;
; 代表的な用途:
;   - 割り込みハンドラ(ISR)での高速コンテキスト保存
;     (PUSH/POP不要で2命令で保存・復元)
;   - 2つの計算コンテキストの切替
;   - スタックを使わない一時変数の退避
;
; 注意: IX/IY, SPには裏レジスタがない
; ================================================================

	org 0x0100

_start:
	; ---- タイトル ----
	ld	hl, msg_title
	call	print_str
	call	newline

	; ============================================================
	; Step 1: メインレジスタに値をセットして表示
	; ============================================================
	ld	hl, msg_step1
	call	print_str
	call	newline

	ld	bc, 0x1234		; BC = 0x1234
	ld	de, 0x5678		; DE = 0x5678
	ld	hl, 0x9ABC		; HL = 0x9ABC
	ld	a, 0x42		; A  = 0x42
	call	save_regs		; メモリに保存

	ld	hl, msg_main
	call	show_regs		; 保存値を表示

	; ============================================================
	; Step 2: EXX + EX AF,AF' で裏レジスタに切替え
	; ============================================================
	; swap前にメモリから正しい値をリロード(表示でHLが変更されるため)
	ld	hl, msg_exx
	call	print_str
	call	newline

	call	load_regs		; メモリから復元: 1234/5678/9ABC/42

	exx			; BC↔BC', DE↔DE', HL↔HL'
	ex	af, af'		; AF↔AF'
	; → シャドウに 1234/5678/9ABC/42 が退避された
	; → メインにはシャドウの初期値(0)が現れた

	; 新しい値をセット(メインとして見えているレジスタ)
	ld	bc, 0xABCD
	ld	de, 0xEF01
	ld	hl, 0x2345
	ld	a, 0x99
	call	save_regs

	ld	hl, msg_shadow
	call	show_regs

	; ============================================================
	; Step 3: もう一度swapしてメインに戻す
	; ============================================================
	ld	hl, msg_back
	call	print_str
	call	newline

	call	load_regs		; メモリから復元: ABCD/EF01/2345/99

	exx			; シャドウ←ABCD/EF01/2345/99
	ex	af, af'
	; → メインに 1234/5678/9ABC/42 が復元された!

	call	save_regs
	ld	hl, msg_restored
	call	show_regs

	; ============================================================
	; Step 4: ISR風コンテキスト保存パターン
	; ============================================================
	ld	hl, msg_step4
	call	print_str
	call	newline

	; 「メインプログラム」の値をセット
	ld	bc, 0xAAAA
	ld	de, 0xBBBB
	ld	hl, 0xCCCC
	ld	a, 0xDD
	call	save_regs

	ld	hl, msg_pre_isr
	call	show_regs

	; --- ISR開始: 2命令で全レジスタ保存! (スタック不要) ---
	call	load_regs		; AAAA/BBBB/CCCC/DD をリロード

	exx			; BC/DE/HL → 裏へ退避
	ex	af, af'		; AF → 裏へ退避

	; ISR本体: レジスタを自由に使用
	ld	bc, 0x1111
	ld	de, 0x2222
	ld	hl, 0x3333
	ld	a, 0x44
	call	save_regs

	ld	hl, msg_in_isr
	call	show_regs

	; --- ISR終了: 2命令で全レジスタ復元! ---
	call	load_regs		; 1111/2222/3333/44 をリロード

	exx			; BC/DE/HL ← 裏から復元
	ex	af, af'		; AF ← 裏から復元
	; → AAAA/BBBB/CCCC/DD が復元された!

	call	save_regs
	ld	hl, msg_post_isr
	call	show_regs

	ret

; ================================================================
; save_regs: BC, DE, HL, A をメモリに保存
; ================================================================
save_regs:
	ld	(save_bc), bc
	ld	(save_de), de
	ld	(save_hl), hl
	ld	(save_a), a
	ret

; ================================================================
; load_regs: メモリから BC, DE, HL, A を復元
; ================================================================
load_regs:
	ld	bc, (save_bc)
	ld	de, (save_de)
	ld	hl, (save_hl)
	ld	a, (save_a)
	ret

; ================================================================
; show_regs: メモリに保存された値をラベル付きで表示
;   入力: HL = ラベルメッセージのアドレス
; ================================================================
show_regs:
	call	print_str

	; BC表示
	ld	hl, msg_bc
	call	print_str
	ld	a, (save_bc+1)		; B (Z80はリトルエンディアン)
	call	print_hex8
	ld	a, (save_bc)		; C
	call	print_hex8
	call	newline

	; DE表示
	ld	hl, msg_de
	call	print_str
	ld	a, (save_de+1)		; D
	call	print_hex8
	ld	a, (save_de)		; E
	call	print_hex8
	call	newline

	; HL表示
	ld	hl, msg_hl
	call	print_str
	ld	a, (save_hl+1)		; H
	call	print_hex8
	ld	a, (save_hl)		; L
	call	print_hex8
	call	newline

	; A表示
	ld	hl, msg_a
	call	print_str
	ld	a, (save_a)
	call	print_hex8
	call	newline

	call	newline
	ret

; ================================================================
; 共通サブルーチン
; ================================================================

print_str:
	push	af
	push	bc
	push	de
.ps_loop:
	ld	a, (hl)
	cp	'$'
	jr	z, .ps_done
	ld	c, 2
	ld	e, a
	call	0x0005
	inc	hl
	jr	.ps_loop
.ps_done:
	pop	de
	pop	bc
	pop	af
	ret

print_hex8:
	push	bc
	ld	b, a
	; 上位ニブル
	rrca
	rrca
	rrca
	rrca
	call	hex_nibble
	ld	c, 2
	ld	e, a
	call	0x0005
	; 下位ニブル
	ld	a, b
	call	hex_nibble
	ld	c, 2
	ld	e, a
	call	0x0005
	pop	bc
	ret

hex_nibble:
	and	0x0F
	cp	10
	jr	c, .hn_dec
	add	'A' - 10
	ret
.hn_dec:
	add	'0'
	ret

newline:
	push	af
	push	bc
	push	de
	ld	c, 2
	ld	e, 13
	call	0x0005
	ld	c, 2
	ld	e, 10
	call	0x0005
	pop	de
	pop	bc
	pop	af
	ret

; ================================================================
; データセクション
; ================================================================

; レジスタ値保存用(リトルエンディアン: low byte, high byte)
save_bc:	defw	0
save_de:	defw	0
save_hl:	defw	0
save_a:		defb	0

; メッセージ
msg_title:	defm	"=== s13: Shadow Registers ===$"
msg_step1:	defm	"--- Step 1: Set main registers ---$"
msg_main:	defm	"Main:     $"
msg_exx:	defm	"--- Step 2: EXX + EX AF,AF' ---$"
msg_shadow:	defm	"Shadow:   $"
msg_back:	defm	"--- Step 3: Swap back to main ---$"
msg_restored:	defm	"Restored: $"
msg_step4:	defm	"--- Step 4: ISR context save/restore ---$"
msg_pre_isr:	defm	"Pre-ISR:  $"
msg_in_isr:	defm	"In ISR:   $"
msg_post_isr:	defm	"Post-ISR: $"

msg_bc:		defm	"  BC=$"
msg_de:		defm	"  DE=$"
msg_hl:		defm	"  HL=$"
msg_a:		defm	"  A=$"
