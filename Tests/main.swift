import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
    checks += 1
    guard condition() else { fatalError("FAIL: \(name)") }
    print("PASS: \(name)")
}
func parse(_ value: String) throws -> [String: VDFValue] {
    var parser = VDFParser(value); return try parser.parse()
}
let basic = try parse("\u{FEFF}// comment\n\"AppState\" { \"Name\" \"Test \\\"Game\\\"\" child { value bare } path \"C:\\\\Games\" }")
expect(basic["appstate"]?.object?["name"]?.string == "Test \"Game\"", "quoted escapes and case-insensitive keys")
expect(basic["appstate"]?.object?["child"]?.object?["value"]?.string == "bare", "nested and unquoted tokens")
expect(basic["appstate"]?.object?["path"]?.string == "C:\\Games", "escaped backslash")
for invalid in ["\"x\" {", "\"x\" \"unterminated", "}", "\"key\""] {
    do { _ = try parse(invalid); fatalError("Invalid VDF accepted") } catch { checks += 1 }
}
expect(!SteamLibrary.isSafeDirectory("../escape") && !SteamLibrary.isSafeDirectory("..") && !SteamLibrary.isSafeDirectory("/tmp/escape"), "reject install path traversal")
expect(!SteamLibrary.isValidID("12/3") && !SteamLibrary.isValidID("0") && SteamLibrary.isValidID("252490"), "only positive numeric Steam app IDs")

let fm = FileManager.default
let testBase = fm.temporaryDirectory.appendingPathComponent("MacDeckTests-\(UUID().uuidString)")
defer { try? fm.removeItem(at: testBase) }
let root = testBase.appendingPathComponent("Steam")
let external = testBase.appendingPathComponent("External Library")
func write(_ text: String, to url: URL) throws {
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
}
try write("\"libraryfolders\" { \"0\" { \"path\" \"\(root.path)\" } \"1\" { \"path\" \"\(external.path)\" } }", to: root.appendingPathComponent("steamapps/libraryfolders.vdf"))
try write("\"AppState\" { \"appid\" \"123\" \"name\" \"Game A\" \"installdir\" \"Game A\" \"SizeOnDisk\" \"100\" \"LastPlayed\" \"200\" \"StateFlags\" \"4\" }", to: root.appendingPathComponent("steamapps/appmanifest_123.acf"))
try fm.createDirectory(at: root.appendingPathComponent("steamapps/common/Game A/Test.app"), withIntermediateDirectories: true)
try write("\"AppState\" { \"appid\" \"124\" \"name\" \"Game B\" \"installdir\" \"Game B\" \"StateFlags\" \"2\" }", to: external.appendingPathComponent("steamapps/appmanifest_124.acf"))
try write("\"AppState\" { \"appid\" \"123\" \"name\" \"Duplicate\" \"installdir\" \"Duplicate\" }", to: external.appendingPathComponent("steamapps/appmanifest_123.acf"))
try write("broken {", to: external.appendingPathComponent("steamapps/appmanifest_bad.acf"))
try write("\"AppState\" { \"appid\" \"125\" \"name\" \"Escape\" \"installdir\" \"../outside\" }", to: external.appendingPathComponent("steamapps/appmanifest_125.acf"))
try write("image placeholder", to: root.appendingPathComponent("appcache/librarycache/123/abcdef/library_hero.jpg"))
let snapshot = SteamLibrary.scan(root: root, additional: [external, external.appendingPathComponent("steamapps")])
expect(snapshot.games.map(\.id) == ["123", "124"], "multiple libraries, malformed entries and duplicate IDs")
expect(snapshot.libraries.count == 2, "deduplicate normalized libraries")
expect(snapshot.games[0].filesPresent && !snapshot.games[1].filesPresent, "detect absent game files")
expect(snapshot.games[0].platformHint == "Macアプリあり", "platform hint from actual files")
expect(snapshot.games[1].needsUpdate && !snapshot.games[0].needsUpdate, "Steam state flags")
expect(snapshot.games[0].lastPlayed == Date(timeIntervalSince1970: 200), "last played timestamp")
expect(snapshot.games[0].heroURL?.lastPathComponent == "library_hero.jpg", "artwork inside hash subdirectory")
expect(snapshot.games[0].launchURL.absoluteString == "steam://rungameid/123", "numeric launch URL")
expect(snapshot.warnings.count == 2, "diagnostics for corrupted and unsafe manifests")
try write("\"LibraryFolders\" { \"1\" \"\(external.path)\" }", to: root.appendingPathComponent("steamapps/libraryfolders.vdf"))
expect(SteamLibrary.scan(root: root).games.count == 2, "legacy libraryfolders format")
expect(!SteamLibrary.scan(root: testBase.appendingPathComponent("missing")).warnings.isEmpty, "missing library diagnostics")
print("\(checks) checks passed")

if CommandLine.arguments.contains("--local") {
    let local = SteamLibrary.scan(root: SteamLibrary.defaultRoot)
    print("Local: \(local.games.count) entries, \(local.libraries.count) libraries, \(local.warnings.count) warnings")
    for game in local.games {
        print("\(game.id) | \(game.name) | files: \(game.filesPresent) | cover: \(game.coverURL != nil) | hero: \(game.heroURL != nil) | \(game.platformHint)")
    }
}
