import Foundation

enum BundlePosterError: Error {
    case invalidURL
    case serverError(statusCode: Int)
    case invalidResponseData
    case networkFailure(Error)
}

class BundlePoster {
    var v: String
    var t: String
    var s: String
    var tk: String
    
    init(v: String, t: String, s: String, tk: String) {
        self.v = v
        self.t = t
        self.s = s
        self.tk = tk
    }
    
    func postBundle(jsonBody: String) async -> Result<String, BundlePosterError> {
        guard let url = URL(string: "https://mcl.spur.dev/r/bundle?v=\(v)&t=\(t)&s=\(s)&tk=\(tk)") else {
            return .failure(.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(jsonBody.utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1))
            }
            
            if httpResponse.statusCode == 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    return .success(responseString)
                } else {
                    return .failure(.invalidResponseData)
                }
            } else {
                return .failure(.serverError(statusCode: httpResponse.statusCode))
            }
        } catch {
            return .failure(.networkFailure(error))
        }
    }
}
