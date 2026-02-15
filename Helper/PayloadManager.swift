import Foundation

/// PayloadManager: Manages bundled OCLP payloads for WiFi + Audio patching
class PayloadManager {
    
    static let payloadVersion = "13.7.2-25"
    
    static func getBundledPayloadsPath() -> String? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let payloadsPath = resourcePath + "/Payloads/ModernWireless"
        if FileManager.default.fileExists(atPath: payloadsPath) { return payloadsPath }
        return nil
    }
    
    struct PayloadFile {
        let name: String
        let bundledPath: String
        let destPath: String
    }
    
    /// WiFi payloads (Tahoe: only 3 patches)
    static func getWiFiPayloadFiles() -> [PayloadFile] {
        guard let basePath = getBundledPayloadsPath() else { return [] }
        return [
            PayloadFile(name: "wifip2pd", bundledPath: "\(basePath)/usr/libexec/wifip2pd",
                        destPath: "/usr/libexec/wifip2pd"),
            PayloadFile(name: "IO80211.framework",
                        bundledPath: "\(basePath)/System/Library/PrivateFrameworks/IO80211.framework",
                        destPath: "/System/Library/PrivateFrameworks/IO80211.framework"),
            PayloadFile(name: "WiFiPeerToPeer.framework",
                        bundledPath: "\(basePath)/System/Library/PrivateFrameworks/WiFiPeerToPeer.framework",
                        destPath: "/System/Library/PrivateFrameworks/WiFiPeerToPeer.framework"),
        ]
    }
    
    static func arePayloadsBundled() -> Bool {
        let payloads = getWiFiPayloadFiles()
        if payloads.isEmpty { return false }
        return payloads.allSatisfy { FileManager.default.fileExists(atPath: $0.bundledPath) }
    }
    
    static func verifyPayloads() -> (valid: Bool, missing: [String]) {
        let payloads = getWiFiPayloadFiles()
        let missing = payloads.filter { !FileManager.default.fileExists(atPath: $0.bundledPath) }.map { $0.name }
        return (missing.isEmpty, missing)
    }
}
