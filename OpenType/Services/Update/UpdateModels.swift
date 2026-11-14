import Foundation

/// A dotted numeric version such as `0.1.2` (a leading `v` and any `-suffix` are ignored).
struct AppVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    let components: [Int]

    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        if let dash = text.firstIndex(where: { $0 == "-" || $0 == "+" }) { text = String(text[..<dash]) }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        components = parts.compactMap { $0 }
    }

    var description: String { components.map(String.init).joined(separator: ".") }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool { compare(lhs, rhs) == 0 }
    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool { compare(lhs, rhs) < 0 }

    /// Missing trailing components count as 0 (`1.2` == `1.2.0`).
    private static func compare(_ lhs: AppVersion, _ rhs: AppVersion) -> Int {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let l = index < lhs.components.count ? lhs.components[index] : 0
            let r = index < rhs.components.count ? rhs.components[index] : 0
            if l != r { return l < r ? -1 : 1 }
        }
        return 0
    }
}

/// The parts of a GitHub Release the updater needs.
struct ReleaseInfo: Equatable, Sendable {
    let version: AppVersion
    let tag: String
    let notes: String
    let pageURL: URL
    let dmgURL: URL
    let dmgName: String
    let dmgSize: Int64
    /// Lower-case hex SHA-256 from the asset's `digest` field, when GitHub provides one.
    let sha256: String?
}

enum UpdateError: LocalizedError, Equatable {
    case network(String)
    case badResponse
    case noCompatibleAsset
    case checksumMismatch
    case mountFailed(String)
    case appNotFoundInDiskImage
    case wrongApp
    case invalidSignature(String)
    case notWritable
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .network(let detail): String(localized: "无法连接到 GitHub：\(detail)")
        case .badResponse: String(localized: "GitHub 返回了无法识别的数据")
        case .noCompatibleAsset: String(localized: "最新版本中没有适用于此 Mac 的安装包")
        case .checksumMismatch: String(localized: "下载的文件校验失败，请稍后重试")
        case .mountFailed(let detail): String(localized: "无法打开安装镜像：\(detail)")
        case .appNotFoundInDiskImage: String(localized: "安装镜像中找不到 OpenType.app")
        case .wrongApp: String(localized: "安装镜像中的应用与当前应用不匹配")
        case .invalidSignature(let detail): String(localized: "新版本的签名校验未通过：\(detail)")
        case .notWritable: String(localized: "没有权限替换当前应用。请先把 OpenType 移到「应用程序」文件夹，或手动下载安装")
        case .commandFailed(let detail): String(localized: "更新失败：\(detail)")
        }
    }
}

enum ReleaseParser {
    /// Parses the body of `GET /repos/{owner}/{repo}/releases/latest`.
    /// `architecture` selects the asset suffix (`-arm64.dmg`); the app is arm64-only.
    static func parseLatest(_ data: Data, architecture: String = "arm64") throws -> ReleaseInfo {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String,
              let version = AppVersion(tag),
              let pageString = object["html_url"] as? String,
              let pageURL = URL(string: pageString)
        else { throw UpdateError.badResponse }
        if (object["draft"] as? Bool) == true || (object["prerelease"] as? Bool) == true {
            throw UpdateError.badResponse
        }

        let assets = object["assets"] as? [[String: Any]] ?? []
        let suffix = "-\(architecture).dmg"
        guard let asset = assets.first(where: {
            ($0["name"] as? String)?.lowercased().hasSuffix(suffix) == true
                && ($0["state"] as? String ?? "uploaded") == "uploaded"
        }),
            let name = asset["name"] as? String,
            let urlString = asset["browser_download_url"] as? String,
            let url = URL(string: urlString),
            url.scheme == "https"
        else { throw UpdateError.noCompatibleAsset }

        return ReleaseInfo(
            version: version,
            tag: tag,
            notes: object["body"] as? String ?? "",
            pageURL: pageURL,
            dmgURL: url,
            dmgName: name,
            dmgSize: (asset["size"] as? NSNumber)?.int64Value ?? 0,
            sha256: sha256Hex(fromDigest: asset["digest"] as? String)
        )
    }

    /// `"sha256:ab12…"` → `"ab12…"`; anything else → nil.
    static func sha256Hex(fromDigest digest: String?) -> String? {
        guard let digest, digest.lowercased().hasPrefix("sha256:") else { return nil }
        let hex = digest.dropFirst("sha256:".count).lowercased()
        guard hex.count == 64, hex.allSatisfy(\.isHexDigit) else { return nil }
        return String(hex)
    }
}
