# oisdhosts

[OISD](https://oisd.nl) (big / small) のブロックリストを、[bindhosts](https://github.com/bindhosts/bindhosts) で使える hosts 形式 (`0.0.0.0 ドメイン`) に変換して配布します。
GitHub Actions で毎日自動更新されます。

## 固定リンク

Releases の `latest` に毎日上書きされます。

| リスト | URL |
| --- | --- |
| big | `https://github.com/minittupoyo/oisdhosts/releases/latest/download/oisd_big_hosts.txt` |
| small | `https://github.com/minittupoyo/oisdhosts/releases/latest/download/oisd_small_hosts.txt` |

bindhosts の `sources.txt` にこの URL を追加してください。

## 手元で変換する

```sh
./oisd2bindhosts.sh -o oisd_big_hosts.txt https://big.oisd.nl
./oisd2bindhosts.sh -w whitelist.txt -o hosts.txt input.txt   # ホワイトリスト付き
```

adblock / domainswild / dnsmasq / hosts / プレーンテキストを自動判別します。`*.example.com` は `example.com` に変換します (hosts はワイルドカード非対応のため)。

## ライセンス

OISD は GPLv3 で配布されており、変換結果も同じく GPLv3 です。元データの著作権は OISD (Stephan van Ruth) に帰属します。
