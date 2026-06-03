# macOS arm64 (AArch64) Hello World

## ビルド & 実行

```sh
make
./hello
```

## コード解説

### システムコール

`svc` 命令でカーネルを呼び出す。`svc` の即値でシステムコールのクラスを指定する。

| 即値    | クラス           |
|---------|------------------|
| #0      | Mach トラップ    |
| #0x80   | BSD システムコール |

syscall 番号は `x16` にセットする（BSD クラスフラグ `0x20000000` は不要）。

```asm
mov     x16, #4             ; SYS_write
svc     #0x80               ; BSD syscall
```

### 呼び出し規約 (ARM64 ABI)

引数はレジスタで渡す。

| 引数 | レジスタ | 意味               |
|------|----------|--------------------|
| 第1  | x0       | fd = stdout        |
| 第2  | x1       | 文字列アドレス     |
| 第3  | x2       | 書き込むバイト数   |
| 番号 | x16      | システムコール番号 |

### データ参照 (adrp + add)

.text と .data など、セクションをまたいだデータ参照には `adrp` + `add` と
`@PAGE` / `@PAGEOFF` 修飾子を使う。

```asm
adrp    x1, msg@PAGE        ; 4KB ページ単位の相対アドレス
add     x1, x1, msg@PAGEOFF ; ページ内オフセットを加算
```

### アセンブラ・リンカ

ARM64 macOS では NASM が使えないため、Clang の組み込みアセンブラでアセンブルする。

```sh
clang -c -arch arm64 -x assembler hello.asm -o hello.o
ld -e _main -arch arm64 -syslibroot $(xcrun --show-sdk-path) -lSystem hello.o -o hello
```

### syscall 番号

| 番号 | 名前   | 説明           |
|------|--------|----------------|
| 1    | exit   | プロセス終了   |
| 4    | write  | ファイル書き出し |
