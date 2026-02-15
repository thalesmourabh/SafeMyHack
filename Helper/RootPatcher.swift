import Foundation

/// RootPatcher: Root patch para WiFi BCM + Audio no macOS Sonoma/Sequoia/Tahoe
/// Copia kexts da EFI do usuário → /System/Library/Extensions/
/// Instala payloads WiFi (frameworks/binários) + kext de áudio fornecida pelo usuário
/// NÃO modifica config.plist nem copia kexts PARA a EFI
class RootPatcher {
    
    struct PatchResult {
        let success: Bool
        let logs: [String]
        let requiresRestart: Bool
    }
    
    static let systemMountPoint = "/private/tmp/SafeMyHack_System"
    
    // MARK: - Pre-flight
    
    static func checkRequirements(includeAudio: Bool, audioKextPath: String?) -> (ready: Bool, issues: [String]) {
        var issues: [String] = []
        
        let sipResult = runCmd("/usr/bin/csrutil", args: ["authenticated-root", "status"])
        if !sipResult.lowercased().contains("disabled") {
            issues.append("Authenticated Root ativo — desabilite no Recovery")
        }
        if !FileManager.default.fileExists(atPath: "/Volumes/EFI/EFI/OC") {
            issues.append("EFI não montada")
        }
        
        // Verificar kexts WiFi na EFI do usuário (serão copiadas pro sistema)
        let efiKexts = "/Volumes/EFI/EFI/OC/Kexts"
        for kext in ["IO80211FamilyLegacy.kext", "IOSkywalkFamily.kext"] {
            if !FileManager.default.fileExists(atPath: "\(efiKexts)/\(kext)") {
                issues.append("Falta \(kext) na EFI/OC/Kexts/")
            }
        }
        
        if !PayloadManager.arePayloadsBundled() {
            issues.append("Payloads WiFi não encontrados no app")
        }

        if includeAudio {
            let kdk = KDKDetector.detect()
            if !kdk.installed { issues.append("KDK não instalado (necessário para áudio)") }
            else if !kdk.matchesOS { issues.append("KDK não corresponde ao macOS atual") }
            
            if let path = audioKextPath {
                if !FileManager.default.fileExists(atPath: path) {
                    issues.append("Kext de áudio não encontrada: \(path)")
                }
            } else {
                issues.append("Nenhuma kext de áudio selecionada")
            }
        }
        return (issues.isEmpty, issues)
    }
    
    // MARK: - Apply Root Patches
    
    static func applyPatches(includeAudio: Bool, audioKextPath: String? = nil, dryRun: Bool = false) -> PatchResult {
        var logs: [String] = []
        let ts = { let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: Date()) }
        
        logs.append("[\(ts())] ════════════════════════════════════════════")
        logs.append("[\(ts())] SafeMyHack — Root Patcher")
        logs.append("[\(ts())] WiFi Payloads: ✓  |  Audio: \(includeAudio ? "✓" : "—")")
        logs.append("[\(ts())] ════════════════════════════════════════════")
        logs.append("")
        logs.append("[\(ts())] NOTA: Kexts do OpenCore são injetadas pela EFI.")
        logs.append("[\(ts())] Este patcher só instala frameworks/binários do sistema.")
        if includeAudio { logs.append("[\(ts())] + Kext de áudio fornecida pelo usuário.") }

        // Step 1: Requirements
        logs.append(""); logs.append("[\(ts())] [1/4] Verificando requisitos...")
        let (ready, issues) = checkRequirements(includeAudio: includeAudio, audioKextPath: audioKextPath)
        if !ready {
            for issue in issues { logs.append("[\(ts())]   ❌ \(issue)") }
            return PatchResult(success: false, logs: logs, requiresRestart: false)
        }
        logs.append("[\(ts())]   ✓ Requisitos OK")
        
        // Step 2: Payloads
        logs.append(""); logs.append("[\(ts())] [2/4] Verificando payloads WiFi...")
        let (valid, missing) = PayloadManager.verifyPayloads()
        if !valid {
            logs.append("[\(ts())]   ❌ Faltando: \(missing.joined(separator: ", "))")
            return PatchResult(success: false, logs: logs, requiresRestart: false)
        }
        for p in PayloadManager.getWiFiPayloadFiles() {
            logs.append("[\(ts())]   ✓ \(p.name)")
        }
        
