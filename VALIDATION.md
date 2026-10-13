# 検証結果

2026-10-13、Apple Silicon / macOS 26.7.1 / Apple Swift 6.4で確認。

- `bash Scripts/build.sh`：コンパイル・ad hoc署名・ステージ上の署名検証に成功。
- `bash Scripts/test.sh --local`：20チェックが成功。VDFの階層・エスケープ・コメント・不正データ、複数ライブラリ、重複排除、パス検証、欠損フォルダ、画像検索、Steam URIを確認。
- 実ライブラリ：1ライブラリ・3タイトル、読み込み警告0件。3件ともゲームフォルダ・カバー画像・大きな画像を検出。
- 実アプリの画面操作：タイトル表示、Rustの検索、検索解除、方向キーでの選択、お気に入りの追加・解除と0件表示、設定画面、フルスクリーンとEscでの解除を確認。
- Steam未検出状態で「Steamで起動」を押し、具体的なエラーが出て一覧に戻れることを確認。
- 配布ZIP：一時フォルダで展開し、展開後の `.app` の署名を検証。

## 未確認

- MacDeckからSteamゲームを実際に起動する一連の操作は未確認。URI生成とSteam未検出時のエラー表示まで検証済み。
- 接続されたコントローラーがないため、物理コントローラーによる操作は未確認。
- macOS 13〜25、Intel Mac、他のSteamライブラリ構成では実機未検証。配布バイナリはarm64専用。
- CrossOver・Heroic・Windowsゲーム実行環境は未実装。

Windows版Overwatchの別構成での起動確認は [OVERWATCH-SETUP.md](OVERWATCH-SETUP.md) を参照。MacDeckのSteam起動機能の検証とは別です。
