# i386 (32-bit x86) macOS アセンブラ

macOS 上で i386 (32-bit x86) アセンブリ言語を学ぶための最小限の教材。NASM を使ってアセンブルし、`int 0x80` でシステムコールを呼び出す。

**注意**: macOS 10.14 (Mojave) 以降は i386 (32-bit) バイナリの実行がサポートされていません。10.13 以前の環境、またはクロスコンパイル環境でのみ動作します。

## 前提条件

| ツール | 用途       | インストール例           |
| :---   | :---       | :---                     |
| NASM   | アセンブラ | `brew install nasm`      |
| LD     | リンカ     | Xcode Command Line Tools |

## ビルドと実行

```bash
cd darwin
make          # ビルド
./hello       # 実行
make clean    # 掃除
```

## ディレクトリ構造

```text
.
├── README.md
└── darwin/
    ├── Makefile
    ├── README.md        # Darwin (macOS) Hello World 解説
    └── hello.asm        # メインソース
```

## コード解説

### macOS i386 (32-bit) Hello World

`hello.asm` は macOS のシステムコールを直接呼び出す最小のプログラム。

```asm
global _main

section .text

_main:
    ; write(1, msg, len)
    push    dword len     ; 第3引数: 長さ
    push    dword msg     ; 第2引数: 文字列アドレス
    push    dword 1       ; 第1引数: fd = stdout
    mov     eax, 4        ; SYS_write
    call    _syscall
    add     esp, 12       ; スタックから引数を除去 (cdecl)

    ; exit(0)
    push    dword 0
    mov     eax, 1        ; SYS_exit
    call    _syscall
```

### int 0x80 システムコール

macOS (XNU カーネル) の i386 では `int 0x80` 命令でシステムコールを実行する。`int 0x80` は `call` と異なりリターンアドレスを自動でスタックに積まないため、ラッパーが必要。

```asm
_syscall:
    sub     esp, 4        ; ダミーのリターンアドレス領域を確保
    int     0x80          ; システムコール実行
    add     esp, 4        ; ダミー領域を解放
    ret
```

### 呼び出し規約 (cdecl)

macOS i386 では **cdecl** 呼び出し規約を使用する。

| 要素             | 仕様                                    |
| :---             | :---                                    |
| 引数の渡し方     | スタック（右から左に PUSH）             |
| スタック cleanup | 呼び出し元が行う (`add esp, 12` など)   |
| 戻り値           | EAX                                     |
| 保存義務         | EBP, EBX, ESI, EDI は呼び出されても保存 |

### システムコール (int 0x80)

| 番号 | 名前  | 引数                                 | 説明             |
| :--- | :---  | :---                                 | :---             |
| 1    | exit  | `ebx` = exit code                    | プロセス終了     |
| 4    | write | `ebx` = fd, `ecx` = buf, `edx` = len | ファイル書き出し |

**macOS i386 の注意点**:
- macOS x86_64 と異なり、`rax` に `0x20000000` フラグを加算する必要は **ない**。
- システムコール番号はレジスタ `eax` にセットする。
- 引数は `ebx`, `ecx`, `edx`, ... にセットする（Linux と同じ順序）。

## 関連ドキュメント

- [`CPU.md`](CPU.md) — i386 命令セット完全リファレンス

## 次のステップ

- `hello.asm` のメッセージを変更して再ビルド・実行
- `SYS_write` の代わりに `SYS_open` など別の syscall を試す
- i386 cdecl の動作を確認するため、引数を追加してサブルーチンを呼び出す
- より高度な i386 アセンブリに興味があれば、`x86_16/qemu/` のブートセクタ教材も参照
