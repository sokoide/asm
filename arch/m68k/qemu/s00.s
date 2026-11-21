# s01 - scratch

.text
.global _start

_start:
	move.l  #0x4000, %sp

	lea     msg1, %a0
	bsr     print_str
	lea     lf, %a0
	bsr     print_str
	move.l  #1234567, %d0
	bsr     print_uint

halt:
	bra     halt

print_str:
	movem.l %d0/%a0, -(%sp)
.Lps_loop:
	move.b  (%a0)+, %d0
	tst.b   %d0
	beq     .Lps_done
	bsr     putchar
	bra     .Lps_loop
.Lps_done:
	movem.l (%sp)+, %d0/%a0
	rts

# d0 の符号なし32ビット整数を10進数で表示する。
# 表示後の d0 は未定義。d1-d3 と a0 は呼び出し前の値に戻す。
print_uint:
	movem.l %d1-%d3/%a0, -(%sp)     | 作業用レジスタをスタックに退避
	lea     -10(%sp), %sp           | 最大10桁分の一時バッファを確保
	move.l  %sp, %a0                | a0 をバッファの末尾に設定
	move.l  #10, %d1                | 10で割ると、余りが一の位になる
	moveq   #0, %d2                 | d2 はバッファに入れた桁数
	tst.l   %d0                     | 入力が0か確認
	bne     .Lpu_digits
	move.b  #48, -(%a0)             | 0のASCIIコード('0')を格納
	bra     .Lpu_output
.Lpu_digits:
	divu.w  %d1, %d0                | d0を10で割る: 商は下位語、余りは上位語
	move.w  %d0, %d3                | 商を保存し、次の桁の計算に使う
	swap    %d0                     | 余りを下位語へ移動
	add.b   #48, %d0                | 数字0-9をASCII文字'0'-'9'に変換
	move.b  %d0, -(%a0)             | 下位の桁から逆順にバッファへ積む
	addq.l  #1, %d2                 | 格納した桁数を増やす
	moveq   #0, %d0
	move.w  %d3, %d0                | 商を次の除算の入力にする
	bne     .Lpu_digits             | 商が残っていれば次の桁も求める
.Lpu_output:
	tst.l   %d2                     | 出力する桁が残っているか確認
	beq     .Lpu_done
	moveq   #0, %d0
	move.b  (%a0)+, %d0             | バッファから文字を1つ取り出す
	bsr     putchar                 | d0の文字をTTYへ出力
	subq.l  #1, %d2                 | 未出力の桁数を減らす
	bra     .Lpu_output
.Lpu_done:
	lea     10(%sp), %sp            | 一時バッファを解放
	movem.l (%sp)+, %d1-%d3/%a0     | 退避したレジスタを復元
	rts

# putchar: write char in d0 to Goldfish TTY (leaf)
putchar:
	move.l  %d0, 0xff008000
	rts

# ---- Data ----
msg1:
    .asciz "d0="
lf:
    .asciz "\n"
