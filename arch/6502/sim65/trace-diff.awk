# trace-diff.awk — sim65 --trace 出力に BEFORE / AFTER / CHANGE のレジスタ差分を追加する。
#
# sim65 のトレース行 (右端6フィールドがレジスタ):
#   3  6  0204  A9 C0  lda #$C0  A=00 X=FF Y=00 S=FF Flags=Nvdizc  SP=FFC0
# レジスタ欄は「その命令の実行前」の値である。そこで各命令行の直後に、
# 変化があったレジスタだけ 3 行 1 セットで表示する:
#   BEFORE: この命令の実行前値 (= この行のレジスタ欄)
#   AFTER:  この命令の実行後値 (= 次のトレース行のレジスタ欄の実行前値)
#   CHANGE: old→new の要約
# AFTER は次のトレース行を読むまで確定しないため、全行を蓄えて END で出力する。

{
    lines[NR] = $0
    # プログラム本体の出力がトレース行の途中に割り込むことがあるため、
    # フィールド数を確認してから右端6フィールドをレジスタとして読む
    # (awk の && は左から評価されるので NF >= 6 を最初に置く)。
    if (NF >= 6 && $(NF - 5) ~ /^A=/ && $NF ~ /^SP=/) {
        k++
        a[k] = substr($(NF - 5), 3); x[k] = substr($(NF - 4), 3)
        y[k] = substr($(NF - 3), 3); s[k] = substr($(NF - 2), 3)
        fl[k] = substr($(NF - 1), 7); sp[k] = substr($NF, 4)
        tln[k] = NR
        idx[NR] = k
    }
}

END {
    for (n = 1; n <= NR; n++) {
        print lines[n]
        if (n in idx) {
            i = idx[n]
            # AFTER は「次のトレース行の実行前値」から取る。次の行が
            # トレース行でない場合 (出力混入で壊れた行など) は差分を
            # 出さない (旧実装の seen リセットの挙動を踏襲)。
            if (i < k && tln[i + 1] == n + 1) {
                j = i + 1
                if (a[i] != a[j]) {
                    print "        BEFORE: A=" a[i]
                    print "        AFTER:  A=" a[j]
                    print "        CHANGE: A " a[i] "→" a[j]
                }
                if (x[i] != x[j]) {
                    print "        BEFORE: X=" x[i]
                    print "        AFTER:  X=" x[j]
                    print "        CHANGE: X " x[i] "→" x[j]
                }
                if (y[i] != y[j]) {
                    print "        BEFORE: Y=" y[i]
                    print "        AFTER:  Y=" y[j]
                    print "        CHANGE: Y " y[i] "→" y[j]
                }
                if (s[i] != s[j]) {
                    print "        BEFORE: S=" s[i]
                    print "        AFTER:  S=" s[j]
                    print "        CHANGE: S " s[i] "→" s[j]
                }
                if (fl[i] != fl[j]) {
                    print "        BEFORE: Flags=" fl[i]
                    print "        AFTER:  Flags=" fl[j]
                    print "        CHANGE: Flags " fl[i] "→" fl[j]
                }
                if (sp[i] != sp[j]) {
                    print "        BEFORE: SP=" sp[i]
                    print "        AFTER:  SP=" sp[j]
                    print "        CHANGE: SP " sp[i] "→" sp[j]
                }
            }
        }
    }
}
