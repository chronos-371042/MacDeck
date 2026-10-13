import SwiftUI
import AppKit

@main struct MacDeckApp: App {
    @StateObject private var model = LibraryModel()
    var body: some Scene {
        Window("MacDeck", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 960, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1280, height: 860)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("ライブラリを再読み込み") { model.refresh() }.keyboardShortcut("r")
                Button("フルスクリーン") { model.fullScreen() }.keyboardShortcut("f", modifiers: [.command, .control])
                Button("設定") { model.showSettings = true }.keyboardShortcut(",")
            }
        }
    }
}
