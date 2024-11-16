import Foundation
import UIKit

public typealias EncryptedAssessment = String

struct MonocleConstants {
    static let sdkVersion = "0.0.1"
    static let platformType = "iOS"
}

public struct MonoclePluginOptions: OptionSet {
    public let rawValue: Int
    
    public static let dns = MonoclePluginOptions(rawValue: 1 << 0)
    public static let deviceInfo = MonoclePluginOptions(rawValue: 1 << 1)
    public static let location = MonoclePluginOptions(rawValue: 1 << 2)
    public static let all: MonoclePluginOptions = [.dns, .deviceInfo, .location]
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/// Monocle configuration
/// - Parameters:
///   - token: Monocle site-token String unique to your deployment. From https://app.spur.us/monocle
///   - enabledPlugins: Select what plugins are enabled, defaults to .all
///   - decryptionToken: Optionally add your decryption token for decrypting data using a spur managed deployment
public struct MonocleConfig {
    public let token: String
    public var enabledPlugins: MonoclePluginOptions
    public var decryptionToken: String?
    
    public init(token: String, enabledPlugins: MonoclePluginOptions = .all, decryptionToken: String? = nil) {
        self.token = token
        self.enabledPlugins = enabledPlugins
        self.decryptionToken = decryptionToken
    }
}

public struct AssessmentResponse: Codable {
    public let data: EncryptedAssessment?
    public let status: String
}

public struct DecryptedAssessment: Codable {
    /// Flag indicating whether or not this connection was detected to be originating from a VPN
    public let vpn: Bool?
    
    /// Flag indicating whether or not this connection was detected to be originating from a proxy of any type (datacenter or residential)
    public let proxied: Bool?
    
    /// Flag indicating whether or not this connection was detected to be originating from IP space known to host anonymizing infrastructure - this is a modifier to vpn and proxied and will never be true by itself
    public let anon: Bool?
    
    /// Flag indicating whether or not this connection was detected to be originating from a remote desktop service
    public let rdp: Bool?
    
    /// Flag indicating whether or not this connection was detected to be originating from a datacenter
    public let dch: Bool?
    
    /// Country code of the source IP address (ISO 3166 ALPHA-2)
    public let cc: String?
    
    /// Source IPv4 address as seen by Monocle
    public let ip: String?
    
    /// If applicable, source IPv6 address as seen by Monocle
    public let ipv6: String?
    
    /// ISO 8601 datetime format of the Monocle Assessment generation
    public let ts: Date?
    
    /// Flag indicating if the Monocle process completed fully; a false value is indicative of a higher chance of false positives/negatives
    public let complete: Bool?
    
    /// Unique Monocle-generated ID identifying the generated Monocle Assessment
    public let id: String?
    
    /// Site ID, arbitrary ID provided by the user at time of Monocle Site Token generation
    public let sid: String?
}

/// Monocle class
///  - Parameters:
///    - config: MonocleConfig object instantiated with a site-token
///  - Returns: AssessmentResponse object
public class Monocle {
    public static let shared: Monocle = Monocle()
    
    public let token: String
    public let installID: UUID
    
    private static var config: MonocleConfig?
    
    private let plugins: [MonoclePlugin]
    
    public class func setup(_ config: MonocleConfig) {
        Monocle.config = config
    }
    
    private init() {
        guard let config = Monocle.config else {
            fatalError("Error - you must call setup before accessing Monocle.shared")
        }
        
        token = config.token
        installID = UIDevice.current.identifierForVendor ?? UUID()
        var pluginsList: [MonoclePlugin] = []
        
        if config.enabledPlugins.contains(.dns) {
            pluginsList.append(MonoclePlugin(v: MonocleConstants.sdkVersion, t: MonocleConstants.platformType, s: installID.uuidString, tk: token, config: DnsResolverPlugin.dnsResolverMonoclePluginConfig))
        }
        if config.enabledPlugins.contains(.deviceInfo) {
            pluginsList.append(MonoclePlugin(v: MonocleConstants.sdkVersion, t: MonocleConstants.platformType, s: installID.uuidString, tk: token, config: DeviceInfoPlugin.deviceInfoPluginConfig))
        }
        if config.enabledPlugins.contains(.location) {
            pluginsList.append(MonoclePlugin(v: MonocleConstants.sdkVersion, t: MonocleConstants.platformType, s: installID.uuidString, tk: token, config: LocationPlugin.locationPluginConfig))
        }
        
        plugins = pluginsList
    }
    
    struct BundlePostData: Codable {
        let h: [MonoclePluginResponse]
    }
    
    public func assess() async -> AssessmentResponse {
        var pluginResults: [MonoclePluginResponse] = []
        for plugin in self.plugins {
            let result = await plugin.trigger()
            pluginResults.append(result)
        }
        
        guard let jsonData = try? JSONEncoder().encode(BundlePostData(h: pluginResults)) else {
            print("Error encoding plugin results data")
            return AssessmentResponse(data: nil, status: "Error encoding plugin results data")
        }
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Error converting JSON data to String")
            return AssessmentResponse(data: nil, status: "Error converting JSON data to String")
        }
        
        print("sending data: \(jsonString)")
        
        let bundlePoster = BundlePoster(v: MonocleConstants.sdkVersion, t: MonocleConstants.platformType, s: installID.uuidString, tk: token)
        let postResult = await bundlePoster.postBundle(jsonBody: jsonString)
        switch postResult {
        case .success(let response):
            do {
                // Assuming the server response is a JSON string that can be decoded into an AssessmentResponse
                let responseData = Data(response.utf8)
                let assessmentResponse = try JSONDecoder().decode(AssessmentResponse.self, from: responseData)
                print("Success: \(assessmentResponse)")
                return assessmentResponse
            } catch {
                print("Error decoding assessment response: \(error)")
                return AssessmentResponse(data: nil, status: "Error decoding assessment response")
            }
        case .failure(let error):
            print("Error posting bundle: \(error)")
            return AssessmentResponse(data: nil, status: error.localizedDescription)
        }
    }
    
    /// Decrypts the encrypted assessment data using the provided decryption token and parses it into a `DecryptedAssessment` struct.
    ///
    /// - Parameter encryptedData: The encrypted assessment data as a `String`.
    /// - Returns: A `Result<DecryptedAssessment, Error>` containing the decrypted assessment or an error.
    public func decryptAssessment(encryptedData: String) async -> Result<DecryptedAssessment, Error> {
        guard let decryptionToken = Monocle.config?.decryptionToken, !decryptionToken.isEmpty else {
            return .failure(NSError(domain: "MonocleErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Decryption token is not set"]))
        }
        
        // Prepare the URL
        guard let url = URL(string: "https://decrypt.mcl.spur.us/api/v1/assessment") else {
            return .failure(NSError(domain: "MonocleErrorDomain", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(decryptionToken, forHTTPHeaderField: "TOKEN")
        
        // Set the encrypted data as the HTTP body
        request.httpBody = encryptedData.data(using: .utf8)
        
        do {
            // Perform the request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check the response status code
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                // Decode the data into DecryptedAssessment
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601 // Assuming the 'ts' field uses ISO 8601 format
                
                let decryptedAssessment = try decoder.decode(DecryptedAssessment.self, from: data)
                
                return .success(decryptedAssessment)
            } else {
                // Handle HTTP errors
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                return .failure(NSError(domain: "MonocleErrorDomain", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorDescription]))
            }
        } catch {
            // Handle networking and decoding errors
            return .failure(error)
        }
    }
    
}
