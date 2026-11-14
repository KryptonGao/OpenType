import Foundation
import Testing
@testable import OpenType

struct AppVersionTests {
    @Test func parsesTagsAndSuffixes() {
        #expect(AppVersion("v0.1.2")?.components == [0, 1, 2])
        #expect(AppVersion("1.2.3-beta.1")?.components == [1, 2, 3])
        #expect(AppVersion("abc") == nil)
        #expect(AppVersion("") == nil)
    }

    @Test func comparesNumerically() {
        #expect(AppVersion("0.1.10")! > AppVersion("0.1.9")!)
        #expect(AppVersion("0.2")! > AppVersion("0.1.9")!)
        #expect(AppVersion("1.0")! == AppVersion("1.0.0")!)
        #expect(AppVersion("0.1.2")! < AppVersion("v0.1.3")!)
    }
}

struct ReleaseParserTests {
    private func json(tag: String = "v0.2.0", assets: String? = nil, extra: String = "") -> Data {
        let defaultAssets = """
        [{"name":"OpenType-0.2.0-arm64.zip","state":"uploaded","size":10,"browser_download_url":"https://github.com/x/y/releases/download/v0.2.0/OpenType-0.2.0-arm64.zip"},
         {"name":"OpenType-0.2.0-arm64.dmg","state":"uploaded","size":2512040,
          "digest":"sha256:4dd441fb536e194b4ab524eb46dfe4d686d5c3699e45cc557175251db87337f3",
          "browser_download_url":"https://github.com/x/y/releases/download/v0.2.0/OpenType-0.2.0-arm64.dmg"}]
        """
        return Data("""
        {"tag_name":"\(tag)","html_url":"https://github.com/x/y/releases/tag/\(tag)","body":"notes",
         "draft":false,"prerelease":false\(extra),"assets":\(assets ?? defaultAssets)}
        """.utf8)
    }

    @Test func picksTheArm64DMGAndDigest() throws {
        let release = try ReleaseParser.parseLatest(json())
        #expect(release.version == AppVersion("0.2.0"))
        #expect(release.dmgName == "OpenType-0.2.0-arm64.dmg")
        #expect(release.dmgSize == 2_512_040)
        #expect(release.sha256 == "4dd441fb536e194b4ab524eb46dfe4d686d5c3699e45cc557175251db87337f3")
        #expect(release.notes == "notes")
    }

    @Test func missingDMGThrows() {
        #expect(throws: UpdateError.noCompatibleAsset) {
            try ReleaseParser.parseLatest(json(assets: "[]"))
        }
    }

    @Test func rejectsNonHTTPSDownloads() {
        let assets = #"[{"name":"a-arm64.dmg","browser_download_url":"http://example.com/a-arm64.dmg"}]"#
        #expect(throws: UpdateError.noCompatibleAsset) {
            try ReleaseParser.parseLatest(json(assets: assets))
        }
    }

    @Test func malformedBodyThrows() {
        #expect(throws: UpdateError.badResponse) { try ReleaseParser.parseLatest(Data("{}".utf8)) }
    }

    @Test func digestParsing() {
        #expect(ReleaseParser.sha256Hex(fromDigest: nil) == nil)
        #expect(ReleaseParser.sha256Hex(fromDigest: "md5:abc") == nil)
        #expect(ReleaseParser.sha256Hex(fromDigest: "sha256:zz") == nil)
    }
}
