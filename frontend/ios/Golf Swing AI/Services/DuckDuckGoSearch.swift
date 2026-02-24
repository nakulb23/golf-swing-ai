import Foundation

// MARK: - Search Result Model
struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let snippet: String
}

// MARK: - DuckDuckGo Search Service
actor DuckDuckGoSearch {
    static let shared = DuckDuckGoSearch()

    private let baseURL = "https://html.duckduckgo.com/html/"
    private let cache = NSCache<NSString, CachedResults>()
    private let cacheTTL: TimeInterval = 60 * 15 // 15 minutes

    private init() {
        print("🔍 DuckDuckGoSearch initialized")
    }

    // MARK: - Search
    func search(query: String, maxResults: Int = 5) async -> [SearchResult] {
        let cacheKey = query.lowercased() as NSString

        // Check cache
        if let cached = cache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            print("📦 Using cached search results for: \(query)")
            return Array(cached.results.prefix(maxResults))
        }

        print("🌐 Searching DuckDuckGo for: \(query)")

        do {
            let results = try await performSearch(query: query)
            let limitedResults = Array(results.prefix(maxResults))

            // Cache results
            let cachedResults = CachedResults(results: limitedResults, timestamp: Date())
            cache.setObject(cachedResults, forKey: cacheKey)

            return limitedResults
        } catch {
            print("❌ Search failed: \(error.localizedDescription)")
            return []
        }
    }

    private func performSearch(query: String) async throws -> [SearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw SearchError.invalidQuery
        }

        let urlString = "\(baseURL)?q=\(encodedQuery)"
        guard let url = URL(string: urlString) else {
            throw SearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SearchError.requestFailed
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw SearchError.parseError
        }

        return parseSearchResults(from: html)
    }

    // MARK: - HTML Parsing
    private func parseSearchResults(from html: String) -> [SearchResult] {
        var results: [SearchResult] = []

        // Find result blocks
        let resultPattern = #"<a class="result__a" href="([^"]+)"[^>]*>([^<]+)</a>.*?<a class="result__snippet"[^>]*>([^<]*)</a>"#

        guard let regex = try? NSRegularExpression(pattern: resultPattern, options: [.dotMatchesLineSeparators]) else {
            return fallbackParse(html: html)
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        for match in matches.prefix(10) {
            guard match.numberOfRanges >= 4 else { continue }

            let urlRange = Range(match.range(at: 1), in: html)
            let titleRange = Range(match.range(at: 2), in: html)
            let snippetRange = Range(match.range(at: 3), in: html)

            guard let urlRange = urlRange,
                  let titleRange = titleRange,
                  let snippetRange = snippetRange else { continue }

            var url = String(html[urlRange])
            let title = String(html[titleRange]).htmlDecoded
            let snippet = String(html[snippetRange]).htmlDecoded

            // Clean up DuckDuckGo redirect URLs
            if url.contains("uddg=") {
                if let uddgRange = url.range(of: "uddg="),
                   let endRange = url.range(of: "&", range: uddgRange.upperBound..<url.endIndex) {
                    let encoded = String(url[uddgRange.upperBound..<endRange.lowerBound])
                    url = encoded.removingPercentEncoding ?? url
                } else if let uddgRange = url.range(of: "uddg=") {
                    let encoded = String(url[uddgRange.upperBound...])
                    url = encoded.removingPercentEncoding ?? url
                }
            }

            if !title.isEmpty && !url.isEmpty {
                results.append(SearchResult(title: title, url: url, snippet: snippet))
            }
        }

        return results
    }

    private func fallbackParse(html: String) -> [SearchResult] {
        // Simpler fallback parsing
        var results: [SearchResult] = []

        // Look for result__a links
        let linkPattern = #"href="([^"]+)"[^>]*class="result__a"[^>]*>([^<]+)</a>"#
        if let regex = try? NSRegularExpression(pattern: linkPattern) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)

            for match in matches.prefix(5) {
                guard match.numberOfRanges >= 3 else { continue }

                if let urlRange = Range(match.range(at: 1), in: html),
                   let titleRange = Range(match.range(at: 2), in: html) {
                    let url = String(html[urlRange])
                    let title = String(html[titleRange]).htmlDecoded

                    results.append(SearchResult(title: title, url: url, snippet: ""))
                }
            }
        }

        return results
    }
}

// MARK: - Cache Class
private class CachedResults {
    let results: [SearchResult]
    let timestamp: Date

    init(results: [SearchResult], timestamp: Date) {
        self.results = results
        self.timestamp = timestamp
    }
}

// MARK: - Search Errors
enum SearchError: Error {
    case invalidQuery
    case invalidURL
    case requestFailed
    case parseError
}

// MARK: - HTML Decoding Extension
private extension String {
    var htmlDecoded: String {
        var result = self
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")

        // Remove HTML tags
        while let range = result.range(of: "<[^>]+>", options: .regularExpression) {
            result.removeSubrange(range)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
