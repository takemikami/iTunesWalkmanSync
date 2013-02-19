# ITunesWalkmanSync

iTunesで管理しているMP3ファイルをwalkmanに同期するためのrubyスクリプトです。
開発途中で、エラーチェックなどもしていません。
現時点では、Rubyのコードが直せる人でなければ使えないと思って下さい。

特徴：
・２枚組以上のCDをwalkmanに入れた場合に曲順が入れ替わる問題に対処するため、
　track番号を２枚組での通し番号に振り直します。
・アルバムアートをjpgに揃えます。(walkmanはjpgの方が良いと聞いたので)

既知の問題：
・macでしか動かないと思います
・デバッグ用のログが標準出力にガリガリでます
・MP3のタグにutf-8以外の文字が入っていると文字化けします

## Installation

インストール：

このリポジトリをcloneします

設定：

サンプルを元に設定ファイルを作成します。

    $ cp etc/config.yml.sample etc/config.yml

iTunesとwalkmanのライブラリのディレクトリを指定します。

    $ vi etc/config.yml

必要なgemをインストールします。

    $ bundle install

実行：
以下の通りコマンドを実行します。

    $ bundle exec bin/iTunesWalkmanSync

## Usage

特になし

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
