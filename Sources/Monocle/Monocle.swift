import Foundation
import UIKit

public typealias EncryptedAssessment = String

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

public struct MonocleConfig {
    public let token: String
    public var enabledPlugins: MonoclePluginOptions

    public init(token: String, enabledPlugins: MonoclePluginOptions = .all) {
        self.token = token
        self.enabledPlugins = enabledPlugins
    }
}

public struct AssessmentResponse: Codable {
    public let data: EncryptedAssessment?
    public let status: String
}

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
            pluginsList.append(MonoclePlugin(v: "0.0.1", t: "iOS", s: installID.uuidString, tk: token, config: DnsResolverPlugin.dnsResolverMonoclePluginConfig))
        }
        if config.enabledPlugins.contains(.deviceInfo) {
            pluginsList.append(MonoclePlugin(v: "0.0.1", t: "iOS", s: installID.uuidString, tk: token, config: DeviceInfoPlugin.deviceInfoPluginConfig))
        }
        if config.enabledPlugins.contains(.location) {
            pluginsList.append(MonoclePlugin(v: "0.0.1", t: "iOS", s: installID.uuidString, tk: token, config: LocationPlugin.locationPluginConfig))
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
        
        let bundlePoster = BundlePoster(v: "0.0.1", t: "iOS", s: installID.uuidString, tk: token)
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
    
}
