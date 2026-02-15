import Foundation

/// Universal BCM WiFi Chipset Detection using PCI IDs
/// Reads directly from ioreg PCI tree — works even without drivers loaded
struct BCMDetector {
    
    static let broadcomVendorID = "14e4"
    
    static let deviceIDMap: [String: ChipsetInfo] = [
        // Modern Wireless (Wi-Fi + AirDrop) - BCM4360+
        "43a0": ChipsetInfo(name: "BCM4360", family: .modern, wifiSupport: true, airdropSupport: true, notes: "Full support"),
        "43a3": ChipsetInfo(name: "BCM4360", family: .modern, wifiSupport: true, airdropSupport: true, notes: "Variant"),
        "43ba": ChipsetInfo(name: "BCM43602", family: .modern, wifiSupport: true, airdropSupport: true, notes: "MacBook Pro 2015+"),
        "43b1": ChipsetInfo(name: "BCM4352", family: .modern, wifiSupport: true, airdropSupport: true, notes: "DW1560 compatible"),
        "43b2": ChipsetInfo(name: "BCM4352", family: .modern, wifiSupport: true, airdropSupport: true, notes: "Variant"),
        "43a1": ChipsetInfo(name: "BCM4350", family: .modern, wifiSupport: true, airdropSupport: true, notes: "DW1820A"),
        "43a2": ChipsetInfo(name: "BCM4350", family: .modern, wifiSupport: true, airdropSupport: true, notes: "Variant"),
        "4464": ChipsetInfo(name: "BCM4364", family: .modern, wifiSupport: true, airdropSupport: true, notes: "MacBook Pro 2018+"),
        "4433": ChipsetInfo(name: "BCM4377", family: .modern, wifiSupport: true, airdropSupport: true, notes: "MacBook Air 2020"),
        // Legacy Wireless (Wi-Fi only, no AirDrop)
        "4331": ChipsetInfo(name: "BCM4331", family: .legacy, wifiSupport: true, airdropSupport: false, notes: "WiFi only"),
        "4353": ChipsetInfo(name: "BCM43224", family: .legacy, wifiSupport: true, airdropSupport: false, notes: "WiFi only"),
        "432b": ChipsetInfo(name: "BCM4322", family: .legacy, wifiSupport: true, airdropSupport: false, notes: "Older, WiFi only"),
        "4328": ChipsetInfo(name: "BCM4321", family: .legacy, wifiSupport: true, airdropSupport: false, notes: "Older, WiFi only"),
    ]
    
    enum ChipsetFamily {
        case modern
        case legacy
        case unknown
    }
    
    struct ChipsetInfo {
        let name: String
        let family: ChipsetFamily
        let wifiSupport: Bool
        let airdropSupport: Bool
        let notes: String
    }

    struct DetectionResult {
        let detected: Bool
        let isBroadcom: Bool
        let vendorID: String
        let deviceID: String
        let chipset: String
        let info: ChipsetInfo?
        let pciPath: String
        let rawOutput: String
        
        var statusText: String {
            if !detected { return "Nenhum WiFi detectado" }
            if !isBroadcom { return "WiFi não-Broadcom: \(chipset)" }
            if let info = info { return "\(info.name) - \(info.notes)" }
            return "Broadcom 0x\(deviceID) (não mapeado)"
        }
    }
    
    // MARK: - Detection via ioreg (PCI direto, sem driver)
    
    static func detectChipset() -> DetectionResult {
        let ioregOutput = runCommand("/usr/sbin/ioreg", args: ["-r", "-d1", "-c", "IOPCIDevice", "-l"], timeout: 10.0)
        
        var vendorID = ""
        var deviceID = ""
        var chipsetName = "Unknown"
        var pciPath = ""
        var rawBlock = ""
        
        let blocks = ioregOutput.components(separatedBy: "+-o ")
        
        for block in blocks {
            guard block.contains("\"vendor-id\" = <") else { continue }
            guard let vid = extractPCIValue(from: block, key: "vendor-id") else { continue }
            if vid != "14e4" { continue }
            guard let did = extractPCIValue(from: block, key: "device-id") else { continue }
            
            if deviceIDMap[did] != nil || did.hasPrefix("43") || did.hasPrefix("44") {
                vendorID = vid
                deviceID = did
                rawBlock = String(block.prefix(300))
                for line in block.components(separatedBy: "\n") {
                    if line.contains("IOName") || line.contains("\"name\"") {
                        pciPath = line.trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
                if deviceIDMap[did] != nil { break }
            }
        }
        
        if vendorID.isEmpty {
            let spResult = detectViaSystemProfiler()
            vendorID = spResult.0; deviceID = spResult.1; rawBlock = spResult.2
        }
        
        let info = deviceIDMap[deviceID.lowercased()]
        if let knownInfo = info { chipsetName = knownInfo.name }
        
        return DetectionResult(
            detected: !vendorID.isEmpty, isBroadcom: vendorID == "14e4",
            vendorID: vendorID.isEmpty ? "N/A" : "0x\(vendorID)",
            deviceID: deviceID.isEmpty ? "N/A" : "0x\(deviceID)",
            chipset: chipsetName, info: info, pciPath: pciPath, rawOutput: rawBlock
        )
    }

    private static func extractPCIValue(from block: String, key: String) -> String? {
        let searchKey = "\"\(key)\" = <"
        guard let range = block.range(of: searchKey) else { return nil }
        let after = String(block[range.upperBound...])
        guard let endRange = after.range(of: ">") else { return nil }
        let hexData = String(after[..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard hexData.count >= 4 else { return nil }
        let byte1 = String(hexData.prefix(2))
        let byte2 = String(hexData.dropFirst(2).prefix(2))
        return (byte2 + byte1).lowercased()
    }
    
    private static func detectViaSystemProfiler() -> (String, String, String) {
        let spOutput = runCommand("/usr/sbin/system_profiler", args: ["SPPCIDataType"], timeout: 10.0)
        let devices = spOutput.components(separatedBy: "\n\n")
        for deviceBlock in devices {
            if deviceBlock.contains("Vendor ID: 0x14e4") {
                if let devRange = deviceBlock.range(of: "Device ID: 0x") {
                    let after = String(deviceBlock[devRange.upperBound...])
                    let id = String(after.prefix(4)).lowercased()
                    if deviceIDMap[id] != nil || id.hasPrefix("43") {
                        return ("14e4", id, String(deviceBlock.prefix(300)))
                    }
                }
            }
        }
        return ("", "", "")
    }
    
    static func isWiFiInterfacePresent() -> Bool {
        let output = runCommand("/sbin/ifconfig", args: ["en0"])
        return output.contains("ether") || output.contains("inet")
    }
    
    private static func runCommand(_ path: String, args: [String], timeout: TimeInterval = 5.0) -> String {
        let process = Process()
        process.launchPath = path
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let group = DispatchGroup()
        group.enter()
        do { try process.run() } catch { return "" }
        DispatchQueue.global().async { process.waitUntilExit(); group.leave() }
        let result = group.wait(timeout: .now() + timeout)
        if result == .timedOut { process.terminate(); return "" }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
