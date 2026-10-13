import SwiftUI
import AppKit

private let deckMint = Color(red: 0.53, green: 0.95, blue: 0.75)
private let deckBackground = Color(red: 0.045, green: 0.062, blue: 0.085)

struct ContentView: View {
    @ObservedObject var model: LibraryModel
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        if let game = model.selected { hero(game) }
                        libraryToolbar
                        if !model.steamAvailable { steamNotice }
                        if model.games.isEmpty { emptyState }
                        else {
                            ScrollViewReader { proxy in
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columnCount(geometry.size.width)), spacing: 24) {
                                    ForEach(model.games) { game in
                                        GameCard(game: game, selected: model.selected?.id == game.id, favorite: model.favorites.contains(game.id)) {
                                            model.select(game.id)
                                        }
                                        .id(game.id)
                                    }
                                }
                                .onChange(of: model.selectedID) { id in
                                    if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) } }
                                }
                            }
                        }
                        if !model.snapshot.warnings.isEmpty {
                            Button { model.showSettings = true } label: {
                                Label("読み込みに関するお知らせ \(model.snapshot.warnings.count)件", systemImage: "exclamationmark.triangle")
                            }.buttonStyle(.plain).foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 38).padding(.vertical, 24)
                }
                footer
            }
            .background(deckBackground)
            .onAppear { model.columns = columnCount(geometry.size.width) }
            .onChange(of: geometry.size.width) { width in model.columns = columnCount(width) }
        }
        .tint(deckMint)
        .onChange(of: model.search) { _ in model.reconcileSelection() }
        .onChange(of: model.filter) { _ in model.reconcileSelection() }
        .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
        .alert("起動できませんでした", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
    private func columnCount(_ width: CGFloat) -> Int { max(3, min(6, Int((width - 76) / 225))) }

    private var header: some View {
        HStack(spacing: 15) {
            Image(systemName: "gamecontroller.fill").font(.system(size: 26)).foregroundStyle(deckMint)
            Text("MACDECK").font(.system(size: 21, weight: .heavy, design: .rounded)).tracking(3)
            Text("YOUR GAMES. YOUR MAC.").font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(.secondary).padding(.leading, 10)
            Spacer()
            Label(model.controllerName, systemImage: "gamecontroller").font(.system(size: 12)).foregroundStyle(.secondary)
            Button { model.fullScreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("フルスクリーン（⌃⌘F）")
            Button { model.showSettings = true } label: { Image(systemName: "gearshape") }.help("設定（⌘,）")
        }
        .buttonStyle(.plain)
        .padding(.leading, 80).padding(.trailing, 38).frame(height: 64)
        .background(Color.white.opacity(0.035))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
    }

    private func hero(_ game: SteamGame) -> some View {
        ZStack(alignment: .leading) {
            GeometryReader { geometry in
                if let url = game.heroURL, let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: 265).clipped()
                } else {
                    LinearGradient(colors: [Color(red: 0.13, green: 0.28, blue: 0.27), deckBackground], startPoint: .topTrailing, endPoint: .bottomLeading)
                }
            }
            LinearGradient(stops: [.init(color: deckBackground.opacity(0.97), location: 0), .init(color: deckBackground.opacity(0.82), location: 0.40), .init(color: deckBackground.opacity(0.08), location: 1)], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 15) {
                Text("READY WHEN YOU ARE").font(.system(size: 10, weight: .bold)).tracking(2.5).foregroundStyle(deckMint)
                Text(game.name).font(.system(size: 33, weight: .bold)).lineLimit(2).frame(maxWidth: 600, alignment: .leading)
                HStack(spacing: 14) {
                    Label(game.filesPresent ? "インストール済み" : "ファイル未検出", systemImage: game.filesPresent ? "checkmark.circle.fill" : "externaldrive.badge.exclamationmark")
                    Text(game.sizeLabel)
                    Text(game.platformHint)
                }.font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                HStack(spacing: 12) {
                    Button { model.launchSelected() } label: {
                        Label("Steamで起動", systemImage: "play.fill").font(.system(size: 14, weight: .bold)).padding(.horizontal, 22).padding(.vertical, 12)
                    }.buttonStyle(.plain).foregroundStyle(deckBackground).background(deckMint, in: RoundedRectangle(cornerRadius: 9))
                    Button { model.toggleFavorite() } label: {
                        Image(systemName: model.favorites.contains(game.id) ? "star.fill" : "star").font(.system(size: 18)).frame(width: 44, height: 44)
                    }.buttonStyle(.plain).foregroundStyle(model.favorites.contains(game.id) ? deckMint : .white).background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9)).help("お気に入り（Space / X）")
                    Button { model.revealSelected() } label: {
                        Image(systemName: "folder").font(.system(size: 18)).frame(width: 44, height: 44)
                    }.buttonStyle(.plain).background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9)).help("Finderでファイルを表示")
                }
                Text("起動と互換性の判定はSteam・各ゲームの実行環境に従います。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(28)
        }
        .frame(height: 265).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08)))
    }

    private var libraryToolbar: some View {
        HStack(alignment: .center, spacing: 20) {
            HStack(spacing: 24) {
                ForEach(LibraryFilter.allCases, id: \.self) { filter in
                    Button { model.filter = filter } label: {
                        VStack(spacing: 12) {
                            Label(filter.rawValue, systemImage: filter.symbol).font(.system(size: 14, weight: .semibold))
                            Capsule().fill(model.filter == filter ? deckMint : .clear).frame(height: 3)
                        }
                    }.buttonStyle(.plain).foregroundStyle(model.filter == filter ? .white : .secondary)
                }
            }
            Spacer()
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("ゲームを検索", text: $model.search).textFieldStyle(.plain).accessibilityLabel("ゲームを検索")
                    .onSubmit { NSApp.keyWindow?.makeFirstResponder(nil) }
                    .onExitCommand { model.search = ""; NSApp.keyWindow?.makeFirstResponder(nil) }
                if !model.search.isEmpty {
                    Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("検索をクリア")
                }
            }.padding(11).frame(width: 230).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
            Button { model.refresh() } label: {
                if model.scanning { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.clockwise") }
            }.buttonStyle(.plain).disabled(model.scanning).help("ライブラリを再読み込み（⌘R）").accessibilityLabel("再読み込み")
        }
    }
    private var steamNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle").foregroundStyle(deckMint)
            Text("Steam本体が見つかりません。保存済みのライブラリを表示しています。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Button("設定を見る") { model.showSettings = true }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(deckMint)
        }.padding(14).background(deckMint.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
    }
    private var emptyState: some View {
        VStack(spacing: 15) {
            Image(systemName: model.scanning ? "externaldrive" : "square.grid.2x2").font(.system(size: 42)).foregroundStyle(deckMint.opacity(0.6))
            Text(model.scanning ? "ライブラリを読み込み中…" : model.search.isEmpty && model.filter == .all ? "インストール済みのゲームがありません" : "条件に一致するゲームがありません").font(.title3.bold())
            Text(model.filter == .favorites ? "ゲームを選び、星ボタン・Space・Xで追加できます。" : "Steamのインストール済みタイトルを表示します。外付けライブラリは設定から追加できます。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Button("ライブラリ設定を開く") { model.showSettings = true }.buttonStyle(.bordered)
        }.frame(maxWidth: .infinity).frame(height: 240)
    }
    private var footer: some View {
        HStack(spacing: 22) {
            controlHint("↔", "↑↓ 選択")
            controlHint("A", "Enter 起動")
            controlHint("X", "Space お気に入り")
            controlHint("Y", "全画面")
            controlHint("B", "Esc 戻る")
            Spacer()
            if let message = model.statusMessage { Text(message).lineLimit(1).font(.system(size: 10)).foregroundStyle(deckMint) }
            else { Text("\(model.games.count)件 / \(model.totalSize)").font(.system(size: 11)).foregroundStyle(.secondary) }
        }.padding(.horizontal, 38).frame(height: 48).background(Color.white.opacity(0.035))
    }
    private func controlHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 7) {
            Text(key).font(.system(size: 10, weight: .bold)).frame(width: 21, height: 21).background(Color.white.opacity(0.09), in: Circle())
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

private struct GameCard: View {
    let game: SteamGame
    let selected: Bool
    let favorite: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    GeometryReader { geometry in
                        if let url = game.coverURL, let image = NSImage(contentsOf: url) {
                            Image(nsImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        } else {
                            ZStack {
                                LinearGradient(colors: [Color(red: 0.12, green: 0.24, blue: 0.25), Color(red: 0.08, green: 0.10, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: "gamecontroller").font(.system(size: 44)).foregroundStyle(deckMint.opacity(0.6))
                            }
                        }
                    }
                    if favorite { Image(systemName: "star.fill").foregroundStyle(deckMint).padding(10).background(.black.opacity(0.6), in: Circle()).padding(10) }
                }
                .frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(selected ? deckMint : Color.white.opacity(0.08), lineWidth: selected ? 3 : 1))
                Text(game.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                HStack {
                    Circle().fill(game.filesPresent ? deckMint : .orange).frame(width: 5, height: 5)
                    Text(game.needsUpdate ? "Steamで状態を確認" : game.platformHint)
                    Spacer()
                    Text(game.sizeLabel)
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(5)
        }.buttonStyle(.plain)
        .accessibilityLabel(game.name)
        .accessibilityValue(selected ? "選択中" : "")
    }
}

private struct SettingsView: View {
    @ObservedObject var model: LibraryModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("MacDeckの設定").font(.title2.bold())
                Spacer()
                Button("完了") { model.showSettings = false }.keyboardShortcut(.cancelAction)
            }
            Text("Steamライブラリ").font(.headline)
            Text(model.root.path).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
            HStack {
                Button("データフォルダを変更") { model.chooseRoot(add: false) }
                Button("標準の場所に戻す") { model.resetRoot() }
                Button("ライブラリを追加") { model.chooseRoot(add: true) }
            }
            ForEach(model.additional, id: \.self) { url in
                HStack {
                    Text(url.path).font(.system(size: 11, design: .monospaced))
                    Spacer()
                    Button("一覧から外す") { model.removeLibrary(url) }
                }
            }
            Text("\(model.snapshot.libraries.count)ライブラリ / \(model.snapshot.games.count)タイトル / \(model.totalSize)").font(.system(size: 12)).foregroundStyle(.secondary)
            Divider()
            Text("実行環境").font(.headline)
            Label(model.steamAvailable ? "Steamを検出済み" : "Steam本体が見つかりません", systemImage: model.steamAvailable ? "checkmark.circle" : "exclamationmark.circle")
            Text("ゲーム起動にはSteam本体が必要です。Windowsゲームの互換レイヤーはこのバージョンには含まれていません。CrossOver・Heroicの統合は今後の開発項目です。")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Link("Steam公式ダウンロード", destination: URL(string: "https://store.steampowered.com/about/")!)
                Button("Steam Big Pictureを開く") { model.openSteam(URL(string: "steam://open/bigpicture")!, message: "Big Pictureの起動をSteamに要求しました。") }
            }
            Divider()
            Text("操作").font(.headline)
            Text("方向キー / 十字キー / 左スティック：選択\nEnter / A：起動　Space / X：お気に入り　Y / ⌃⌘F：全画面\nLB・RB：表示切り替え　B / Esc：戻る　⌘R：再読み込み")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if !model.snapshot.warnings.isEmpty {
                ScrollView { Text(model.snapshot.warnings.joined(separator: "\n")).font(.system(size: 11)).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.frame(maxHeight: 100)
            }
            Text("MacDeck 0.1.0 · 独立したmacOSランチャー · ライブラリデータは読み取り専用")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(28).frame(width: 650).preferredColorScheme(.dark)
    }
}
