import CoreLocation

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let locationTimestamp: String?
}

class LocationPlugin: MonoclePlugin {
    static let locationPluginConfig = MonoclePluginConfig(pid: "p/li", version: 1)

    override func execute() async throws -> Codable {
        let locationManager = CLLocationManager()

        // Check if location services are enabled and if the app has permission to access location
        if CLLocationManager.locationServicesEnabled() {
            switch locationManager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                // Try to get the location
                let location = locationManager.location

                // We can't get the location, return default
                if location == nil {
                    return LocationData(latitude: 0, longitude: 0, locationTimestamp: nil)
                } else {
                    let timestamp = LocationPlugin.rfc3339Formatted(date: location?.timestamp ?? Date())
                    return LocationData(
                            latitude: location?.coordinate.latitude ?? 0,
                            longitude: location?.coordinate.longitude ?? 0,
                            locationTimestamp: timestamp
                    )
                }
            default:
                return LocationData(latitude: 0, longitude: 0, locationTimestamp: nil)
            }
        } else {
            return LocationData(latitude: 0, longitude: 0, locationTimestamp: nil)
        }
    }

    static func rfc3339Formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}