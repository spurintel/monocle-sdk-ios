import Foundation

// Simple config container for plugin metadata
struct MonoclePluginConfig {
    let pid: String
    var version: Int

    init(pid: String, version: Int) {
        self.pid = pid
        self.version = version
    }
}

struct MonoclePluginResponse: Codable {
    let pid: String
    let version: Int
    let start: Date
    var end: Date?
    var data: String? // Serialized response data
    var error: String? // Error message if any
    
    enum CodingKeys: String, CodingKey {
        case pid, version, data, error
        case start, end
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pid, forKey: .pid)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encode(rfc3339Formatted(date: start), forKey: .start)
        if let endDate = end {
            try container.encode(rfc3339Formatted(date: endDate), forKey: .end)
        }
    }
}

// A class to represent a plugin
class MonoclePlugin {
    let pid: String
    private let version: Int
    var v: String
    var t: String
    var s: String
    var tk: String

    init(v: String, t: String, s: String, tk: String, pid: String, version: Int) {
        self.pid = pid
        self.version = version
        self.v = v
        self.t = t
        self.s = s
        self.tk = tk
    }

    // Subclasses should override this to perform their work and return Codable data
    func execute() async throws -> Codable {
        fatalError("Subclasses must override execute()")
    }

    func trigger() async -> MonoclePluginResponse {
        let start = Date()
        var response = MonoclePluginResponse(pid: self.pid, version: self.version, start: start, end: nil, data: nil, error: nil)

        do {
            let data = try await execute()
            response.data = serialize(data: data)
        } catch {
            response.error = error.localizedDescription
        }
        response.end = Date()

        return response
    }

    func appendCommonQueryParameters(to components: inout URLComponents) {
        let commonParams = [
            URLQueryItem(name: "v", value: v),
            URLQueryItem(name: "t", value: t),
            URLQueryItem(name: "s", value: s),
            URLQueryItem(name: "tk", value: tk)
        ]

        if components.queryItems == nil {
            components.queryItems = commonParams
        } else {
            components.queryItems?.append(contentsOf: commonParams)
        }
    }
}

func serialize(data: Codable) -> String {
    let encoder = JSONEncoder()
    do {
        let jsonData = try encoder.encode(data)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
    } catch {
        print("Error serializing data to JSON: \(error)")
    }
    return "{}" // Return an empty JSON object string in case of failure
}

func rfc3339Formatted(date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: date)
}
