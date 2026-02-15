import Foundation

/// ConfigAnalyzer: Analisa config.plist do OpenCore e INSTRUI o usuário
/// Não faz alterações — apenas diagnostica e gera instruções claras
class ConfigAnalyzer {
    
    // MARK: - Required Settings
    
    static func requiredBootArgs(for family: BCMDetector.ChipsetFamily) -> [String] {
        switch family {
        case .legacy:
            return ["-amfipassbeta", "brcmfx-country=#a", "brcmfx-driver=2", "brcmfx-delay=9000"]
        default:
            return ["-amfipassbeta"]
        }
    }
    
    static let requiredBlocks = [
        (identifier: "com.apple.iokit.IOSkywalkFamily", comment: "Block IOSkywalk for BCM")
    ]
    
    /// Kexts necessárias para WiFi BCM (ordem ProperTree)
    static let requiredWiFiKexts = [
        "AMFIPass.kext",
        "IOSkywalkFamily.kext",
        "IO80211FamilyLegacy.kext",
        "IO80211FamilyLegacy.kext/Contents/PlugIns/AirPortBrcm4360.kext"
    ]

    // MARK: - Diagnostic
    
    struct Issue {
        let category: Category
        let description: String
        let fix: String  // Instrução clara pro usuário
        
        enum Category: String {
            case bootArg = "Boot-Arg"
            case kernelBlock = "Kernel Block"
            case kextMissing = "Kext Ausente"
            case kextDisabled = "Kext Desabilitada"
            case kextInjector = "Injector Incorreto"
            case secureBootModel = "SecureBootModel"
            case pluginMissing = "Plugin Ausente"
        }
    }
    
    struct Diagnostic {
        let issues: [Issue]
        let kextsOnDisk: [String]    // Kexts presentes em EFI/OC/Kexts/
        let kextsInConfig: [String]  // Kexts no Kernel > Add
        
        var isReady: Bool { issues.isEmpty }
        var issueCount: Int { issues.count }
        
        var summary: String {
            if isReady { return "✓ Config pronto para Root Patch" }
            return "\(issueCount) problema(s) encontrado(s)"
        }
    }
    
    // MARK: - Analyze config.plist (read-only)
    
