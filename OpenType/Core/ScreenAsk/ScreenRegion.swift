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

    private var uploadURL: URL {
        switch self {
        case .google: URL(string: "https://lens.google.com/v3/upload")!
        case .bing: URL(string: "https://www.bing.com/images/detail/search?iss=sbiupload&FORM=ANCMS1#enterInsights")!
        }
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

        let action = uploadURL.absoluteString.replacingOccurrences(of: "&", with: "&amp;")
        return """
        <!doctype html><html><head><meta charset="utf-8"><title>\(rawValue) Image Search</title>
        <meta name="referrer" content="no-referrer"></head><body>
        <form method="post" enctype="multipart/form-data" action="\(action)">
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
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("OpenType-ImageSearch", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        Self.removeExpiredFiles(in: folder)
        let url = folder.appendingPathComponent(UUID().uuidString + ".html")
        try Data(html(imageData: png).utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        guard let browser = NSWorkspace.shared.urlForApplication(toOpen: uploadURL) else {
            try? FileManager.default.removeItem(at: url)
            throw LLMError.network(String(localized: "无法打开默认浏览器"))
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
            try? await Task.sleep(for: .seconds(120))
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func removeExpiredFiles(in folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where file.pathExtension == "html" {
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if date < Date().addingTimeInterval(-120) { try? FileManager.default.removeItem(at: file) }
        }
    }
}
