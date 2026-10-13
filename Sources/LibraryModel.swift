import AppKit
import SwiftUI
import GameController

enum LibraryFilter: String, CaseIterable {
    case all = "ライブラリ", favorites = "お気に入り", recent = "最近プレイ"
    var symbol: String {
        switch self { case .all: return "square.grid.2x2"; case .favorites: return "star"; case .recent: return "clock" }
    }
}

@MainActor final class LibraryModel: ObservableObject {
    @Published var snapshot = LibrarySnapshot()
    @Published var search = ""
    @Published var filter: LibraryFilter = .all
    @Published var selectedID: String?
    @Published var favorites: Set<String>
    @Published var scanning = false
    @Published var controllerName = "キーボード / マウス"
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var showSettings = false
    @Published var steamAvailable = false
    @Published var root: URL
    @Published var additional: [URL]
    var columns = 4
    private var observers: [NSObjectProtocol] = []
    private var keyboardMonitor: Any?
    private var lastDirection = Date.distantPast
    private let defaults = UserDefaults.standard

    init() {
        let defaults = UserDefaults.standard
        root = defaults.string(forKey: "steamRoot").map { URL(fileURLWithPath: $0) } ?? SteamLibrary.defaultRoot
        additional = (defaults.stringArray(forKey: "additionalLibraries") ?? []).map { URL(fileURLWithPath: $0) }
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        observers.append(NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.connectControllers() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.connectControllers() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled: Bool = MainActor.assumeIsolated {
                guard let self, !self.showSettings, self.errorMessage == nil,
                      NSApp.keyWindow?.attachedSheet == nil,
                      !(NSApp.keyWindow?.firstResponder is NSTextView),
                      event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
                switch event.keyCode {
                case 123: self.move(-1)
                case 124: self.move(1)
                case 125: self.move(self.columns)
                case 126: self.move(-self.columns)
                case 36, 76: self.launchSelected()
                case 49: self.toggleFavorite()
                case 53: self.back()
                default: return false
                }
                return true
            }
            return handled ? nil : event
        }
        connectControllers()
        refresh()
    }

