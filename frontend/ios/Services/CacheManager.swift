import Foundation
import UIKit

// MARK: - Cache Configuration
struct CacheConfiguration {
    let maxMemorySize: Int
    let maxDiskSize: Int
    let defaultExpiration: TimeInterval
    let cleanupInterval: TimeInterval
    
    static let `default` = CacheConfiguration(
        maxMemorySize: 50 * 1024 * 1024, // 50MB
        maxDiskSize: 200 * 1024 * 1024,  // 200MB
        defaultExpiration: 3600,          // 1 hour
        cleanupInterval: 300              // 5 minutes
    )
}

// MARK: - Cache Item
struct CacheItem<T: Codable>: Codable {
    let data: T
    let timestamp: Date
    let expiration: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expiration
    }
    
    var remainingTime: TimeInterval {
        expiration - Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Cache Manager
class CacheManager {
    static let shared = CacheManager()
    
    private let logger = Logger.shared
    private let configuration: CacheConfiguration
    private let memoryCache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let queue = DispatchQueue(label: "com.golfswingai.cache", qos: .utility)
    private var cleanupTimer: Timer?
    
    // Cache statistics
    private var hitCount: Int = 0
    private var missCount: Int = 0
    
    var hitRate: Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0.0
    }
    
    init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration
        
        // Setup cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent("GolfSwingAI")
        
        setupCache()
        startCleanupTimer()
        setupMemoryWarningNotification()
    }
    
    deinit {
        cleanupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Cache Methods
    
    func get<T: Codable>(_ key: String, type: T.Type) async -> T? {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(returning: nil)
                return
            }
            queue.async {
                // Check memory cache first
                if let memoryData = self.getFromMemory(key),
                   let item = try? JSONDecoder().decode(CacheItem<T>.self, from: memoryData) {
                    
                    if !item.isExpired {
                        self.hitCount += 1
                        self.logger.logCacheOperation("GET", key: key, hit: true)
                        continuation.resume(returning: item.data)
                        return
                    } else {
                        self.removeFromMemory(key)
                    }
                }
                
                // Check disk cache
                if let diskData = self.getFromDisk(key),
                   let item = try? JSONDecoder().decode(CacheItem<T>.self, from: diskData) {
                    
                    if !item.isExpired {
                        self.hitCount += 1
                        self.logger.logCacheOperation("GET", key: key, hit: true)
                        
                        // Promote to memory cache
                        self.setInMemory(key, data: diskData)
                        
                        continuation.resume(returning: item.data)
                        return
                    } else {
                        self.removeFromDisk(key)
                    }
                }
                
                self.missCount += 1
                self.logger.logCacheOperation("GET", key: key, hit: false)
                continuation.resume(returning: nil)
            }
        }
    }
    
    func set<T: Codable>(_ key: String, data: T, expiration: TimeInterval? = nil) async {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume()
                return
            }
            queue.async {
                let item = CacheItem(
                    data: data,
                    timestamp: Date(),
                    expiration: expiration ?? self.configuration.defaultExpiration
                )
                
                guard let encodedData = try? JSONEncoder().encode(item) else {
                    self.logger.error("Failed to encode cache item for key: \(key)", category: .cache)
                    continuation.resume()
                    return
                }
                
                // Save to memory cache
                self.setInMemory(key, data: encodedData)
                
                // Save to disk cache
                self.setOnDisk(key, data: encodedData)
                
                self.logger.logCacheOperation("SET", key: key)
                continuation.resume()
            }
        }
    }
    
    func remove(_ key: String) async {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume()
                return
            }
            queue.async {
                self.removeFromMemory(key)
                self.removeFromDisk(key)
                self.logger.logCacheOperation("REMOVE", key: key)
                continuation.resume()
            }
        }
    }
    
    func clear() async {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume()
                return
            }
            queue.async {
                self.memoryCache.removeAllObjects()
                
                if self.fileManager.fileExists(atPath: self.cacheDirectory.path) {
                    try? self.fileManager.removeItem(at: self.cacheDirectory)
                    self.createCacheDirectory()
                }
                
                self.hitCount = 0
                self.missCount = 0
                
                self.logger.info("Cache cleared", category: .cache)
                continuation.resume()
            }
        }
    }
    
    func getCacheSize() async -> (memory: Int, disk: Int) {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(returning: (memory: 0, disk: 0))
                return
            }
            queue.async {
                let diskSize = self.calculateDiskCacheSize()
                // Memory size is managed by NSCache automatically
                continuation.resume(returning: (memory: 0, disk: diskSize))
            }
        }
    }
    
    func getCacheStatistics() async -> CacheStatistics {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(returning: CacheStatistics(hitCount: 0, missCount: 0, hitRate: 0.0, memorySize: 0, diskSize: 0, itemCount: 0))
                return
            }
            queue.async {
                let diskSize = self.calculateDiskCacheSize()
                let stats = CacheStatistics(
                    hitCount: self.hitCount,
                    missCount: self.missCount,
                    hitRate: self.hitRate,
                    memorySize: 0, // NSCache doesn't expose current size
                    diskSize: diskSize,
                    itemCount: self.countDiskItems()
                )
                continuation.resume(returning: stats)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCache() {
        // Configure memory cache
        memoryCache.totalCostLimit = configuration.maxMemorySize
        memoryCache.name = "GolfSwingAI.MemoryCache"
        
        // Create cache directory
        createCacheDirectory()
        
        logger.info("Cache manager initialized with memory: \(configuration.maxMemorySize / 1024 / 1024)MB, disk: \(configuration.maxDiskSize / 1024 / 1024)MB", category: .cache)
    }
    
    private func createCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func getFromMemory(_ key: String) -> Data? {
        return memoryCache.object(forKey: NSString(string: key)) as Data?
    }
    
    private func setInMemory(_ key: String, data: Data) {
        memoryCache.setObject(NSData(data: data), forKey: NSString(string: key), cost: data.count)
    }
    
    private func removeFromMemory(_ key: String) {
        memoryCache.removeObject(forKey: NSString(string: key))
    }
    
    private func getFromDisk(_ key: String) -> Data? {
        let url = diskURL(for: key)
        return try? Data(contentsOf: url)
    }
    
    private func setOnDisk(_ key: String, data: Data) {
        let url = diskURL(for: key)
        try? data.write(to: url)
    }
    
    private func removeFromDisk(_ key: String) {
        let url = diskURL(for: key)
        try? fileManager.removeItem(at: url)
    }
    
    private func diskURL(for key: String) -> URL {
        let hashedKey = key.sha256
        return cacheDirectory.appendingPathComponent(hashedKey)
    }
    
    private func calculateDiskCacheSize() -> Int {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    private func countDiskItems() -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return 0
        }
        return contents.count
    }
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: configuration.cleanupInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.performCleanup()
            }
        }
    }
    
    private func performCleanup() async {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume()
                return
            }
            queue.async {
                self.cleanupExpiredItems()
                self.enforceStorageLimits()
                continuation.resume()
            }
        }
    }
    
    private func cleanupExpiredItems() {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        var removedCount = 0
        for case let fileURL as URL in enumerator {
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            
            // Try to decode as any CacheItem to check expiration
            if let item = try? JSONDecoder().decode(CacheItem<String>.self, from: data) {
                if item.isExpired {
                    try? fileManager.removeItem(at: fileURL)
                    removedCount += 1
                }
            }
        }
        
        if removedCount > 0 {
            logger.info("Cleanup removed \(removedCount) expired cache items", category: .cache)
        }
    }
    
    private func enforceStorageLimits() {
        let currentSize = calculateDiskCacheSize()
        guard currentSize > configuration.maxDiskSize else { return }
        
        // Get all files sorted by modification date (oldest first)
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return
        }
        
        var files: [(url: URL, date: Date, size: Int)] = []
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
               let modificationDate = resourceValues.contentModificationDate,
               let fileSize = resourceValues.fileSize {
                files.append((url: fileURL, date: modificationDate, size: fileSize))
            }
        }
        
        files.sort { $0.date < $1.date }
        
        var sizeToRemove = currentSize - configuration.maxDiskSize
        var removedCount = 0
        
        for file in files {
            try? fileManager.removeItem(at: file.url)
            sizeToRemove -= file.size
            removedCount += 1
            
            if sizeToRemove <= 0 {
                break
            }
        }
        
        logger.info("Storage limit enforcement removed \(removedCount) cache items", category: .cache)
    }
    
    private func setupMemoryWarningNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
        logger.warning("Memory cache cleared due to memory warning", category: .cache)
    }
}

