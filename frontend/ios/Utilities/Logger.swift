import Foundation
import os.log

// MARK: - Log Level
enum LogLevel: String, CaseIterable {
    case verbose = "VERBOSE"
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case fatal = "FATAL"
    
    var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .fatal: return "💀"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .verbose, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error, .fatal: return .error
        }
    }
}

// MARK: - Logger
class Logger {
    static let shared = Logger()
    
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.golfswingai"
    private var loggers: [String: OSLog] = [:]
    
    // Configuration
    private var enabledLevels: Set<LogLevel> = {
        #if DEBUG
        return Set(LogLevel.allCases)
        #else
        return [.info, .warning, .error, .fatal]
        #endif
    }()
    
    private var enableConsoleLogging: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    private init() {}
    
    // MARK: - Public Logging Methods
    func verbose(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.verbose, message: message, category: category, file: file, function: function, line: line)
    }
    
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, category: category, file: file, function: function, line: line)
    }
    
    func fatal(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.fatal, message: message, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - API Specific Logging
    func logAPIRequest(_ request: URLRequest, category: LogCategory = .network) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "UNKNOWN"
        let headers = request.allHTTPHeaderFields?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? "None"
        
        let message = """
        🌐 API Request
        Method: \(method)
        URL: \(url)
        Headers: \(headers)
        Body Size: \(request.httpBody?.count ?? 0) bytes
        """
        
        debug(message, category: category)
    }
    
    func logAPIResponse(_ response: URLResponse?, data: Data?, error: Error?, category: LogCategory = .network) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let dataSize = data?.count ?? 0
        
        if let error = error {
            let message = """
            🌐 API Response - ERROR
            Status: \(statusCode)
            Data Size: \(dataSize) bytes
            Error: \(error.localizedDescription)
            """
            self.error(message, category: category)
        } else {
            let message = """
            🌐 API Response - SUCCESS
            Status: \(statusCode)
            Data Size: \(dataSize) bytes
            """
            debug(message, category: category)
        }
    }
    
    func logCacheOperation(_ operation: String, key: String, hit: Bool? = nil, category: LogCategory = .cache) {
        var message = "💾 Cache \(operation): \(key)"
        if let hit = hit {
            message += hit ? " - HIT" : " - MISS"
        }
        debug(message, category: category)
    }
    
    // MARK: - Private Methods
    private func log(_ level: LogLevel, message: String, category: LogCategory, file: String, function: String, line: Int) {
        guard enabledLevels.contains(level) else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        
        // Console logging for debug builds
        if enableConsoleLogging {
            let consoleMessage = "\(level.emoji) [\(level.rawValue)] [\(category.rawValue)] \(timestamp) \(fileName):\(line) \(function) - \(message)"
            print(consoleMessage)
        }
        
        // OS Log
        let osLog = getOSLog(for: category)
        let osMessage = "[\(fileName):\(line)] \(function) - \(message)"
        os_log("%{public}@", log: osLog, type: level.osLogType, osMessage)
    }
    
    private func getOSLog(for category: LogCategory) -> OSLog {
        if let existingLogger = loggers[category.rawValue] {
            return existingLogger
        }
        
        let logger = OSLog(subsystem: subsystem, category: category.rawValue)
        loggers[category.rawValue] = logger
        return logger
    }
}

// MARK: - Log Categories
enum LogCategory: String, CaseIterable {
    case general = "General"
    case network = "Network"
    case cache = "Cache"
    case ui = "UI"
    case auth = "Authentication"
    case video = "Video"
    case analysis = "Analysis"
    case chat = "Chat"
    case tracking = "BallTracking"
    case storage = "Storage"
}

// MARK: - Date Formatter Extension
private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Convenience Extensions
extension Logger {
    // Network request logging
    func logNetworkRequest<T: Codable>(_ request: URLRequest, payload: T? = nil) {
        var message = "🌐 Network Request: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "UNKNOWN")"
        
        if let payload = payload,
           let jsonData = try? JSONEncoder().encode(payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            message += "\nPayload: \(jsonString)"
        }
        
        debug(message, category: .network)
    }
    
    func logNetworkResponse<T: Codable>(_ response: Result<T, Error>, for request: URLRequest) {
        let url = request.url?.absoluteString ?? "UNKNOWN"
        
        switch response {
        case .success(let data):
            if let jsonData = try? JSONEncoder().encode(data),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                debug("🌐 Network Success: \(url)\nResponse: \(jsonString)", category: .network)
            } else {
                debug("🌐 Network Success: \(url)", category: .network)
            }
        case .failure(let error):
            error("🌐 Network Error: \(url)\nError: \(error.localizedDescription)", category: .network)
        }
    }
}