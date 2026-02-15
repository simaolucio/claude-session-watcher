import Foundation
import Combine

// MARK: - Copilot Usage Models

struct CopilotUsage: Equatable {
    var premiumRequestsUsed: Int
    var premiumRequestsLimit: Int // 0 = unknown
    var percent: Double // 0-100
    var byModel: [(model: String, count: Int)]
    
    static func == (lhs: CopilotUsage, rhs: CopilotUsage) -> Bool {
        lhs.premiumRequestsUsed == rhs.premiumRequestsUsed
        && lhs.premiumRequestsLimit == rhs.premiumRequestsLimit
        && lhs.percent == rhs.percent
    }
    
    static let empty = CopilotUsage(premiumRequestsUsed: 0, premiumRequestsLimit: 0, percent: 0, byModel: [])
}

enum CopilotUsageState: Equatable {
    case notConnected
    case loading
    case loaded(CopilotUsage)
    case error(String)
}

// MARK: - Copilot Usage Manager

class CopilotUsageManager: ObservableObject {
    static let shared = CopilotUsageManager()
    
    @Published var state: CopilotUsageState = .notConnected
    @Published var lastUpdateText: String = "never"
    
    private var lastUpdateTime: Date?
    private var refreshTimer: Timer?
    private var textTimer: Timer?
    private let authManager = GitHubAuthManager.shared
    
    // Known plan limits (premium requests/month)
    private static let planLimits: [String: Int] = [
        "free": 50,
        "pro": 300,
        "pro+": 1500,
        "business": 300,
        "enterprise": 1000,
    ]
    
    private init() {}
    
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        textTimer?.invalidate()
        
        // Copilot billing data is monthly, no need to poll aggressively
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        
        textTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateLastUpdateText()
        }
        
        refresh()
    }
    
    func refresh() {
        guard authManager.isConnected, let token = authManager.accessToken else {
            state = .notConnected
            return
        }
        
        let username = authManager.username
        guard !username.isEmpty else {
            if case .loaded = state { } else { state = .loading }
            // Username not loaded yet, retry shortly
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.refresh()
            }
            return
        }
        
        if case .loaded = state { } else { state = .loading }
        
        fetchPremiumRequestUsage(token: token, username: username)
    }
    
    private func fetchPremiumRequestUsage(token: String, username: String) {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        let urlString = "https://api.github.com/users/\(username)/settings/billing/premium_request/usage?year=\(year)&month=\(month)"
        
        guard let url = URL(string: urlString) else {
            state = .error("Invalid URL for billing API.")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        print("[Copilot] fetching: \(urlString)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("[Copilot] network error: \(error)")
                    self.state = .error("Network error: \(error.localizedDescription)")
                    return
                }
                
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[Copilot] HTTP \(statusCode)")
                
                guard let data = data else {
                    self.state = .error("No data received.")
                    return
                }
                
                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                print("[Copilot] body: \(bodyStr.prefix(500))")
                
                if statusCode == 401 || statusCode == 403 {
                    self.state = .error("Access denied (HTTP \(statusCode)). The token may lack the required scope.")
                    return
                }
                
                if statusCode == 404 {
                    self.state = .error("Billing API not found. You may need a Copilot Pro subscription.")
                    return
                }
                
                if statusCode < 200 || statusCode >= 300 {
                    self.state = .error("GitHub API error (HTTP \(statusCode))")
                    return
                }
                
                self.parseUsageResponse(data)
            }
        }.resume()
    }
    
    private func parseUsageResponse(_ data: Data) {
        let result = CopilotUsageParser.parseResponse(data)
        switch result {
        case .success(let usage):
            print("[Copilot] parsed: used=\(usage.premiumRequestsUsed)/\(usage.premiumRequestsLimit) (\(String(format: "%.0f", usage.percent))%) models=\(usage.byModel.count)")
            state = .loaded(usage)
            lastUpdateTime = Date()
            lastUpdateText = "just now"
        case .failure:
            state = .error("Invalid response format.")
        }
    }
    
    private func updateLastUpdateText() {
        guard let t = lastUpdateTime else { lastUpdateText = "never"; return }
        let s = Int(Date().timeIntervalSince(t))
        if s < 5 { lastUpdateText = "just now" }
        else if s < 60 { lastUpdateText = "\(s)s ago" }
        else if s < 3600 { lastUpdateText = "\(s / 60)m ago" }
        else { lastUpdateText = "\(s / 3600)h ago" }
    }
    
    deinit {
        refreshTimer?.invalidate()
        textTimer?.invalidate()
    }
}