    var games: [SteamGame] {
        var games = snapshot.games.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.id.contains(search) }
        if filter == .favorites { games = games.filter { favorites.contains($0.id) } }
        if filter == .recent {
            games = games.filter { $0.lastPlayed != nil }.sorted { $0.lastPlayed! > $1.lastPlayed! }
        }
        return games
    }
    var selected: SteamGame? { games.first { $0.id == selectedID } ?? games.first }
    var totalSize: String { ByteCountFormatter.string(fromByteCount: snapshot.games.reduce(0) { $0 + $1.size }, countStyle: .file) }
    func refresh() {
        steamAvailable = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "steam://open/main")!) != nil
        guard !scanning else { return }
        scanning = true
        let scanRoot = root, scanAdditional = additional
        Task {
            let result = await Task.detached(priority: .userInitiated) { SteamLibrary.scan(root: scanRoot, additional: scanAdditional) }.value
            snapshot = result
            reconcileSelection()
            scanning = false
        }
    }
    func reconcileSelection() {
        if !games.contains(where: { $0.id == selectedID }) { selectedID = games.first?.id }
    }
    func select(_ id: String) {
        NSApp.keyWindow?.makeFirstResponder(nil)
        selectedID = id
    }
    func move(_ offset: Int) {
        guard !showSettings, errorMessage == nil, !games.isEmpty else { return }
        let index = games.firstIndex { $0.id == selected?.id } ?? 0
        selectedID = games[max(0, min(games.count - 1, index + offset))].id
    }
    func toggleFavorite() {
        guard let game = selected else { return }
        if favorites.contains(game.id) { favorites.remove(game.id) } else { favorites.insert(game.id) }
        defaults.set(Array(favorites).sorted(), forKey: "favorites")
        reconcileSelection()
    }
    func launchSelected() {
        guard !showSettings, errorMessage == nil, let game = selected else { return }
        guard game.filesPresent else {
            errorMessage = "ゲームのフォルダが見つかりません。外付けディスクを接続するか、Steamでインストール状態を確認してください。"; return
        }
        openSteam(game.launchURL, message: "\(game.name) の起動要求をSteamに送りました。")
    }
    func openSteam(_ url: URL, message: String) {
        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
            errorMessage = "Steam本体が見つかりません。Steamをインストールして一度開いたあと、ライブラリを再読み込みしてください。保存済みのゲーム一覧は引き続き閲覧できます。"; return
        }
        if NSWorkspace.shared.open(url) { statusMessage = message }
        else { errorMessage = "Steamを開けませんでした。Steam本体を起動してから再度試してください。" }
    }
    func fullScreen() { NSApp.keyWindow?.toggleFullScreen(nil) }
    func back() {
        if errorMessage != nil { errorMessage = nil }
        else if showSettings { showSettings = false }
        else if !search.isEmpty { search = "" }
        else if filter != .all { filter = .all }
        else if NSApp.keyWindow?.styleMask.contains(.fullScreen) == true { fullScreen() }
    }
    func revealSelected() {
        guard let selected else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selected.installURL])
    }
    func chooseRoot(add: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.message = add ? "Steamライブラリ、またはsteamappsフォルダを選択" : "Steamデータフォルダ、またはsteamappsフォルダを選択"
        panel.prompt = "選択"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let normalized = SteamLibrary.normalize(url)
        guard FileManager.default.fileExists(atPath: normalized.appendingPathComponent("steamapps").path) else {
            errorMessage = "選択した場所にsteamappsフォルダがありません。Steamのライブラリフォルダを選んでください。"; return
        }
        if add {
            if !additional.contains(normalized) && root != normalized { additional.append(normalized) }
        } else { root = normalized }
        savePaths(); refresh()
    }
    func removeLibrary(_ url: URL) { additional.removeAll { $0 == url }; savePaths(); refresh() }
    func resetRoot() { root = SteamLibrary.defaultRoot; savePaths(); refresh() }
    private func savePaths() {
        defaults.set(root.path, forKey: "steamRoot")
        defaults.set(additional.map(\.path), forKey: "additionalLibraries")
    }
    private func connectControllers() {
        let controllers = GCController.controllers()
        controllerName = controllers.first?.vendorName ?? "キーボード / マウス"
        for controller in controllers {
            controller.handlerQueue = .main
            guard let pad = controller.extendedGamepad else { continue }
            let direction: GCControllerDirectionPadValueChangedHandler = { [weak self] _, x, y in
                MainActor.assumeIsolated {
                    guard let self, NSApp.isActive, Date().timeIntervalSince(self.lastDirection) > 0.16 else { return }
                    if abs(x) > 0.55 || abs(y) > 0.55 {
                        self.lastDirection = Date()
                        if abs(x) > abs(y) { self.move(x > 0 ? 1 : -1) }
                        else { self.move(y > 0 ? -self.columns : self.columns) }
                    }
                }
            }
            pad.dpad.valueChangedHandler = direction
            pad.leftThumbstick.valueChangedHandler = direction
            pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { MainActor.assumeIsolated { if NSApp.isActive { self?.launchSelected() } } }
            }
            pad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { MainActor.assumeIsolated { if NSApp.isActive { self?.back() } } }
            }
            pad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { MainActor.assumeIsolated { if NSApp.isActive, self?.showSettings == false, self?.errorMessage == nil { self?.toggleFavorite() } } }
            }
            pad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { MainActor.assumeIsolated { if NSApp.isActive, self?.showSettings == false { self?.fullScreen() } } }
            }
            pad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { MainActor.assumeIsolated { self?.changeFilter(-1) } }
            }
            pad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { MainActor.assumeIsolated { self?.changeFilter(1) } }
            }
        }
    }
    private func changeFilter(_ delta: Int) {
        guard NSApp.isActive, !showSettings, errorMessage == nil else { return }
        let values = LibraryFilter.allCases
        let index = values.firstIndex(of: filter) ?? 0
        filter = values[(index + delta + values.count) % values.count]
        reconcileSelection()
    }
}
