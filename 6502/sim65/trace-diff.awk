# trace-diff.awk — sim65 --trace 出力に前命令とのレジスタ差分行を追加する。
#
# sim65 のトレース行 (右端6フィールドがレジスタ):
#   3  6  0204  A9 C0  lda #$C0  A=00 X=FF Y=00 S=FF Flags=Nvdizc  SP=FFC0
# 差分は各行の直後に "  ▸ A: 00→C0" の形式で表示される (変化なしなら省略)。
# レジスタは各行で「その命令の実行前」の値であるため、差分は直前の行の
# 命令が変更したレジスタを示すことに注意。

{
    print
    # プログラム本体の出力がトレース行の途中に割り込むことがあるため、
    # フィールド数を確認してから右端6フィールドをレジスタとして読む
    # (awk の && は左から評価されるので NF >= 6 を最初に置く)。
    if (NF >= 6 && $(NF - 5) ~ /^A=/ && $NF ~ /^SP=/) {
        a = substr($(NF - 5), 3); x = substr($(NF - 4), 3)
        y = substr($(NF - 3), 3); s = substr($(NF - 2), 3)
        fl = substr($(NF - 1), 7); sp = substr($NF, 4)
        if (NR > 1 && seen) {
            d = ""
            if (a != pa) d = d "  A: " pa "→" a
            if (x != px) d = d "  X: " px "→" x
            if (y != py) d = d "  Y: " py "→" y
            if (s != ps) d = d "  S: " ps "→" s
            if (fl != pfl) d = d "  Flags: " pfl "→" fl
            if (sp != psp) d = d "  SP: " psp "→" sp
            if (d != "") print "        ▸" d
        }
        pa = a; px = x; py = y; ps = s; pfl = fl; psp = sp
        seen = 1
    } else {
        seen = 0
    }
}
