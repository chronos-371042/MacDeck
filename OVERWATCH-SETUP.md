# OverwatchをMacで起動した外付け構成

Apple SiliconのMacで、外部プロジェクト [Recall](https://github.com/AsherJN/recall) を使ってWindows版Overwatchを起動した構成の記録です。MacDeckとは別の実行環境です。Recall、Battle.net、Overwatchのソースや配布物はこのリポジトリに含みません。

## 構成例

- 外付けSSD：`/Volumes/名称未設定`（exFAT）
- ゲーム用イメージ：`/Volumes/名称未設定/OverwatchGames.sparsebundle`
- マウント先：`/Volumes/OverwatchMac`（Mac OS拡張・大文字小文字を区別しない）
- Recallのゲーム保存先：`/Volumes/OverwatchMac/Overwatch2Mac`
- Recall本体：`/Applications/Recall.app`

外付けSSDの既存ファイルを残すため、物理ディスクを初期化せず、SSD上のディスクイメージにMac用の保存領域を作成しました。イメージの上限は160 GiBで、実際の使用量は保存したデータに応じて増えます。この環境ではAPFSイメージをマウントできなかったため、Mac OS拡張を使用しました。

ここに示すパスは構成例です。別の環境ではSSDの名前と保存先に合わせて変更してください。

## インストール

1. Recallの公式リポジトリから配布アプリを取得し、Applicationsに配置します。
2. 外付けSSD上のゲーム用イメージをマウントします。
3. Recallでゲーム保存先を選び、実行環境とBattle.netをインストールします。
4. Battle.netにログインし、Overwatchをインストールします。RecallのWindows環境内にある標準のCドライブは、指定した外付けゲーム用領域に保存されます。
5. Battle.netの「プレイ」から起動し、必要に応じてゲーム内でBattle.netへログインします。

ログイン情報や購入コードはこのリポジトリには保存しません。ログインは各サービスの画面で行います。

## 次回の起動

外付けSSDを接続して `Scripts/Open-Overwatch.command` をFinderでダブルクリックすると、ゲーム用イメージをマウントしてRecallを開きます。この補助スクリプトは上記構成例のパスを使うため、別の保存先では冒頭の `GAME_IMAGE` と `GAME_VOLUME` を編集してください。

GitHubから取得したスクリプトをFinderで起動する場合は、初回にターミナルで `chmod +x Scripts/Open-Overwatch.command` を実行して起動権限を付けます。ターミナルから `bash Scripts/Open-Overwatch.command` で起動することもできます。

手動の場合は、SSD内の `OverwatchGames.sparsebundle` をダブルクリックしたあと、ApplicationsのRecallを開きます。その後RecallからBattle.netを開いてOverwatchを起動します。

Battle.netとゲームを終了してからゲーム用ボリュームを取り出し、続いて外付けSSDを取り出します。

## 確認結果

2026年10月13日、Apple Silicon / macOS 26.7.1で確認しました。

- Recall 1.3.0のDMGが開発元の公開SHA-256と一致し、署名・公証の検証に成功。Recall内の更新機能で1.3.1へ更新し、更新後の署名・公証も確認。
- 外付けの標準保存先に `Overwatch/.build.info` と `Overwatch/_retail_/Overwatch.exe` を確認。ゲームフォルダは約77 GiB。
- ログイン後、導入ムービーの再生とメインメニューへの到達を画面で確認。

対戦中の安定性や性能、他のMac・macOSバージョンでは未検証です。
