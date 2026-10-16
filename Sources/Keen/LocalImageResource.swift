import Foundation
import WebKit

enum LocalImageResource {
    static let scheme = "keen-local-image"

    static func url(for source: String, relativeTo directory: URL) -> URL? {
        guard !source.isEmpty,
              !source.hasPrefix("/"),
              !source.hasPrefix("//"),
              URLComponents(string: source)?.scheme == nil else { return nil }

        let decoded = source.removingPercentEncoding ?? source
        let fileURL = directory.appendingPathComponent(decoded).standardizedFileURL
        guard isInside(fileURL, directory: directory),
              let mimeType = mimeType(for: fileURL),
              mimeType.hasPrefix("image/") else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.path = fileURL.path
        return components.url
    }

    static func fileURL(for resourceURL: URL, inside directory: URL) -> URL? {
        guard resourceURL.scheme == scheme else { return nil }
        let fileURL = URL(fileURLWithPath: resourceURL.path).standardizedFileURL
        guard isInside(fileURL, directory: directory),
              mimeType(for: fileURL)?.hasPrefix("image/") == true else { return nil }
        return fileURL
    }

    static func mimeType(for fileURL: URL) -> String? {
        switch fileURL.pathExtension.lowercased() {
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "webp": "image/webp"
        case "svg": "image/svg+xml"
        case "bmp": "image/bmp"
        case "tif", "tiff": "image/tiff"
        case "avif": "image/avif"
        case "heic", "heif": "image/heic"
        default: nil
        }
    }

    private static func isInside(_ fileURL: URL, directory: URL) -> Bool {
        let rootPath = directory.standardizedFileURL.resolvingSymlinksInPath().path
        let filePath = fileURL.resolvingSymlinksInPath().path
        return filePath.hasPrefix(rootPath + "/") && FileManager.default.fileExists(atPath: filePath)
    }
}

final class LocalImageSchemeHandler: NSObject, WKURLSchemeHandler {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let fileURL = LocalImageResource.fileURL(for: url, inside: directory),
              let mimeType = LocalImageResource.mimeType(for: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        do {
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
