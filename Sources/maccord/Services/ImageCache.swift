import Foundation
import AppKit

/// A small async image cache: in-memory NSCache of raw image data plus
/// request coalescing so the same avatar/icon URL is fetched once.
actor ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, NSData>()
    private var inFlight: [URL: Task<Data?, Never>] = [:]
    private let session: URLSession

    init() {
        cache.countLimit = 1000
        cache.totalCostLimit = 96 * 1024 * 1024  // ~96 MB of decoded-ish data
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024,
                                   diskCapacity: 256 * 1024 * 1024)
        self.session = URLSession(configuration: config)
    }

    func data(for url: URL) async -> Data? {
        if let cached = cache.object(forKey: url as NSURL) { return cached as Data }
        if let existing = inFlight[url] { return await existing.value }

        let task = Task<Data?, Never> { [session] in
            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return nil
                }
                return data
            } catch {
                return nil
            }
        }
        inFlight[url] = task
        let data = await task.value
        inFlight[url] = nil
        if let data {
            cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        }
        return data
    }
}
