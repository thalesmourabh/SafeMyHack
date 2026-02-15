import Foundation

/// KDKDetector: Detecta e valida Kernel Debug Kit (KDK) instalado
/// Baseado na lógica do OCLP-Mod (kdk_handler.py)
/// KDK é necessário APENAS para áudio — WiFi NÃO precisa de KDK
///
/// Fluxo de matching (igual OCLP-Mod):
/// 1. Match exato por build number (ex: 25A5034f)
/// 2. Fallback: mesmo major.minor (ex: 15.3)
/// 3. Fallback: major.(minor-1) (ex: 15.2)
class KDKDetector {
    
    static let kdkBasePath = "/Library/Developer/KDKs"
    
    struct KDKInfo {
        let installed: Bool
        let version: String?      // ex: "15.3"
        let build: String?        // ex: "24D60"
        let path: String?         // ex: "/Library/Developer/KDKs/KDK_macOS_15.3_24D60.kdk"
        let matchesOS: Bool       // Match exato ou próximo
        let exactMatch: Bool      // Match exato por build
        let isValid: Bool         // Passou na validação de integridade
        let osVersion: String     // Versão atual do macOS
        let osBuild: String       // Build atual do macOS
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
        
        guard fm.fileExists(atPath: kdkBasePath),
              let kdks = try? fm.contentsOfDirectory(atPath: kdkBasePath) else {
            return noKDK(osVersion: osVersion, osBuild: osBuild)
        }
        
        let kdkDirs = kdks.filter { $0.hasPrefix("KDK_") && $0.hasSuffix(".kdk") }
        if kdkDirs.isEmpty {
            return noKDK(osVersion: osVersion, osBuild: osBuild)
        }
        
        // Parse versão e build do macOS atual
        let osMajorMinor = osMajorMinorFrom(osVersion)
        
        // 1. Match EXATO por build number (prioridade máxima, igual OCLP-Mod)
        for kdk in kdkDirs {
            let (kdkVer, kdkBuild) = parseKDKName(kdk)
            if kdkBuild == osBuild {
                let path = "\(kdkBasePath)/\(kdk)"
                let valid = validateKDK(path: path)
                if valid {
                    return KDKInfo(installed: true, version: kdkVer, build: kdkBuild,
                                   path: path, matchesOS: true, exactMatch: true,
                                   isValid: true, osVersion: osVersion, osBuild: osBuild)
                }
                // KDK corrompido — continua buscando
            }
        }
        
        // 2. Fallback: mesmo major.minor (ex: 15.3 para 15.3.1)
        if let match = findLooseMatch(kdkDirs: kdkDirs, targetMajorMinor: osMajorMinor, osBuild: osBuild) {
            return KDKInfo(installed: true, version: match.version, build: match.build,
                           path: match.path, matchesOS: true, exactMatch: false,
                           isValid: match.valid, osVersion: osVersion, osBuild: osBuild)
        }
        
        // 3. Fallback: major.(minor-1) (ex: 15.2 se macOS é 15.3)
        let olderMajorMinor = olderVersionFrom(osMajorMinor)
        if let match = findLooseMatch(kdkDirs: kdkDirs, targetMajorMinor: olderMajorMinor, osBuild: osBuild) {
            return KDKInfo(installed: true, version: match.version, build: match.build,
                           path: match.path, matchesOS: true, exactMatch: false,
                           isValid: match.valid, osVersion: osVersion, osBuild: osBuild)
        }
        
        // KDK existe mas nenhum corresponde
        let first = kdkDirs.sorted().last ?? kdkDirs.first!
        let (fVer, fBuild) = parseKDKName(first)
        return KDKInfo(installed: true, version: fVer, build: fBuild,
                       path: "\(kdkBasePath)/\(first)", matchesOS: false, exactMatch: false,
                       isValid: false, osVersion: osVersion, osBuild: osBuild)
    }

    // MARK: - Validation (igual OCLP-Mod _local_kdk_valid)
    
    /// Valida integridade do KDK — verifica se arquivos críticos existem
    /// OCLP-Mod checa pkg receipts primeiro, depois fallback pra arquivos-chave
    static func validateKDK(path: String) -> Bool {
        let fm = FileManager.default
        let sle = "\(path)/System/Library/Extensions"
        
        // SystemVersion.plist deve existir (OCLP-Mod verifica isso primeiro)
        if !fm.fileExists(atPath: "\(path)/System/Library/CoreServices/SystemVersion.plist") {
            return false
        }
        
        // Arquivos essenciais que o kmutil precisa (OCLP-Mod legacy validation)
        let criticalFiles = [
            "\(sle)/System.kext/PlugIns/Libkern.kext/Libkern",
            "\(sle)/apfs.kext/Contents/MacOS/apfs",
            "\(sle)/IOUSBHostFamily.kext/Contents/MacOS/IOUSBHostFamily",
        ]
        
        for file in criticalFiles {
            if !fm.fileExists(atPath: file) {
                return false
            }
        }
        return true
    }
    
