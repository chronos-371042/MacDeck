# MacDeck

Apple Silicon向けのMacネイティブゲームランチャーです。SteamのローカルライブラリをSwiftUI / AppKit / GameControllerで表示・操作します。

## 起動

このリポジトリにはソースコードを収録しています。以下のビルド手順を実行し、生成された `build/MacDeck.app` を開いてください。パッケージ作成後は `dist/MacDeck-0.1.0-arm64.zip` を展開して起動できます。

動作対象はApple Silicon・macOS 13以降です。このMac（arm64 / macOS 26.7.1）でビルドしました。Apple Developerの配布証明書による署名・公証は行っていません。ビルドにはローカルのad hoc署名を使用しています。

## 実装済み

- Steamのインストール済みタイトルを自動検出。ゲーム名・容量・ローカル画像・最終プレイ日時を読み込み。
- `libraryfolders.vdf` の複数ライブラリ、新旧フォーマット、外付けディスク、設定からの手動追加。
- 画像付きライブラリ、選択中タイトルの大きな表示、検索、お気に入り、最近プレイ順。
- `steam://rungameid/<appid>` でSteamに起動を要求。Steam未検出・ゲームフォルダ未検出のエラー表示。
- フルスクリーン、キーボード操作、GameControllerによるコントローラー操作。
- Finderでゲームフォルダを表示、Steam Big Pictureを開く。

Steamの保存データは読み取り専用です。お気に入りとフォルダ指定はアプリ専用のUserDefaultsに保存します。Steamのログイン情報は読み取りません。画像はSteamのローカルキャッシュを使います。

## 操作

| キーボード | コントローラー | 操作 |
| --- | --- | --- |
| 方向キー | 十字キー / 左スティック | 選択 |
| Enter | A | 選択中ゲームを起動 |
| Space | X | お気に入り切り替え |
| ⌃⌘F | Y | フルスクリーン |
| Esc | B | 戻る / 全画面解除 |
| — | LB / RB | ライブラリ・お気に入り・最近プレイ切り替え |
| ⌘R | — | 再読み込み |
| ⌘, | — | 設定 |

検索欄の入力中は方向キーとSpaceを文字編集に使います。Enter、Esc、またはゲームカードのクリックで検索欄からフォーカスを外せます。コントローラーはmacOSがGameControllerとして認識する機器が対象です。アプリが前面にある間だけ入力を処理します。

## 対応範囲

一覧はローカルの `appmanifest_*.acf` にあるインストール情報です。未インストールの所有ゲームをSteam Web APIで取得する機能は含まれていません。ゲームの起動成功やmacOS互換性はSteamと各ゲームの環境に依存します。「Macアプリあり」等はファイルの存在から得た参考情報で、互換性の保証ではありません。

CrossOver・Heroic・Windows互換レイヤー、エミュレーター、ゲーム別実行プロファイル、性能表示は未実装です。

Windows版OverwatchをMacで動かした別構成の記録は [OVERWATCH-SETUP.md](OVERWATCH-SETUP.md) にあります。これは外部プロジェクトのRecallを使う手順で、MacDeckの内蔵機能ではありません。

## 再ビルドと検証

AppleのCommand Line Toolsが必要です。外部パッケージは不要です。

```sh
bash Scripts/build.sh
bash Scripts/test.sh
# このMacのライブラリも読み取り確認する場合
bash Scripts/test.sh --local
bash Scripts/package.sh
```

ソースコードは `Sources/`、読み込みテストは `Tests/` にあります。読み込みテストは一時フォルダに検証用データを作成し、終了時に片付けます。実際のSteamデータを書き換えません。

配布ZIPにはSteamのゲーム画像・マニフェスト・アカウント情報を含めません。

実機で確認した項目と制限は [VALIDATION.md](VALIDATION.md) を参照してください。第三者のインストーラー、ゲーム本体、生成されたアプリやZIPはリポジトリに含めません。