        // Step 3: System volume
        logs.append(""); logs.append("[\(ts())] [3/4] Identificando volume...")
        guard let systemDevice = EFIAnalyzer.getSystemVolumeDevice() else {
            logs.append("[\(ts())]   ❌ Volume não identificado")
            return PatchResult(success: false, logs: logs, requiresRestart: false)
        }
        logs.append("[\(ts())]   ✓ Volume: \(systemDevice)")

        // Dry run
        if dryRun {
            logs.append(""); logs.append("[\(ts())] ═══════ SIMULAÇÃO ═══════")
            logs.append("[\(ts())] 1. mount_apfs \(systemDevice) \(systemMountPoint)")
            logs.append("[\(ts())] 2. Copiar kexts da EFI → /System/Library/Extensions/")
            logs.append("[\(ts())]    → IO80211FamilyLegacy.kext")
            logs.append("[\(ts())]    → IOSkywalkFamily.kext")
            logs.append("[\(ts())] 3. Instalar payloads WiFi (frameworks do sistema):")
            for p in PayloadManager.getWiFiPayloadFiles() {
                logs.append("[\(ts())]    → \(p.destPath)")
            }
            if includeAudio, let path = audioKextPath {
                logs.append("[\(ts())] 4. Instalar kext de áudio fornecida pelo usuário:")
                logs.append("[\(ts())]    → \((path as NSString).lastPathComponent)")
            }
            let nextStep = includeAudio ? "5" : "4"
            logs.append("[\(ts())] \(nextStep). kmutil install --update-all --force")
            logs.append("[\(ts())] \(includeAudio ? "6" : "5"). bless --create-snapshot")
            return PatchResult(success: true, logs: logs, requiresRestart: false)
        }
        
        // Step 4: Execute
        logs.append(""); logs.append("[\(ts())] [4/4] Aplicando patches...")
        let script = buildPatchScript(systemDevice: systemDevice, includeAudio: includeAudio, audioKextPath: audioKextPath)
        let result = runScriptWithAdmin(script)
        
        if !result.success {
            logs.append("[\(ts())] ❌ Erro: \(result.output)")
            return PatchResult(success: false, logs: logs, requiresRestart: false)
        }
        
        if !result.output.isEmpty {
            for line in result.output.components(separatedBy: "\n") {
                let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { logs.append("[\(ts())]   \(clean)") }
            }
        }
        
