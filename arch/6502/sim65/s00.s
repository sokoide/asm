;        s00.s: Scratch
.export  _main

.segment "RODATA"

.segment "CODE"
_main:
	lda     #1
	ldx     #2
	ldy     #3
	lda     #0    ; sim65 は _main の戻り値 (A) を終了コードにする。1 のままだと make run が失敗扱いになるため 0 に戻す
	rts
