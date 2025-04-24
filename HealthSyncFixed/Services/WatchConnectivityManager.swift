import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable = false
    @Published var isCompanionAppInstalled = false
    
    private let session = WCSession.default
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Send Messages
    
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        guard session.activationState == .activated else {
            errorHandler?(WatchConnectivityError.sessionNotActivated)
            return
        }
        
        #if os(iOS)
        guard session.isReachable else {
            errorHandler?(WatchConnectivityError.watchNotReachable)
            return
        }
        #endif
        
        session.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }
    
    func updateFastingData(_ fastingWindow: HealthData.FastingWindow?) {
        guard let window = fastingWindow else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(window)
            
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let message: [String: Any] = ["fastingUpdate": dict]
                
                sendMessage(message, errorHandler: { error in
                    print("Failed to send fasting update: \(error.localizedDescription)")
                })
            }
        } catch {
            print("Failed to encode fasting window: \(error.localizedDescription)")
        }
    }
    
    func updateMetrics(recovery: Double, strain: Double, hrv: Double) {
        let metrics: [String: Any] = [
            "metricsUpdate": [
                "recovery": recovery,
                "strain": strain,
                "hrv": hrv
            ]
        ]
        
        sendMessage(metrics, errorHandler: { error in
            print("Failed to send metrics update: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Transfer User Defaults
    
    func transferUserInfo(_ userInfo: [String: Any]) {
        do {
            try session.updateApplicationContext(userInfo)
        } catch {
            print("Error updating application context: \(error.localizedDescription)")
        }
    }
    
    enum WatchConnectivityError: Error {
        case sessionNotActivated
        case watchNotReachable
        case encodingError
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("WCSession activation failed with error: \(error.localizedDescription)")
                return
            }
            
            self.isCompanionAppInstalled = session.isCompanionAppInstalled
            
            #if os(iOS)
            self.isReachable = session.isReachable
            #endif
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            #if os(iOS)
            self.isReachable = session.isReachable
            #endif
        }
    }
    
    // Required for iOS
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // Reactivate session if needed
        session.activate()
    }
    #endif
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message, replyHandler: replyHandler)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        // Handle fasting-related messages
        if let fastingAction = message["fastingAction"] as? String {
            switch fastingAction {
            case "start":
                if let duration = message["duration"] as? TimeInterval {
                    NotificationCenter.default.post(
                        name: Notification.Name("StartFasting"),
                        object: nil,
                        userInfo: ["duration": duration]
                    )
                }
            case "end":
                NotificationCenter.default.post(
                    name: Notification.Name("EndFasting"),
                    object: nil
                )
            case "status":
                // Reply with current fasting status
                if let replyHandler = replyHandler {
                    let fastingManager = FastingManager.shared
                    if let window = fastingManager.getCurrentFastingWindow() {
                        let isActive = !window.completed
                        let timeRemaining = fastingManager.formattedTimeRemaining(for: window)
                        let progress = fastingManager.progressPercentage(for: window)
                        
                        replyHandler([
                            "isActive": isActive,
                            "timeRemaining": timeRemaining,
                            "progress": progress
                        ])
                    } else {
                        replyHandler(["isActive": false])
                    }
                }
            default:
                break
            }
        }
        
        // Handle supplement logging
        if let supplementAction = message["supplementAction"] as? String, supplementAction == "log" {
            if let supplementName = message["name"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("LogSupplement"),
                    object: nil,
                    userInfo: ["name": supplementName]
                )
            }
        }
        
        // Handle meal logging
        if let mealAction = message["mealAction"] as? String, mealAction == "log" {
            if let mealType = message["type"] as? String {
                NotificationCenter.default.post(
                    name: Notification.Name("LogMeal"),
                    object: nil,
                    userInfo: ["type": mealType]
                )
            }
        }
    }
}