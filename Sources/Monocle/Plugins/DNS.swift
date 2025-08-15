import Foundation

let regionalDomain = "verify-use.spur.us" // Replace with your actual domain

struct ResolverPluginStub: Codable {
    var ok: Bool
    var id: String
    var dns: String?
}

class DnsResolverPlugin: MonoclePlugin {
    static let dnsResolverMonoclePluginConfig = MonoclePluginConfig(pid: "p/dr", version: 1, execute: execute)
    
    static func execute() async -> Codable {
        let id = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let subdomain = id
        guard let url = URL(string: "https://\(subdomain).\(regionalDomain)/d/p?s=\(id)") else {
            return ResolverPluginStub(ok: false, id: id, dns: nil)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let dns = String(data: data, encoding: .utf8) else {
                return ResolverPluginStub(ok: false, id: id, dns: nil)
            }
            return ResolverPluginStub(ok: true, id: id, dns: dns)
        } catch {
            return ResolverPluginStub(ok: false, id: id, dns: nil)
        }
    }
}
