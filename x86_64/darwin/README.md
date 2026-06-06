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

## x86_64 命令リファレンス

この教材で使用する主な x86_64 命令。

### データ転送

| 命令           | 機能                      |
| :---           | :---                      |
| `mov dst, src` | レジスタ間、即値→レジスタ |
| `push src`     | スタックにプッシュ        |
| `pop dst`      | スタックからポップ        |

### 算術演算

| 命令           | 機能               |
| :---           | :---               |
| `add dst, src` | 加算               |
| `sub dst, src` | 減算               |
| `inc dst`      | インクリメント     |
| `dec dst`      | デクリメント       |
| `imul src`     | 符号付き乗算       |
| `xor dst, src` | 排他的論理和 (XOR) |
| `and dst, src` | 論理積             |
| `or dst, src`  | 論理和             |

### シフト

| 命令             | 機能         |
| :---             | :---         |
| `shl dst, count` | 論理左シフト |
| `shr dst, count` | 論理右シフト |
| `sar dst, count` | 算術右シフト |

### 比較・テスト

| 命令        | 機能                      |
| :---        | :---                      |
| `cmp a, b`  | a - b（フラグのみ更新）   |
| `test a, b` | a AND b（フラグのみ更新） |

### 分岐

| 命令            | 機能                   |
| :---            | :---                   |
| `jmp label`     | 無条件ジャンプ         |
| `je/jz label`   | 等しいときジャンプ     |
| `jne/jnz label` | 等しくないときジャンプ |
| `jl/jnge label` | より小さい（符号付き） |
| `jg/jnle label` | より大きい（符号付き） |
| `jb/jnae label` | より小さい（符号なし） |
| `ja/jnbe label` | より大きい（符号なし） |
| `call label`    | サブルーチン呼び出し   |
| `ret`           | 戻り                   |

### アドレス計算

| 命令             | 機能               |
| :---             | :---               |
| `lea dst, [mem]` | 実効アドレスを計算 |

### システム

| 命令      | 機能           |
| :---      | :---           |
| `syscall` | システムコール |
| `nop`     | 何もしない     |

### 疑似命令 (NASM)

| 疑似命令    | 機能                            |
| :---        | :---                            |
| `db`        | バイト列の定義                  |
| `equ`       | 定数の定義（`len equ $ - msg`） |
| `global`    | シンボルを外部に公開            |
| `[rel ...]` | RIP 相対アドレッシング          |

## 次のステップ

- `msg` の文字列を変更して再ビルド・実行
- `SYS_write` の代わりに `SYS_open`（=5）でファイルを作成してみる
- x86_64 のプロテクトモードやリアルモードに興味があれば、`x86_16/qemu/` のブートセクタ教材も参照
