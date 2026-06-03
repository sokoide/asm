; hello-sim65: 6502 "Hello World" for sim65 simulator
; sim65 の C ランタイム経由で stdout に文字列出力する
;
; Build:  cl65 -t sim6502 -o hello hello.s
; Run:    sim65 hello

.import _puts        ; C 標準ライブラリの puts() をインポート
.export _main        ; C ランタイムが呼ぶエントリポイント

.segment "RODATA"
message: .asciiz "Hello, sim65 world!"

.segment "CODE"
_main:
    lda #<message    ; ローアドレス
    ldx #>message    ; ハイアドレス
    jsr _puts        ; puts(message) → stdout へ出力
    lda #0
    rts              ; return 0 → sim65 が終了
