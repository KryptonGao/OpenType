import AppKit

struct ScreenRegion {
    let image: CGImage
    /// Global AppKit coordinates (origin at the bottom left of the primary display).
    let frame: CGRect

    /// Convert a bottom-left view selection into top-left screenshot pixels, including Retina scaling.
    static func pixelRect(selection: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let clipped = selection.standardized.intersection(CGRect(origin: .zero, size: viewSize))
        guard !clipped.isNull, !clipped.isEmpty else { return .zero }
        return CGRect(x: clipped.minX * imageSize.width / viewSize.width,
                      y: (viewSize.height - clipped.maxY) * imageSize.height / viewSize.height,
                      width: clipped.width * imageSize.width / viewSize.width,
                      height: clipped.height * imageSize.height / viewSize.height).integral
            .intersection(CGRect(origin: .zero, size: imageSize))
    }

    func jpegData() throws -> Data {
        // Bound model payloads while keeping screen text legible. The original crop is kept for image search.
        let scale = min(1, 2048 / CGFloat(max(image.width, image.height)))
        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw LLMError.badResponse(String(localized: "无法处理所选图片"))
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let resized = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: resized).representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            throw LLMError.badResponse(String(localized: "无法处理所选图片"))
        }
        return data
    }
}

/// Browser-side multipart upload: no public image host, clipboard changes, or browser-specific scripting.
enum ImageSearchEngine: String, CaseIterable {
    case google = "Google"
    case bing = "Bing"

    private static let temporaryFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent("OpenType-ImageSearch", isDirectory: true)
    private static let fileLifetime: TimeInterval = 120

    private var uploadURL: URL {
        switch self {
        case .google: URL(string: "https://lens.google.com/v3/upload")!
        case .bing: URL(string: "https://www.bing.com/images/detail/search?iss=sbiupload&FORM=ANCMS1#enterInsights")!
        }
    }

    private var formHeader: String {
        let action = uploadURL.absoluteString.replacingOccurrences(of: "&", with: "&amp;")
        return """
        <!doctype html><html><head><meta charset="utf-8"><title>\(rawValue) Image Search</title>
        <meta name="referrer" content="no-referrer"></head><body>
        <form method="post" enctype="multipart/form-data" action="\(action)">
        """
    }

    func html(imageData: Data) -> String {
        let base64 = imageData.base64EncodedString()
        let input: String
        let prepareFile: String
        switch self {
        case .google:
            input = #"<input type="file" name="encoded_image" accept="image/png">"#
            prepareFile = """
            const bytes=Uint8Array.from(atob('\(base64)'), c=>c.charCodeAt(0));
            const files=new DataTransfer();
            files.items.add(new File([bytes], 'OpenType.png', {type:'image/png'}));
            document.querySelector('input').files=files.files;
            """
        case .bing:
            input = #"<input type="hidden" name="imageBin" value="\#(base64)">"#
            prepareFile = ""
        }

        return """
        \(formHeader)
        \(input)<button type="submit">\(rawValue) Image Search</button>
        </form><script>
        \(prepareFile)
        document.querySelector('form').submit();
        </script></body></html>
        """
    }

    @MainActor
    func open(image: CGImage) throws {
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw LLMError.badResponse(String(localized: "无法处理所选图片"))
        }
        let folder = Self.temporaryFolder
        Self.removeExpiredFiles()
        guard mkdir(folder.path, 0o700) == 0 || errno == EEXIST else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let directory = try Self.openPrivateDirectory(at: folder)
        let name = UUID().uuidString + ".html"
        let url = folder.appendingPathComponent(name)
        let fd = openat(directory.fileDescriptor, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        let browser: URL
        do {
            guard flock(fd, LOCK_EX | LOCK_NB) == 0, fchmod(fd, 0o600) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            try file.write(contentsOf: Data(html(imageData: png).utf8))
            guard let application = NSWorkspace.shared.urlForApplication(toOpen: uploadURL) else {
                throw LLMError.network(String(localized: "无法打开默认浏览器"))
            }
            browser = application
        } catch {
            Self.removeFile(named: name, in: directory, matching: file)
            throw error
        }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: browser, configuration: configuration) { _, error in
            if error != nil {
                Task { @MainActor in
                    let alert = NSAlert()
                    alert.messageText = String(localized: "无法打开默认浏览器")
                    alert.informativeText = error?.localizedDescription ?? ""
                    alert.runModal()
                }
            }
        }
        Task {
            // Keep the exclusive lock through the browser's handoff window, including across app instances.
            try? await Task.sleep(for: .seconds(Self.fileLifetime))
            Self.removeFile(named: name, in: directory, matching: file)
        }
    }

    static func cleanUpOnLaunch() {
        removeExpiredFiles()
        Task {
            // After a quick restart, give recent files their full handoff window before sweeping again.
            try? await Task.sleep(for: .seconds(fileLifetime))
            removeExpiredFiles()
        }
    }

    static func removeExpiredFiles(in folder: URL = temporaryFolder, now: Date = .now) {
        guard let directory = try? openPrivateDirectory(at: folder),
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        let cutoff = now.addingTimeInterval(-fileLifetime)
        let headers = allCases.map { Data(($0.formHeader + "\n").utf8) }
        let headerLength = headers.map(\.count).max() ?? 0
        for name in names where name.hasSuffix(".html") {
            let stem = String(name.dropLast(".html".count))
            guard UUID(uuidString: stem)?.uuidString == stem else { continue }
            let fd = openat(directory.fileDescriptor, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
            guard fd >= 0 else { continue }
            let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            var info = stat()
            guard flock(fd, LOCK_EX | LOCK_NB) == 0,
                  fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
                  info.st_uid == geteuid(), info.st_nlink == 1 else { continue }
            let modified = Date(timeIntervalSince1970: Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9)
            // Check the generated form header without reading the embedded screenshot, including for files from older builds.
            guard modified < cutoff, let prefix = try? file.read(upToCount: headerLength),
                  headers.contains(where: { prefix.starts(with: $0) }) else { continue }
            removeFile(named: name, in: directory, matching: file)
        }
    }

    private static func openPrivateDirectory(at folder: URL) throws -> FileHandle {
        let fd = Darwin.open(folder.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let directory = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == geteuid(), info.st_mode & 0o7777 == 0o700 else {
            throw CocoaError(.fileWriteNoPermission)
        }
        return directory
    }

    private static func removeFile(named name: String, in directory: FileHandle, matching file: FileHandle) {
        var opened = stat()
        var entry = stat()
        let directoryFD = directory.fileDescriptor
        guard fstat(file.fileDescriptor, &opened) == 0,
              fstatat(directoryFD, name, &entry, AT_SYMLINK_NOFOLLOW) == 0,
              entry.st_dev == opened.st_dev, entry.st_ino == opened.st_ino else { return }
        _ = unlinkat(directoryFD, name, 0)
    }
}
