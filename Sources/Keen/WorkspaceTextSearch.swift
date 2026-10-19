import Foundation

struct WorkspaceSearchHit: Identifiable, Equatable {
    let url: URL
    let relativePath: String
    let lineNumber: Int?
    let excerpt: String?

    var id: URL { url }
}

enum WorkspaceTextSearch {
    static func search(
        rootURL: URL,
        query: String,
        showHidden: Bool,
        limit: Int = 200
    ) -> [WorkspaceSearchHit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = FileNode.searchMarkdownFileURLs(
            rootURL: rootURL,
            matching: "",
            showHidden: showHidden,
            limit: .max
        )
        var contentMatches: [WorkspaceSearchHit] = []
        var pathMatches: [WorkspaceSearchHit] = []
        for url in urls {
            if Task<Never, Never>.isCancelled { break }
            let relativePath = String(url.path.dropFirst(rootURL.path.count + 1))
            if needle.isEmpty {
                pathMatches.append(WorkspaceSearchHit(url: url, relativePath: relativePath, lineNumber: nil, excerpt: nil))
            } else if let content = try? String(contentsOf: url, encoding: .utf8),
                      let match = firstMatchingLine(in: content, query: needle) {
                contentMatches.append(WorkspaceSearchHit(
                    url: url,
                    relativePath: relativePath,
                    lineNumber: match.number,
                    excerpt: match.text
                ))
            } else if relativePath.localizedCaseInsensitiveContains(needle) {
                pathMatches.append(WorkspaceSearchHit(url: url, relativePath: relativePath, lineNumber: nil, excerpt: nil))
            }
            if contentMatches.count >= limit || (needle.isEmpty && pathMatches.count >= limit) { break }
        }
        // 正文命中优先；相对路径仍可作为快速定位文件的补充。
        return Array((contentMatches + pathMatches).prefix(limit))
    }

    private static func firstMatchingLine(in content: String, query: String) -> (number: Int, text: String)? {
        var number = 0
        var match: (number: Int, text: String)?
        content.enumerateLines { line, stop in
            number += 1
            guard let range = line.range(of: query, options: .caseInsensitive) else { return }
            let before = line[..<range.lowerBound]
            let after = line[range.upperBound...]
            let excerpt = (before.count > 60 ? "…" : "")
                + before.suffix(60)
                + line[range]
                + after.prefix(100)
                + (after.count > 100 ? "…" : "")
            match = (number, excerpt.trimmingCharacters(in: .whitespacesAndNewlines))
            stop = true
        }
        return match
    }
}
