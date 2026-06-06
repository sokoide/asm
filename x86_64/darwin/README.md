# macOS x86_64 (64-bit) Hello World

macOS 上で x86_64 (AMD64) アセンブリ言語を学ぶための最小限の Hello World。NASM でアセンブルし、`syscall` 命令でシステムコールを呼び出す。

## ビルド & 実行

```sh
make       # アセンブル + リンク
./hello    # 実行
make clean # 掃除
```

## コード解説

```asm
global _main

section .text

_main:
    ; write(1, msg, len)
    mov     rax, 0x2000004      ; SYS_write = 4 | BSD クラスフラグ
    mov     rdi, 1              ; 第1引数: fd = stdout
    lea     rsi, [rel msg]      ; 第2引数: 文字列アドレス (RIP 相対)
    mov     rdx, len            ; 第3引数: 書き込むバイト数
    syscall                     ; システムコール呼び出し

    ; exit(0)
    mov     rax, 0x2000001      ; SYS_exit
    xor     rdi, rdi            ; 第1引数: exit code 0
    syscall
```

### syscall 命令

`syscall` 命令でカーネルに処理を依頼する。macOS x86_64 では BSD システムコールであることを示すフラグ `0x20000000` を番号に加算する必要がある。

### 呼び出し規約 (System V AMD64 ABI)

macOS x86_64 は **System V AMD64 ABI** に従う。

| 引数 | レジスタ | 意味               |
| :--- | :---     | :---               |
| 第1  | rdi      | 第1引数            |
| 第2  | rsi      | 第2引数            |
| 第3  | rdx      | 第3引数            |
| 第4  | rcx      | 第4引数            |
| 第5  | r8       | 第5引数            |
| 第6  | r9       | 第6引数            |
| 番号 | rax      | システムコール番号 |

### RIP 相対アドレッシング

位置独立コード (PIC) では、データ参照に RIP 相対アドレッシングを使う。

```asm
lea     rsi, [rel msg]      ; 推奨: RIP 相対
; または
lea     rsi, [msg]          ; デフォルトでは RIP 相対 (NASM macho64)
```

### システムコール番号

| 番号      | 名前  | 引数                                 | 説明             |
| :---      | :---  | :---                                 | :---             |
| 0x2000001 | exit  | `rdi` = exit code                    | プロセス終了     |
| 0x2000004 | write | `rdi` = fd, `rsi` = buf, `rdx` = len | ファイル書き出し |

**macOS の syscall 番号体系**:
- macOS は Mach トラップ（`0x0`-`0xFFFF`）と BSD システムコール（`0x2000000` + BSD番号）の 2 種類を持つ
- BSD システムコールは `0x2000000` のフラグが必要
- 標準的な BSD 番号: `exit` = 1, `write` = 4, `open` = 5, `close` = 6, `read` = 3

## 関連ドキュメント

- [`../CPU.md`](../CPU.md) — x86_64 (AMD64) 命令セット完全リファレンス

## 次のステップ

- `msg` の文字列を変更して再ビルド・実行
- `SYS_write` の代わりに `SYS_open`（=5）でファイルを作成してみる
- x86_64 のプロテクトモードやリアルモードに興味があれば、`x86_16/qemu/` のブートセクタ教材も参照
