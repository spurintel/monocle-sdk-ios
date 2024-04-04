import UIKit
import Network

struct DeviceInformation: Codable {
    let name: String
    let systemName: String
    let systemVersion: String
    let model: String
    let localizedModel: String
    let identifierForVendor: String
    let isBatteryMonitoringEnabled: Bool
    let batteryState: Int
    let batteryLevel: Float
    let screenSize: String
    let brightness: Float
    let currentLocale: String
    let timeZone: String
    let thermalState: Int
    let networkType: String
}

class DeviceInfoPlugin {
    static let deviceInfoPluginConfig = MonoclePluginConfig(pid: "p/di", version: 1, execute: gatherDeviceInformation)
    
    static func gatherDeviceInformation() async -> DeviceInformation {
        // First, asynchronously get the network type
        let networkType = await getNetworkType()
        
        // Now create and return the device information including the network type
        return createDeviceInfo(withNetworkType: networkType)
    }
    
    private static func getNetworkType() async -> String {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                var networkType = "No Connection"
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        networkType = "Wi-Fi"
                    } else if path.usesInterfaceType(.cellular) {
                        networkType = "Cellular"
                    }
                }
                continuation.resume(returning: networkType)
                monitor.cancel() // Stop monitoring once we have the info
            }
            let queue = DispatchQueue(label: "NetworkMonitor")
            monitor.start(queue: queue)
        }
    }
    
    private static func createDeviceInfo(withNetworkType networkType: String) -> DeviceInformation {
        let device = UIDevice.current
        let screen = UIScreen.main
        let locale = NSLocale.current
        let processInfo = ProcessInfo.processInfo
        
        device.isBatteryMonitoringEnabled = true
        
        let deviceInfo = DeviceInformation(
            name: device.name,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            model: device.model,
            localizedModel: device.localizedModel,
            identifierForVendor: device.identifierForVendor?.uuidString ?? "",
            isBatteryMonitoringEnabled: device.isBatteryMonitoringEnabled,
            batteryState: device.batteryState.rawValue,
            batteryLevel: device.batteryLevel,
            screenSize: "\(screen.bounds.width)x\(screen.bounds.height)",
            brightness: Float(screen.brightness),
            currentLocale: locale.identifier,
            timeZone: TimeZone.current.identifier,
            thermalState: processInfo.thermalState.rawValue,
            networkType: networkType // Include the network type
        )
        
        device.isBatteryMonitoringEnabled = false
        return deviceInfo
    }
}
