// Renders an SVG to a PNG (transparent background) using WebKit.
// usage: swift render.swift <in.svg> <out.png> <pixelSize>
import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count == 4, let px = Int(args[3]) else { print("usage: render.swift in.svg out.png px"); exit(1) }
let svg = try! String(contentsOfFile: args[1], encoding: .utf8)
let html = "<html><body style='margin:0;background:transparent'><div style='width:\(px)px;height:\(px)px'>\(svg.replacingOccurrences(of: "width=\"1024\" height=\"1024\"", with: "width=\"\(px)\" height=\"\(px)\"").replacingOccurrences(of: #"width="18" height="18""#, with: "width=\"\(px)\" height=\"\(px)\""))</div></body></html>"

final class Loader: NSObject, WKNavigationDelegate {
    let web: WKWebView
    let out: String
    let px: Int
    init(px: Int, out: String) {
        self.px = px
        let cfg = WKWebViewConfiguration()
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: px, height: px), configuration: cfg)
        web.setValue(false, forKey: "drawsBackground")
        self.out = out
        super.init()
        web.navigationDelegate = self
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let c = WKSnapshotConfiguration()
        c.snapshotWidth = NSNumber(value: px)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            webView.takeSnapshot(with: c) { image, err in
                guard let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else { print("fail", err as Any); exit(1) }
                try! png.write(to: URL(fileURLWithPath: self.out))
                exit(0)
            }
        }
    }
}
let app = NSApplication.shared
let loader = Loader(px: px, out: args[2])
loader.web.loadHTMLString(html, baseURL: nil)
app.run()
