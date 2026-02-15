import Foundation

/// EFIAnalyzer: Dynamic EFI partition mount for boot disk
/// Detects physical boot disk via APFS Physical Store, mounts correct EFI
class EFIAnalyzer {
    
    struct MountResult {
        let success: Bool
        let message: String
    }
    
    // MARK: - Check if EFI is mounted
    
    static func isEFIMounted() -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: "/Volumes/EFI/EFI/OC/config.plist")
    }
    
    // MARK: - Find EFI partition (boot disk aware)
    
    static func findEFIPartition() -> String? {
        // Get root volume info
        let diskInfo = runCmd("/usr/sbin/diskutil", args: ["info", "/"])
        
        // Look for APFS Physical Store (e.g. disk0s2) → strip to disk0 → EFI is disk0s1
        for line in diskInfo.components(separatedBy: "\n") {
            if line.contains("APFS Physical Store") || line.contains("Part of Whole") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    var disk = parts[1].trimmingCharacters(in: .whitespaces)
                    // disk0s2 → disk0
                    while disk.last?.isNumber == true || disk.last == "s" {
                        if disk.hasSuffix("s") && disk.dropLast().last?.isNumber == true { break }
                        disk = String(disk.dropLast())
                    }
                    if disk.last == "s" { disk = String(disk.dropLast()) }
                    return "\(disk)s1"
                }
            }
        }

        // Fallback: parse diskutil list for EFI GUID
        let listOutput = runCmd("/usr/sbin/diskutil", args: ["list"])
        for line in listOutput.components(separatedBy: "\n") {
            if line.contains("EFI") && line.contains("disk") {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                if let lastPart = parts.last, lastPart.hasPrefix("disk") {
                    return lastPart
                }
            }
        }
        
        return "disk0s1" // Ultimate fallback
    }
    
    // MARK: - Mount EFI
    
    static func mountEFI() -> MountResult {
        if isEFIMounted() { return MountResult(success: true, message: "EFI já montada") }
        
        guard let efiDisk = findEFIPartition() else {
            return MountResult(success: false, message: "Partição EFI não encontrada")
        }
        
        // Method 1: diskutil mount
        let script1 = "do shell script \"diskutil mount \(efiDisk)\" with administrator privileges"
        let r1 = runOsascript(script1)
        if r1.success && isEFIMounted() {
            return MountResult(success: true, message: "EFI montada (\(efiDisk))")
        }
        
        // Method 2: mount_msdos fallback
        let script2 = "do shell script \"mkdir -p /Volumes/EFI && mount_msdos /dev/\(efiDisk) /Volumes/EFI\" with administrator privileges"
        let r2 = runOsascript(script2)
        if r2.success && isEFIMounted() {
            return MountResult(success: true, message: "EFI montada via mount_msdos (\(efiDisk))")
        }
        
        return MountResult(success: false, message: "Falha ao montar EFI (\(efiDisk))")
    }
    
    // MARK: - Revert Snapshot
    
    static func revertSnapshot() -> MountResult {
        let script = "do shell script \"bless --mount / --bootefi --last-sealed-snapshot\" with administrator privileges"
        let result = runOsascript(script)
        if result.success {
            return MountResult(success: true, message: "Snapshot revertido. Reinicie o Mac.")
        }
        return MountResult(success: false, message: "Erro ao reverter: \(result.output)")
    }

    // MARK: - Helpers
    
    private static func runCmd(_ path: String, args: [String]) -> String {
        let p = Process(); p.launchPath = path; p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        do { try p.run(); p.waitUntilExit() } catch { return "" }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
    
    private static func runOsascript(_ script: String) -> (success: Bool, output: String) {
        let p = Process(); p.launchPath = "/usr/bin/osascript"; p.arguments = ["-e", script]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        do {
            try p.run(); p.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return (p.terminationStatus == 0, out)
        } catch { return (false, error.localizedDescription) }
    }
    
    /// Get system volume device (for root patches)
    static func getSystemVolumeDevice() -> String? {
        let output = runCmd("/usr/sbin/diskutil", args: ["info", "/"])
        for line in output.components(separatedBy: "\n") {
            if line.contains("Device Node:") {
                var device = line.replacingOccurrences(of: "Device Node:", with: "").trimmingCharacters(in: .whitespaces)
                if device.hasSuffix("s1") && device.filter({ $0 == "s" }).count >= 2 {
                    device = String(device.dropLast(2))
                }
                return device
            }
        }
        return nil
    }
}
