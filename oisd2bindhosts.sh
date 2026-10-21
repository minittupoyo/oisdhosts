#!/bin/sh
# oisd2bindhosts.sh - OISD のブロックリストを bindhosts 用の hosts 形式に変換する
#
# 使い方:
#   ./oisd2bindhosts.sh [-o 出力ファイル] [-w ホワイトリスト] [-i IP] [入力 (URL またはファイル)]
#
# 入力形式は自動判別 (引数省略時は標準入力):
#   - domainswild   (*.example.com / example.com)
#   - adblock       (||example.com^)
#   - dnsmasq       (address=/example.com/0.0.0.0, local=/example.com/)
#   - hosts         (0.0.0.0 example.com)
#   - 1行1ドメインのプレーンテキスト
#
# 例:
#   ./oisd2bindhosts.sh -o oisd_hosts.txt https://small.oisd.nl/domainswild2
#   ./oisd2bindhosts.sh -w whitelist.txt -o hosts.txt big_oisd.txt
#
# 出力された hosts ファイルは bindhosts のソースとして使えます
# (例: /data/adb/modules/bindhosts/custom.txt に追記、
#  もしくは sources.txt の URL として配信)。

set -eu

OUT=/dev/stdout
WL=
IP=0.0.0.0

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while getopts o:w:i:h opt; do
    case $opt in
        o) OUT=$OPTARG ;;
        w) WL=$OPTARG ;;
        i) IP=$OPTARG ;;
        h) usage 0 ;;
        *) usage 1 >&2 ;;
    esac
done
shift $((OPTIND - 1))

SRC=${1:--}

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

case $SRC in
    http://*|https://*)
        curl -fsSL --retry 3 "$SRC" -o "$TMP" ;;
    -)
        cat > "$TMP" ;;
    *)
        cp "$SRC" "$TMP" ;;
esac

# ホワイトリスト: 1行1ドメイン、# 以降はコメント。サブドメインも除外対象。
WLFILE=/dev/null
[ -n "$WL" ] && WLFILE=$WL

{
    printf '# Converted from OISD for bindhosts\n'
    printf '# Source: %s\n' "$SRC"
    printf '# Generated: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    printf '127.0.0.1 localhost\n'
    printf '::1 localhost\n'

    awk -v ip="$IP" -v wlfile="$WLFILE" '
    BEGIN {
        while ((getline line < wlfile) > 0) {
            sub(/#.*/, "", line)
            gsub(/[ \t\r]/, "", line)
            if (line != "") wl[tolower(line)] = 1
        }
    }
    function whitelisted(d,   p) {
        while (1) {
            if (d in wl) return 1
            p = index(d, ".")
            if (p == 0) return 0
            d = substr(d, p + 1)
        }
    }
    {
        sub(/\r$/, "")
        line = $0
        # コメント・空行
        if (line ~ /^[ \t]*($|#|!|\[)/) next
        sub(/[ \t]+#.*/, "", line)

        d = ""
        if (line ~ /^[ \t]*(0\.0\.0\.0|127\.0\.0\.1|::1?)[ \t]+/) {
            # hosts 形式
            n = split(line, f, /[ \t]+/)
            d = f[n]
        } else if (line ~ /^\|\|/) {
            # adblock 形式 (||example.com^ のみ。$modifier 付きなどは除外)
            if (line ~ /\^$/) { d = substr(line, 3); sub(/\^$/, "", d) }
        } else if (line ~ /^(address|local|server)=\//) {
            # dnsmasq 形式
            split(line, f, "/")
            d = f[2]
        } else {
            d = line
            gsub(/[ \t]/, "", d)
        }

        d = tolower(d)
        sub(/^\*\./, "", d)       # *.example.com -> example.com
        sub(/\.$/, "", d)

        # ドメイン名として妥当なものだけ通す (IP や記号入りは除外)
        if (d !~ /^[a-z0-9_]([a-z0-9_-]*[a-z0-9_])?(\.[a-z0-9_]([a-z0-9_-]*[a-z0-9_])?)+$/) next
        if (d ~ /^[0-9.]+$/) next
        if (d == "localhost") next
        if (d in seen) next
        if (whitelisted(d)) next

        seen[d] = 1
        print ip " " d
    }' "$TMP" | LC_ALL=C sort -k2
} > "$OUT"

if [ "$OUT" != /dev/stdout ]; then
    printf '%s 件のドメインを %s に出力しました\n' \
        "$(grep -c "^$IP " "$OUT")" "$OUT" >&2
fi