        logs.append("")
        logs.append("[\(ts())] ════════════════════════════════════════════")
        logs.append("[\(ts())] ✅ ROOT PATCHES APLICADOS!")
        logs.append("[\(ts())] ⚠️  REINICIE o Mac para ativar")
        logs.append("[\(ts())] ════════════════════════════════════════════")
        return PatchResult(success: true, logs: logs, requiresRestart: true)
    }

    // MARK: - Build Script (só payloads WiFi + audio kext do usuário)
    
    private static func buildPatchScript(systemDevice: String, includeAudio: Bool, audioKextPath: String?) -> String {
        // Payloads WiFi: frameworks e binários do sistema
        var payloadInstalls = ""
        for payload in PayloadManager.getWiFiPayloadFiles() {
            payloadInstalls += """
            
            if [ -e "\(payload.bundledPath)" ]; then
                echo "Instalando \(payload.name)..."
                rm -rf "$MOUNT_POINT\(payload.destPath)"
                cp -R "\(payload.bundledPath)" "$MOUNT_POINT\(payload.destPath)"
                chmod -R 755 "$MOUNT_POINT\(payload.destPath)"
                chown -R root:wheel "$MOUNT_POINT\(payload.destPath)"
                echo "✓ \(payload.name)"
            else
                echo "⚠️ Payload não encontrado: \(payload.name)"
            fi
            """
        }
        
        // Audio: kext fornecida pelo usuário
        var audioInstall = ""
        if includeAudio, let audioPath = audioKextPath {
            let kextName = (audioPath as NSString).lastPathComponent
            audioInstall = """
            
            echo ""
            echo "Instalando kext de áudio (\(kextName))..."
            if [ -d "\(audioPath)" ]; then
                rm -rf "$MOUNT_POINT/System/Library/Extensions/\(kextName)"
                cp -R "\(audioPath)" "$MOUNT_POINT/System/Library/Extensions/\(kextName)"
                chmod -R 755 "$MOUNT_POINT/System/Library/Extensions/\(kextName)"
                chown -R root:wheel "$MOUNT_POINT/System/Library/Extensions/\(kextName)"
                echo "✓ \(kextName) (audio)"
            else
                echo "ERRO: Kext de áudio não encontrada em \(audioPath)"
                exit 1
            fi
            """
        }

        return """
        #!/bin/bash
        
        SYSTEM_VOL="\(systemDevice)"
        MOUNT_POINT="\(systemMountPoint)"
        EFI_KEXTS="/Volumes/EFI/EFI/OC/Kexts"
        
        echo "=== SafeMyHack Root Patcher ==="
        
        mkdir -p "$MOUNT_POINT"
        
        echo "Montando sistema ($SYSTEM_VOL)..."
        mount_apfs "$SYSTEM_VOL" "$MOUNT_POINT" 2>/dev/null || {
            mount_apfs -o nobrowse "$SYSTEM_VOL" "$MOUNT_POINT" || {
                echo "ERRO: Falha ao montar volume do sistema"
                exit 1
            }
        }
        
        if [ ! -d "$MOUNT_POINT/System/Library/Extensions" ]; then
            echo "ERRO: Extensions não encontrado"
            exit 1
        fi
        echo "✓ Sistema montado"
        
        echo ""
        echo "Copiando kexts da EFI para o sistema..."
        for KEXT in IO80211FamilyLegacy.kext IOSkywalkFamily.kext; do
            if [ -d "$EFI_KEXTS/$KEXT" ]; then
                rm -rf "$MOUNT_POINT/System/Library/Extensions/$KEXT"
                cp -R "$EFI_KEXTS/$KEXT" "$MOUNT_POINT/System/Library/Extensions/"
                chmod -R 755 "$MOUNT_POINT/System/Library/Extensions/$KEXT"
                chown -R root:wheel "$MOUNT_POINT/System/Library/Extensions/$KEXT"
                echo "✓ $KEXT"
            else
                echo "⚠️ $KEXT não encontrada na EFI (pulando)"
            fi
        done
        
        echo ""
        echo "Instalando payloads WiFi..."
        \(payloadInstalls)
        \(audioInstall)
        
        echo ""
        echo "Reconstruindo kernel cache (1-2 min)..."
        KMUTIL_OUTPUT=$(kmutil install --volume-root "$MOUNT_POINT" --update-all --force 2>&1)
        KMUTIL_EXIT=$?
        echo "$KMUTIL_OUTPUT"
        
        if [ $KMUTIL_EXIT -ne 0 ]; then
            if [ ! -f "$MOUNT_POINT/System/Library/PrelinkedKernels/prelinkedkernel" ] && \\
               [ ! -d "$MOUNT_POINT/System/Library/KernelCollections" ]; then
                echo "ERRO CRÍTICO: kernel cache não criado"
                diskutil unmount "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null || true
                exit 1
            fi
            echo "⚠️ kmutil warnings mas kernel cache existe"
        fi
        echo "✓ Kernel cache OK"
        
        echo ""
        echo "Criando snapshot bootável..."
        bless --folder "$MOUNT_POINT/System/Library/CoreServices" --bootefi --create-snapshot 2>&1
        BLESS_EXIT=$?
        if [ $BLESS_EXIT -ne 0 ]; then
            echo "ERRO: bless falhou"
            diskutil unmount "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null || true
            exit 1
        fi
        echo "✓ Snapshot criado"
        
        diskutil unmount "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null || true
        echo "=== Concluído! ==="
        exit 0
        """
    }

    // MARK: - Helpers
    
    private static func runCmd(_ path: String, args: [String]) -> String {
        let p = Process(); p.launchPath = path; p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        do { try p.run(); p.waitUntilExit() } catch { return "" }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
    
    private static func runScriptWithAdmin(_ script: String) -> (success: Bool, output: String) {
        let escaped = script.replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"
        let p = Process(); p.launchPath = "/usr/bin/osascript"; p.arguments = ["-e", appleScript]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        do {
            try p.run(); p.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return (p.terminationStatus == 0, out)
        } catch { return (false, error.localizedDescription) }
    }
}