// MARK: - Cache Statistics
struct CacheStatistics {
    let hitCount: Int
    let missCount: Int
    let hitRate: Double
    let memorySize: Int
    let diskSize: Int
    let itemCount: Int
    
    var formattedHitRate: String {
        String(format: "%.1f%%", hitRate * 100)
    }
    
    var formattedDiskSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(diskSize), countStyle: .binary)
    }
}

// MARK: - String Extension for Hashing
private extension String {
    var sha256: String {
        guard let data = self.data(using: .utf8) else { return self }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Import CommonCrypto
import CommonCrypto

// MARK: - Cache Key Generation
extension CacheManager {
    static func cacheKey(for endpoint: String, parameters: [String: Any] = [:]) -> String {
        var components = [endpoint]
        
        let sortedParams = parameters.sorted { $0.key < $1.key }
        for (key, value) in sortedParams {
            components.append("\(key)=\(value)")
        }
        
        return components.joined(separator: "&")
    }
    
    static func cacheKey(for request: URLRequest) -> String {
        var components: [String] = []
        
        if let url = request.url {
            components.append(url.absoluteString)
        }
        
        if let method = request.httpMethod {
            components.append("method:\(method)")
        }
        
        if let headers = request.allHTTPHeaderFields {
            let sortedHeaders = headers.sorted { $0.key < $1.key }
            for (key, value) in sortedHeaders {
                // Skip authorization headers for security
                if !key.lowercased().contains("auth") {
                    components.append("header:\(key)=\(value)")
                }
            }
        }
        
        return components.joined(separator: "&").sha256
    }
}