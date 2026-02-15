import Foundation

/// KDKDetector: Detecta se o Kernel Debug Kit (KDK) está instalado
/// KDK é necessário para root patches de áudio no macOS Sonoma/Sequoia/Tahoe
class KDKDetector {
    
    static let kdkBasePath = "/Library/Developer/KDKs"
    
    struct KDKInfo {
        let installed: Bool
        let version: String?
        let path: String?
        let matchesOS: Bool
        let osVersion: String
    }
    
    struct KDKInstruction {
        let steps: [String]
        let downloadURL: String
    }
    
    // MARK: - Detect KDK
    
    static func detect() -> KDKInfo {
        let fm = FileManager.default
        let osVersion = getOSVersion()
        let osBuild = getOSBuild()
        
        // KDK fica em /Library/Developer/KDKs/KDK_macOS_XX.X_YYYYYY.kdk/
        guard fm.fileExists(atPath: kdkBasePath),
              let kdks = try? fm.contentsOfDirectory(atPath: kdkBasePath) else {
            return KDKInfo(installed: false, version: nil, path: nil, matchesOS: false, osVersion: osVersion)
        }

        let kdkDirs = kdks.filter { $0.hasPrefix("KDK_") && $0.hasSuffix(".kdk") }
        
        if kdkDirs.isEmpty {
            return KDKInfo(installed: false, version: nil, path: nil, matchesOS: false, osVersion: osVersion)
        }
        
        // Procurar KDK que corresponde à versão atual do macOS
        var bestMatch: (String, String)? = nil // (dir, version)
        
        for kdk in kdkDirs {
            let kdkPath = "\(kdkBasePath)/\(kdk)"
            // KDK_macOS_15.3_24D60.kdk → extrair versão
            let parts = kdk.replacingOccurrences(of: "KDK_macOS_", with: "")
                           .replacingOccurrences(of: ".kdk", with: "")
            // parts = "15.3_24D60"
            let versionParts = parts.components(separatedBy: "_")
            let kdkVersion = versionParts.first ?? ""
            let kdkBuild = versionParts.count > 1 ? versionParts[1] : ""
            
            // Match exato por build number é ideal
            if kdkBuild == osBuild {
                return KDKInfo(installed: true, version: parts, path: kdkPath, matchesOS: true, osVersion: osVersion)
            }
            
            // Match por versão principal (fallback)
            if osVersion.hasPrefix(kdkVersion) || kdkVersion.hasPrefix(osVersion.components(separatedBy: ".").prefix(2).joined(separator: ".")) {
                bestMatch = (kdkPath, parts)
            }
        }
        
        if let match = bestMatch {
            return KDKInfo(installed: true, version: match.1, path: match.0, matchesOS: true, osVersion: osVersion)
        }
        
        // KDK existe mas não corresponde ao macOS atual
        let firstKDK = kdkDirs.first ?? ""
        return KDKInfo(installed: true, version: firstKDK, path: "\(kdkBasePath)/\(firstKDK)", matchesOS: false, osVersion: osVersion)
    }

    // MARK: - Instructions for user
    
    static func getInstallInstructions() -> KDKInstruction {
        let osVersion = getOSVersion()
        return KDKInstruction(
            steps: [
                "1. Acesse https://developer.apple.com/download/all/ (precisa de Apple ID grátis)",
                "2. Pesquise por 'Kernel Debug Kit' na barra de busca",
                "3. Baixe o KDK correspondente ao seu macOS \(osVersion)",
                "4. Abra o .dmg baixado e instale o .pkg",
                "5. O KDK será instalado em /Library/Developer/KDKs/",
                "6. Após instalar, volte aqui e clique em Atualizar"
            ],
            downloadURL: "https://developer.apple.com/download/all/?q=Kernel%20Debug%20Kit"
        )
    }
    
    /// Verifica se o KDK tem os kexts de áudio necessários
    static func hasAudioKexts(kdkPath: String) -> Bool {
        let fm = FileManager.default
        let sle = "\(kdkPath)/System/Library/Extensions"
        
        // Verificar AppleHDA.kext no KDK
        return fm.fileExists(atPath: "\(sle)/AppleHDA.kext")
    }
    
    // MARK: - Helpers
    
    static func getOSVersion() -> String {
        let p = Process()
        p.launchPath = "/usr/bin/sw_vers"
        p.arguments = ["-productVersion"]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run(); p.waitUntilExit()
        return (String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func getOSBuild() -> String {
        let p = Process()
        p.launchPath = "/usr/bin/sw_vers"
        p.arguments = ["-buildVersion"]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run(); p.waitUntilExit()
        return (String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
