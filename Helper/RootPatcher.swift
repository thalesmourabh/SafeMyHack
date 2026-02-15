import Foundation

/// RootPatcher: Root patch para WiFi BCM + Audio no macOS Sonoma/Sequoia/Tahoe
///
/// Fluxo baseado no OCLP-Mod (sys_patch.py + kdk_merge.py):
/// 1. Monta volume do sistema (mount_apfs)
/// 2. Copia kexts da EFI → /System/Library/Extensions/
/// 3. Instala payloads WiFi (frameworks bundled no app)
/// 4. [AUDIO] Merge KDK → root (rsync Extensions do KDK pro sistema)
/// 5. [AUDIO] Instala kext de áudio do usuário
/// 6. Reconstrói kernel cache (kmutil install --update-all --force)
/// 7. Cria snapshot bootável (bless --create-snapshot)
///
/// WiFi NÃO precisa de KDK. Audio PRECISA de KDK.
/// NÃO modifica config.plist nem copia kexts PARA a EFI.
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
        
        // Kexts WiFi na EFI (serão copiadas pro sistema)
        let efiKexts = "/Volumes/EFI/EFI/OC/Kexts"
        for kext in ["IO80211FamilyLegacy.kext", "IOSkywalkFamily.kext"] {
            if !FileManager.default.fileExists(atPath: "\(efiKexts)/\(kext)") {
                issues.append("Falta \(kext) na EFI/OC/Kexts/")
            }
        }
        
        if !PayloadManager.arePayloadsBundled() {
            issues.append("Payloads WiFi não encontrados no app")
        }
        
        // Audio precisa de KDK + kext selecionada
        if includeAudio {
            let kdk = KDKDetector.detect()
            if !kdk.installed {
                issues.append("KDK não instalado (necessário para áudio)")
            } else if !kdk.matchesOS {
                issues.append("KDK não corresponde ao macOS \(kdk.osVersion) (Build \(kdk.osBuild))")
            } else if !kdk.isValid {
                issues.append("KDK corrompido — reinstale via developer.apple.com")
            }
            
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
        logs.append("[\(ts())] WiFi: ✓  |  Audio: \(includeAudio ? "✓" : "—")")
        if includeAudio { logs.append("[\(ts())] WiFi NÃO precisa de KDK. Audio PRECISA.") }
        logs.append("[\(ts())] ════════════════════════════════════════════")
        
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
        
        // KDK path (só para audio)
        var kdkPath: String? = nil
        if includeAudio {
            let kdk = KDKDetector.detect()
            kdkPath = kdk.path
            logs.append("[\(ts())]   ✓ KDK: \(kdk.version ?? "?") (Build \(kdk.build ?? "?"))")
            if kdk.exactMatch { logs.append("[\(ts())]     Match exato por build ✓") }
            else { logs.append("[\(ts())]     Match aproximado (versão próxima)") }
        }

        // Dry run
        if dryRun {
            logs.append(""); logs.append("[\(ts())] ═══════ SIMULAÇÃO ═══════")
            var step = 1
            logs.append("[\(ts())] \(step). mount_apfs \(systemDevice) \(systemMountPoint)"); step += 1
            logs.append("[\(ts())] \(step). Copiar kexts da EFI → /System/Library/Extensions/"); step += 1
            logs.append("[\(ts())]    → IO80211FamilyLegacy.kext")
            logs.append("[\(ts())]    → IOSkywalkFamily.kext")
            logs.append("[\(ts())] \(step). Instalar payloads WiFi (frameworks):"); step += 1
            for p in PayloadManager.getWiFiPayloadFiles() {
                logs.append("[\(ts())]    → \(p.destPath)")
            }
            if includeAudio, let kp = kdkPath {
                logs.append("[\(ts())] \(step). Merge KDK → root (rsync Extensions)"); step += 1
                logs.append("[\(ts())]    → rsync \(kp)/System/Library/Extensions/ → sistema")
            }
            if includeAudio, let ap = audioKextPath {
                logs.append("[\(ts())] \(step). Instalar kext de áudio:"); step += 1
                logs.append("[\(ts())]    → \((ap as NSString).lastPathComponent)")
            }
            logs.append("[\(ts())] \(step). kmutil install --update-all --force"); step += 1
            logs.append("[\(ts())] \(step). bless --create-snapshot")
            return PatchResult(success: true, logs: logs, requiresRestart: false)
        }
        
        // Step 4: Execute
        logs.append(""); logs.append("[\(ts())] [4/4] Aplicando patches...")
        let script = buildPatchScript(
            systemDevice: systemDevice,
            includeAudio: includeAudio,
            audioKextPath: audioKextPath,
            kdkPath: kdkPath
        )
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


    // MARK: - Build Script
    // Fluxo baseado no OCLP-Mod:
    // 1. mount_apfs → root
    // 2. Copiar kexts WiFi da EFI → /S/L/E
    // 3. Instalar payloads WiFi (frameworks bundled)
    // 4. [AUDIO] rsync KDK/System/Library/Extensions → root (igual kdk_merge.py)
    // 5. [AUDIO] Copiar kext de áudio do usuário → /S/L/E
    // 6. kmutil install --update-all --force
    // 7. bless --create-snapshot
    
    private static func buildPatchScript(systemDevice: String, includeAudio: Bool, audioKextPath: String?, kdkPath: String?) -> String {
        
        // --- Payloads WiFi ---
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

        // --- KDK Merge (APENAS para audio) ---
        // Igual OCLP-Mod kdk_merge.py → _merge_kdk():
        // rsync -r -i -a {kdk}/System/Library/Extensions/ → {root}/System/Library/Extensions
        // Isso fornece os symbols que o kmutil precisa para reconstruir o kernel cache
        var kdkMerge = ""
        if includeAudio, let kp = kdkPath {
            kdkMerge = """
            
            echo ""
            echo "Merging KDK com root volume (símbolos para kmutil)..."
            KDK_SLE="\(kp)/System/Library/Extensions"
            if [ -d "$KDK_SLE" ]; then
                # Verificar integridade mínima do KDK
                if [ ! -f "$KDK_SLE/System.kext/PlugIns/Libkern.kext/Libkern" ]; then
                    echo "ERRO: KDK corrompido — Libkern ausente"
                    diskutil unmount "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null || true
                    exit 1
                fi
                # rsync só /System/Library/Extensions (não precisa de Kernels nem KernelSupport)
                rsync -r -a "$KDK_SLE/" "$MOUNT_POINT/System/Library/Extensions"
                echo "✓ KDK merged com root"
            else
                echo "ERRO: KDK Extensions não encontrado em \(kp)"
                diskutil unmount "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null || true
                exit 1
            fi
            """
        }

        // --- Audio kext do usuário ---
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
                diskutil unmount "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null || true
                exit 1
            fi
            """
        }

        // --- Script principal ---
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
        \(kdkMerge)
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
        let p = Process()
        p.launchPath = "/usr/bin/osascript"
        p.arguments = ["-e", appleScript]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run(); p.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return (p.terminationStatus == 0, out)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