    /// Verifica se o KDK tem AppleHDA.kext (necessário para audio patch)
    static func hasAppleHDA(kdkPath: String) -> Bool {
        return FileManager.default.fileExists(atPath: "\(kdkPath)/System/Library/Extensions/AppleHDA.kext")
    }
    
    // MARK: - Instructions
    
    static func getInstallInstructions() -> KDKInstruction {
        let osVersion = getOSVersion()
        let osBuild = getOSBuild()
        return KDKInstruction(
            steps: [
                "1. Acesse developer.apple.com/download/all/ (Apple ID grátis)",
                "2. Pesquise 'Kernel Debug Kit'",
                "3. Baixe o KDK para macOS \(osVersion) (Build \(osBuild))",
                "4. Abra o .dmg e instale o .pkg",
                "5. KDK será instalado em /Library/Developer/KDKs/",
                "6. Volte ao SafeMyHack e clique Atualizar",
                "",
                "⚠️ IMPORTANTE: O build number deve ser \(osBuild)",
                "   Se não existir, use o mais próximo (mesmo major.minor)"
            ],
            downloadURL: "https://developer.apple.com/download/all/?q=Kernel%20Debug%20Kit"
        )
    }

    // MARK: - Parsing Helpers
    
    /// Parse "KDK_macOS_15.3_24D60.kdk" → ("15.3", "24D60")
    private static func parseKDKName(_ name: String) -> (version: String, build: String) {
        // KDK_macOS_15.3_24D60.kdk → "15.3_24D60"
        var clean = name.replacingOccurrences(of: "KDK_macOS_", with: "")
                        .replacingOccurrences(of: "KDK_", with: "")
                        .replacingOccurrences(of: ".kdk", with: "")
        let parts = clean.components(separatedBy: "_")
        let version = parts.first ?? ""
        let build = parts.count > 1 ? parts.last! : ""
        return (version, build)
    }
    
    /// "15.3.1" → "15.3"
    private static func osMajorMinorFrom(_ version: String) -> String {
        let parts = version.components(separatedBy: ".")
        if parts.count >= 2 { return "\(parts[0]).\(parts[1])" }
        return version
    }
    
    /// "15.3" → "15.2"
    private static func olderVersionFrom(_ majorMinor: String) -> String {
        let parts = majorMinor.components(separatedBy: ".")
        guard parts.count == 2, let major = Int(parts[0]), let minor = Int(parts[1]) else {
            return majorMinor
        }
        let newMinor = max(0, minor - 1)
        return "\(major).\(newMinor)"
    }
    
    private struct LooseMatch {
        let version: String; let build: String; let path: String; let valid: Bool
    }
    
    /// Busca KDK que corresponde ao major.minor, escolhendo o build mais próximo
    private static func findLooseMatch(kdkDirs: [String], targetMajorMinor: String, osBuild: String) -> LooseMatch? {
        var candidates: [(String, String, String, Bool)] = [] // (dir, version, build, valid)
        
        for kdk in kdkDirs {
            let (ver, build) = parseKDKName(kdk)
            let kdkMM = osMajorMinorFrom(ver)
            if kdkMM == targetMajorMinor {
                let path = "\(kdkBasePath)/\(kdk)"
                let valid = validateKDK(path: path)
                if valid { candidates.append((kdk, ver, build, valid)) }
            }
        }
        
        if candidates.isEmpty { return nil }
        
        // Ordenar por build (decrescente) e pegar o mais próximo <= osBuild
        candidates.sort { $0.2 > $1.2 }
        
        for c in candidates {
            if c.2 <= osBuild {
                return LooseMatch(version: c.1, build: c.2, path: "\(kdkBasePath)/\(c.0)", valid: c.3)
            }
        }
        // Se nenhum <= osBuild, pegar o menor (mais antigo)
        if let last = candidates.last {
            return LooseMatch(version: last.1, build: last.2, path: "\(kdkBasePath)/\(last.0)", valid: last.3)
        }
        return nil
    }
    
    private static func noKDK(osVersion: String, osBuild: String) -> KDKInfo {
        return KDKInfo(installed: false, version: nil, build: nil, path: nil,
                       matchesOS: false, exactMatch: false, isValid: false,
                       osVersion: osVersion, osBuild: osBuild)
    }
    
    // MARK: - System Info
    
    static func getOSVersion() -> String {
        let p = Process(); p.launchPath = "/usr/bin/sw_vers"; p.arguments = ["-productVersion"]
        let pipe = Pipe(); p.standardOutput = pipe
        try? p.run(); p.waitUntilExit()
        return (String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func getOSBuild() -> String {
        let p = Process(); p.launchPath = "/usr/bin/sw_vers"; p.arguments = ["-buildVersion"]
        let pipe = Pipe(); p.standardOutput = pipe
        try? p.run(); p.waitUntilExit()
        return (String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
