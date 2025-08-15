import Foundation

let regionalDomain = "verify-use.spur.us" // Default; may be overridden by runtime fetch

struct ResolverPluginStub: Codable {
    var ok: Bool
    var id: String
    var dns: String?
}

class DnsResolverPlugin: MonoclePlugin {
    static let dnsResolverMonoclePluginConfig = MonoclePluginConfig(pid: "p/dr", version: 1)

    // Fetch the regional domain from the control endpoint on every call, falling back to `regionalDomain` on error
    static func fetchRegionalDomain() async -> String {
        guard let url = URL(string: "https://mcl.spur.us/region") else {
            return regionalDomain
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let regionString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !regionString.isEmpty {
                print("found regional domain: \(regionString)")
                return regionString
            }
        } catch {
            // ignore error and fall back
        }

        return regionalDomain
    }

    override func execute() async throws -> Codable {
        let id = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let subdomain = id

        let region = await DnsResolverPlugin.fetchRegionalDomain()

        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(subdomain).\(region)"
        components.path = "/d/p"
        // Preserve existing id parameter used for the subdomain/resolve
        components.queryItems = [URLQueryItem(name: "s", value: id)]

        // Append common Monocle query parameters using the instance properties
        appendCommonQueryParameters(to: &components)

        guard let url = components.url else {
            return ResolverPluginStub(ok: false, id: id, dns: nil)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let dns = String(data: data, encoding: .utf8) else {
                print("HTTP Response: \(response)")
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                }
                return ResolverPluginStub(ok: false, id: id, dns: nil)
            }
            return ResolverPluginStub(ok: true, id: id, dns: dns)
        } catch {
            return ResolverPluginStub(ok: false, id: id, dns: nil)
        }
    }
}
