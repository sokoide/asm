# macOS i386 (32-bit) Hello World

## ビルド & 実行

```sh
make
./hello
```

## コード解説

### システムコール

macOS i386 では Linux と同じ `int 0x80` でカーネルを呼び出す。ただし `int 0x80` は
`call` と違い戻りアドレスを自動でスタックに積まないため、`_syscall` ヘルパー内で
`sub esp, 4` によりダミー領域を確保してから呼び出している。

### 呼び出し規約 (cdecl)

引数はスタックに **後ろから前へ** 積まれ、呼び出し元がスタックを復元する。

```asm
push    dword len       ; 第3引数: 書き込むバイト数
push    dword msg       ; 第2引数: 文字列アドレス
push    dword 1         ; 第1引数: fd = stdout
mov     eax, 4          ; syscall 番号: write
call    _syscall
add     esp, 12         ; 引数 3 つ分 (12 bytes) をスタックから除去
```

### syscall 番号

| 番号 | 名前  | 説明             |
| :--- | :---  | :---             |
| 1    | exit  | プロセス終了     |
| 4    | write | ファイル書き出し |

## 関連ドキュメント

- [`../CPU.md`](../CPU.md) — i386 命令セット完全リファレンス

## 制限

macOS 10.14 (Mojave) 以降は i386 バイナリの実行ができません。
