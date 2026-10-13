import Foundation

struct ResolvedDocumentLink: Equatable {
    let fileURL: URL
    let headingID: String?
}

enum DocumentLinkResolver {
    static func resolve(_ url: URL, fileManager: FileManager = .default) -> ResolvedDocumentLink? {
        guard url.isFileURL else { return nil }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let heading = components?.fragment?.removingPercentEncoding
        components?.fragment = nil
        components?.query = nil
        guard var fileURL = components?.url?.standardizedFileURL else { return nil }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            let candidates = ["README.md", "index.md", "README.markdown"]
            guard let entry = candidates
                .map({ fileURL.appendingPathComponent($0) })
                .first(where: { fileManager.fileExists(atPath: $0.path) }) else { return nil }
            fileURL = entry
        } else if fileURL.pathExtension.isEmpty {
            let candidates = [fileURL.appendingPathExtension("md"), fileURL.appendingPathExtension("markdown")]
            if let match = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) {
                fileURL = match
            }
        }

        guard ["md", "markdown"].contains(fileURL.pathExtension.lowercased()),
              fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return ResolvedDocumentLink(fileURL: fileURL, headingID: heading?.isEmpty == false ? heading : nil)
    }
}