    static func analyze(configPath: String, chipsetFamily: BCMDetector.ChipsetFamily = .unknown) -> Diagnostic {
        var issues: [Issue] = []
        var kextsOnDisk: [String] = []
        var kextsInConfig: [String] = []
        
        let fm = FileManager.default
        
        // Verificar kexts no disco (EFI/OC/Kexts/)
        let kextsDir = (configPath as NSString).deletingLastPathComponent + "/Kexts"
        if let contents = try? fm.contentsOfDirectory(atPath: kextsDir) {
            kextsOnDisk = contents.filter { $0.hasSuffix(".kext") }
        }

        guard let data = fm.contents(atPath: configPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return Diagnostic(issues: [Issue(category: .kextMissing, description: "config.plist não encontrado",
                                             fix: "Verifique se a EFI está montada e possui /EFI/OC/config.plist")],
                              kextsOnDisk: kextsOnDisk, kextsInConfig: [])
        }
        
        let kernel = plist["Kernel"] as? [String: Any] ?? [:]
        let adds = kernel["Add"] as? [[String: Any]] ?? []
        let blocks = kernel["Block"] as? [[String: Any]] ?? []
        
        // Coletar kexts no config
        for add in adds {
            if let bundle = add["BundlePath"] as? String {
                kextsInConfig.append(bundle)
            }
        }
        
        // 1. Verificar IOSkywalkFamily Block
        let hasSkywalkBlock = blocks.contains {
            ($0["Identifier"] as? String) == "com.apple.iokit.IOSkywalkFamily" && ($0["Enabled"] as? Bool) == true
        }
        let hasSkywalkDisabled = blocks.contains {
            ($0["Identifier"] as? String) == "com.apple.iokit.IOSkywalkFamily" && ($0["Enabled"] as? Bool) == false
        }
        
        if !hasSkywalkBlock {
            if hasSkywalkDisabled {
                issues.append(Issue(category: .kernelBlock,
                    description: "Block IOSkywalkFamily está DESABILITADO",
                    fix: "No config.plist → Kernel → Block → IOSkywalkFamily → mude Enabled para TRUE"))
            } else {
                issues.append(Issue(category: .kernelBlock,
                    description: "Block IOSkywalkFamily não existe",
                    fix: "No config.plist → Kernel → Block → Adicione IOSkywalkFamily com Identifier 'com.apple.iokit.IOSkywalkFamily', Strategy 'Exclude', Enabled TRUE"))
            }
        }

        // 2. Verificar AirPortBrcm4360_Injector (deve estar DESABILITADO)
        for add in adds {
            if let bundle = add["BundlePath"] as? String,
               bundle.contains("AirPortBrcm4360_Injector"),
               let enabled = add["Enabled"] as? Bool, enabled {
                issues.append(Issue(category: .kextInjector,
                    description: "AirPortBrcm4360_Injector está HABILITADO",
                    fix: "No config.plist → Kernel → Add → AirPortBrcm4360_Injector.kext → mude Enabled para FALSE"))
            }
        }
        
        // 3. Verificar Boot-Args
        let nvram = plist["NVRAM"] as? [String: Any] ?? [:]
        let nvramAdd = nvram["Add"] as? [String: Any] ?? [:]
        let appleGUID = nvramAdd["7C436110-AB2A-4BBB-A880-FE41995C9F82"] as? [String: Any] ?? [:]
        let bootArgs = appleGUID["boot-args"] as? String ?? ""
        
        for arg in requiredBootArgs(for: chipsetFamily) {
            if arg.contains("=") {
                let argKey = arg.components(separatedBy: "=")[0]
                if !bootArgs.contains(argKey) {
                    issues.append(Issue(category: .bootArg,
                        description: "Boot-arg '\(arg)' ausente",
                        fix: "No config.plist → NVRAM → Add → 7C436110... → boot-args → adicione '\(arg)'"))
                }
            } else {
                if !bootArgs.contains(arg) {
                    issues.append(Issue(category: .bootArg,
                        description: "Boot-arg '\(arg)' ausente",
                        fix: "No config.plist → NVRAM → Add → 7C436110... → boot-args → adicione '\(arg)'"))
                }
            }
        }
        
        // 4. Verificar SecureBootModel
        let misc = plist["Misc"] as? [String: Any] ?? [:]
        let security = misc["Security"] as? [String: Any] ?? [:]
        if let sbm = security["SecureBootModel"] as? String, sbm.lowercased() != "disabled" {
            issues.append(Issue(category: .secureBootModel,
                description: "SecureBootModel está '\(sbm)' (precisa ser Disabled)",
                fix: "No config.plist → Misc → Security → SecureBootModel → mude para 'Disabled'"))
        }

        // 5. Verificar kexts WiFi no config.plist e no disco
        for kextName in requiredWiFiKexts {
            let shortName = (kextName as NSString).lastPathComponent
            let isPlugin = kextName.contains("PlugIns/")
            
            // Verificar no config.plist (Kernel > Add)
            let inConfig = adds.contains { ($0["BundlePath"] as? String) == kextName && ($0["Enabled"] as? Bool) == true }
            let inConfigDisabled = adds.contains { ($0["BundlePath"] as? String) == kextName && ($0["Enabled"] as? Bool) == false }
            
            if !inConfig {
                if inConfigDisabled {
                    issues.append(Issue(category: .kextDisabled,
                        description: "\(shortName) está no config.plist mas DESABILITADA",
                        fix: "No config.plist → Kernel → Add → \(shortName) → mude Enabled para TRUE"))
                } else if isPlugin {
                    issues.append(Issue(category: .pluginMissing,
                        description: "Plugin \(shortName) ausente no config.plist",
                        fix: "No config.plist → Kernel → Add → adicione entry para '\(kextName)' LOGO APÓS IO80211FamilyLegacy.kext"))
                } else {
                    issues.append(Issue(category: .kextMissing,
                        description: "\(shortName) ausente no config.plist",
                        fix: "No config.plist → Kernel → Add → adicione entry para '\(kextName)' com Enabled TRUE"))
                }
            }
            
            // Verificar no disco (EFI/OC/Kexts/) — só kexts pai, plugins ficam dentro
            if !isPlugin {
                let baseName = (kextName as NSString).lastPathComponent
                if !kextsOnDisk.contains(baseName) {
                    issues.append(Issue(category: .kextMissing,
                        description: "\(baseName) não encontrada em EFI/OC/Kexts/",
                        fix: "Copie \(baseName) para /Volumes/EFI/EFI/OC/Kexts/"))
                }
            }
        }
        
        return Diagnostic(issues: issues, kextsOnDisk: kextsOnDisk, kextsInConfig: kextsInConfig)
    }
}
