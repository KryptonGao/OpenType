import CryptoKit
import Foundation
import Security

/// Everything that touches the disk / external tools while updating: download the DMG, mount it, copy the new
/// `.app` out, verify its signature, and (later) hand over to a detached shell script that swaps the bundle.
enum UpdateInstaller {
    // MARK: Staging

    /// Downloads the release DMG, verifies it and returns a verified copy of the new `.app` ready to be installed.
    static func stage(
        release: ReleaseInfo,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let fm = FileManager.default
        let work = workDirectory(for: release.version)
        try? fm.removeItem(at: work)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        do {
            let dmg = work.appendingPathComponent("update.dmg")
            try await download(release.dmgURL, to: dmg, expectedSize: release.dmgSize, progress: progress)
            if let expected = release.sha256 {
                guard try sha256(of: dmg) == expected else { throw UpdateError.checksumMismatch }
            }

            let mountPoint = work.appendingPathComponent("mnt", isDirectory: true)
            try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)
            let attach = try await run("/usr/bin/hdiutil", [
                "attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mountPoint.path, dmg.path,
            ])
            guard attach.status == 0 else { throw UpdateError.mountFailed(attach.output.lastLine) }

            let staged = work.appendingPathComponent("OpenType.app", isDirectory: true)
            do {
                let source = try locateApp(in: mountPoint, release: release)
                let copy = try await run("/usr/bin/ditto", [source.path, staged.path])
                guard copy.status == 0 else { throw UpdateError.commandFailed(copy.output.lastLine) }
            } catch {
                _ = try? await run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
                throw error
            }
            _ = try? await run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
            try? fm.removeItem(at: dmg)

            try verifySignature(of: staged)
            return staged
        } catch {
            try? fm.removeItem(at: work)
            throw error
        }
    }

    static func workDirectory(for version: AppVersion) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let id = Bundle.main.bundleIdentifier ?? "OpenType"
        return base.appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
            .appendingPathComponent(version.description, isDirectory: true)
    }

    /// Removes leftovers of earlier (finished or interrupted) updates.
    static func cleanUpOldUpdates() {
        let base = workDirectory(for: AppVersion("0")!).deletingLastPathComponent()
        try? FileManager.default.removeItem(at: base)
    }

    /// The `.app` inside the mounted image: same bundle identifier as the running app, and the announced version.
    private static func locateApp(in mountPoint: URL, release: ReleaseInfo) throws -> URL {
        let items = (try? FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)) ?? []
        let apps = items.filter { $0.pathExtension == "app" }
        guard !apps.isEmpty else { throw UpdateError.appNotFoundInDiskImage }
        for app in apps {
            guard let bundle = Bundle(url: app) else { continue }
            guard bundle.bundleIdentifier == Bundle.main.bundleIdentifier else { continue }
            let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
            guard let shortVersion, AppVersion(shortVersion) == release.version else { throw UpdateError.wrongApp }
            return app
        }
        throw UpdateError.wrongApp
    }

    // MARK: Signature

    /// The new app must be a valid, untampered bundle and — when the running app has a real signing identity —
    /// satisfy the running app's designated requirement (same bundle id + same certificate).
    /// A running ad-hoc build (designated requirement = cdhash) has no identity to compare, so only validity is checked.
    static func verifySignature(of appURL: URL) throws {
        var newCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &newCode) == errSecSuccess, let newCode else {
            throw UpdateError.invalidSignature(String(localized: "无法读取签名"))
        }

        var requirement: SecRequirement?
        var selfCode: SecCode?
        if SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode {
            var selfStatic: SecStaticCode?
            if SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic {
                var designated: SecRequirement?
                if SecCodeCopyDesignatedRequirement(selfStatic, [], &designated) == errSecSuccess, let designated {
                    var text: CFString?
                    SecRequirementCopyString(designated, [], &text)
                    if !(text as String? ?? "").contains("cdhash") { requirement = designated }
                }
            }
        }

        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckNestedCode | kSecCSCheckAllArchitectures)
        var error: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(newCode, flags, requirement, &error)
        guard status == errSecSuccess else {
            let detail = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "OSStatus \(status)"
            throw UpdateError.invalidSignature(detail)
        }
    }

    // MARK: Installing

    /// Whether the running bundle can be replaced in place.
    static func checkInstallable(bundleURL: URL = Bundle.main.bundleURL) throws {
        let parent = bundleURL.deletingLastPathComponent()
        let readOnly = (try? parent.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly ?? false
        if readOnly || bundleURL.path.contains("/AppTranslocation/") || !FileManager.default.isWritableFile(atPath: parent.path) {
            throw UpdateError.notWritable
        }
    }

    /// Starts a detached shell script that waits for this process to exit, swaps the bundle (restoring the old one
    /// if the copy fails), strips quarantine and opens the app again. The caller must terminate the app afterwards.
    static func launchInstallScript(staged: URL, destination: URL = Bundle.main.bundleURL) throws {
        let work = staged.deletingLastPathComponent()
        let script = work.deletingLastPathComponent().appendingPathComponent("install-\(ProcessInfo.processInfo.processIdentifier).sh")
        try installScript.write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            script.path, String(ProcessInfo.processInfo.processIdentifier), staged.path, destination.path, work.path,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    static let installScript = """
    #!/bin/sh
    # args: <pid to wait for> <new .app> <installed .app> <work dir>
    trap '' HUP
    PID="$1"; SRC="$2"; DST="$3"; WORK="$4"
    i=0
    while kill -0 "$PID" 2>/dev/null; do
      i=$((i+1))
      if [ "$i" -gt 300 ]; then exit 1; fi
      sleep 0.1
    done
    BAK="$DST.updating-old"
    rm -rf "$BAK"
    if mv "$DST" "$BAK"; then
      if /usr/bin/ditto "$SRC" "$DST"; then
        /usr/bin/xattr -dr com.apple.quarantine "$DST" 2>/dev/null
        rm -rf "$BAK"
      else
        rm -rf "$DST"
        mv "$BAK" "$DST"
      fi
    fi
    /usr/bin/open "$DST"
    rm -rf "$WORK"
    rm -f "$0"
    """

    // MARK: Helpers

    private static func download(
        _ url: URL, to destination: URL, expectedSize: Int64, progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let delegate = DownloadProgressDelegate(progress: progress)
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        do {
            let (temp, response) = try await session.download(for: request, delegate: delegate)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw UpdateError.badResponse }
            let size = (try? FileManager.default.attributesOfItem(atPath: temp.path)[.size] as? Int64) ?? 0
            if expectedSize > 0, size != expectedSize { throw UpdateError.checksumMismatch }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temp, to: destination)
            progress(1)
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.network(error.localizedDescription)
        }
    }

    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func run(_ path: String, _ arguments: [String]) async throws -> (status: Int32, output: String) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do { try process.run() } catch {
                    continuation.resume(throwing: error)
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: (process.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
        }
    }
}

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let progress: @Sendable (Double) -> Void
    init(progress: @escaping @Sendable (Double) -> Void) { self.progress = progress }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress(min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

private extension String {
    var lastLine: String {
        trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").last.map(String.init) ?? self
    }
}
