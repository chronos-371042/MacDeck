import Foundation

indirect enum VDFValue {
    case string(String)
    case object([String: VDFValue])
    var string: String? { if case .string(let value) = self { return value }; return nil }
    var object: [String: VDFValue]? { if case .object(let value) = self { return value }; return nil }
}

/// Valve KeyValues: quoted and bare tokens, nested objects, escapes and comments.
struct VDFParser {
    enum ParseError: Error { case invalid(String) }
    private let chars: [Character]
    private var offset = 0
    init(_ source: String) { chars = Array(source) }
    mutating func parse() throws -> [String: VDFValue] { try object(nested: false) }
    private mutating func skipSpace() {
        while offset < chars.count {
            if chars[offset].isWhitespace || chars[offset] == "\u{FEFF}" { offset += 1 }
            else if chars[offset] == "/", offset + 1 < chars.count, chars[offset + 1] == "/" {
                while offset < chars.count && chars[offset] != "\n" { offset += 1 }
            } else { break }
        }
    }
    private mutating func token() throws -> String {
        skipSpace()
        guard offset < chars.count else { throw ParseError.invalid("Unexpected end") }
        if chars[offset] == "\"" {
            offset += 1
            var value = ""
            while offset < chars.count {
                let c = chars[offset]; offset += 1
                if c == "\"" { return value }
                if c == "\\", offset < chars.count {
                    let next = chars[offset]
                    if next == "\"" || next == "\\" { value.append(next); offset += 1 }
                    else { value.append(c) }
                } else { value.append(c) }
            }
            throw ParseError.invalid("Unterminated quote")
        }
        var value = ""
        while offset < chars.count && !chars[offset].isWhitespace && chars[offset] != "{" && chars[offset] != "}" {
            value.append(chars[offset]); offset += 1
        }
        guard !value.isEmpty else { throw ParseError.invalid("Expected token") }
        return value
    }
    private mutating func object(nested: Bool, depth: Int = 0) throws -> [String: VDFValue] {
        guard depth < 64 else { throw ParseError.invalid("Nesting limit") }
        var result: [String: VDFValue] = [:]
        while true {
            skipSpace()
            guard offset < chars.count else {
                if nested { throw ParseError.invalid("Unclosed object") }
                return result
            }
            if chars[offset] == "}" {
                guard nested else { throw ParseError.invalid("Unexpected brace") }
                offset += 1; return result
            }
            let key = try token().lowercased()
            skipSpace()
            if offset < chars.count && chars[offset] == "{" {
                offset += 1; result[key] = .object(try object(nested: true, depth: depth + 1))
            } else { result[key] = .string(try token()) }
        }
    }
}

struct SteamGame: Identifiable, Equatable {
    let id: String
    let name: String
    let installURL: URL
    let libraryURL: URL
    let size: Int64
    let lastPlayed: Date?
    let filesPresent: Bool
    let needsUpdate: Bool
    let platformHint: String
    let coverURL: URL?
    let heroURL: URL?
    var launchURL: URL { URL(string: "steam://rungameid/\(id)")! }
    var sizeLabel: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}

struct LibrarySnapshot {
    var games: [SteamGame] = []
    var libraries: [URL] = []
    var warnings: [String] = []
}

struct SteamLibrary {
    static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Steam")
    }

    static func scan(root: URL, additional: [URL] = []) -> LibrarySnapshot {
        let fm = FileManager.default
        var snapshot = LibrarySnapshot()
        var roots = [normalize(root)] + additional.map(normalize)
        let folders = roots[0].appendingPathComponent("steamapps/libraryfolders.vdf")
        if fm.fileExists(atPath: folders.path) {
            do {
                var parser = VDFParser(try String(contentsOf: folders, encoding: .utf8))
                let parsed = try parser.parse()
                for (key, value) in parsed["libraryfolders"]?.object ?? [:] where Int(key) != nil {
                    if let path = value.object?["path"]?.string ?? value.string, path.hasPrefix("/") {
                        roots.append(normalize(URL(fileURLWithPath: path)))
                    }
                }
            } catch { snapshot.warnings.append("libraryfolders.vdf を読み込めませんでした。\(error.localizedDescription)") }
        }
        var seenRoots = Set<String>(), seenGames = Set<String>()
        for library in roots where seenRoots.insert(library.path).inserted {
            let steamapps = library.appendingPathComponent("steamapps")
            guard fm.fileExists(atPath: steamapps.path) else {
                snapshot.warnings.append("ライブラリが見つかりません: \(steamapps.path)"); continue
            }
            snapshot.libraries.append(library)
            do {
                let files = try fm.contentsOfDirectory(at: steamapps, includingPropertiesForKeys: nil)
                for file in files.sorted(by: { $0.path < $1.path }) where file.lastPathComponent.hasPrefix("appmanifest_") && file.pathExtension == "acf" {
                    do {
                        var parser = VDFParser(try String(contentsOf: file, encoding: .utf8))
                        guard let state = try parser.parse()["appstate"]?.object,
                              let id = state["appid"]?.string, isValidID(id),
                              let name = state["name"]?.string, !name.isEmpty,
                              let directory = state["installdir"]?.string, isSafeDirectory(directory) else {
                            snapshot.warnings.append("不正なマニフェスト: \(file.lastPathComponent)"); continue
                        }
                        let install = steamapps.appendingPathComponent("common").appendingPathComponent(directory)
                        var isDirectory: ObjCBool = false
                        let present = fm.fileExists(atPath: install.path, isDirectory: &isDirectory) && isDirectory.boolValue
                        let flags = Int(state["stateflags"]?.string ?? "0") ?? 0
                        guard seenGames.insert(id).inserted else { continue }
                        let timestamp = Double(state["lastplayed"]?.string ?? "0") ?? 0
                        snapshot.games.append(SteamGame(
                            id: id, name: name, installURL: install, libraryURL: library,
                            size: Int64(state["sizeondisk"]?.string ?? "0") ?? 0,
                            lastPlayed: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil,
                            filesPresent: present, needsUpdate: flags & 4 == 0 || flags & 2 != 0,
                            platformHint: platformHint(at: install),
                            coverURL: artwork(id: id, root: normalize(root), names: ["library_600x900_japanese.jpg", "library_600x900.jpg", "library_600x900.png", "header.jpg"]),
                            heroURL: artwork(id: id, root: normalize(root), names: ["library_hero.jpg", "library_header_japanese.jpg", "library_header.jpg", "header.jpg"])))
                    } catch { snapshot.warnings.append("\(file.lastPathComponent) を読み込めませんでした。") }
                }
            } catch { snapshot.warnings.append("ライブラリにアクセスできません: \(steamapps.path)") }
        }
        snapshot.games.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return snapshot
    }

    static func normalize(_ url: URL) -> URL {
        url.lastPathComponent == "steamapps" ? url.deletingLastPathComponent().standardizedFileURL : url.standardizedFileURL
    }
    static func isValidID(_ id: String) -> Bool { !id.isEmpty && id.utf8.allSatisfy { $0 >= 48 && $0 <= 57 } && UInt64(id) != nil && UInt64(id)! > 0 }
    static func isSafeDirectory(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/") && !value.contains("\\") && !value.contains("\0")
    }
    private static func platformHint(at url: URL) -> String {
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return "実行環境未確認" }
        if files.contains(where: { $0.pathExtension.lowercased() == "app" }) { return "Macアプリあり" }
        if files.contains(where: { $0.pathExtension.lowercased() == "exe" }) { return "Windowsファイルあり" }
        return "実行環境未確認"
    }
    private static func artwork(id: String, root: URL, names: [String]) -> URL? {
        let cache = root.appendingPathComponent("appcache/librarycache")
        let folder = cache.appendingPathComponent(id)
        let fm = FileManager.default
        for name in names {
            for url in [folder.appendingPathComponent(name), cache.appendingPathComponent("\(id)_\(name)")] {
                if fm.fileExists(atPath: url.path) { return url }
            }
        }
        if let subfolders = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey]) {
            for sub in subfolders.sorted(by: { $0.path < $1.path }) {
                guard (try? sub.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                for name in names {
                    let candidate = sub.appendingPathComponent(name)
                    if fm.fileExists(atPath: candidate.path) { return candidate }
                }
            }
        }
        return nil
    }
}
