import SwiftUI

// MARK: - Glassmorphism Components

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Main View

struct ContentView: View {
    @State private var osVersion = "Carregando..."
    @State private var sipStatus = "..."
    @State private var efiMounted = false
    @State private var payloadsReady = false
    @State private var bcmInfo: BCMDetector.DetectionResult? = nil
    @State private var configDiag: ConfigAnalyzer.Diagnostic? = nil
    @State private var kdkInfo: KDKDetector.KDKInfo? = nil
    @State private var isPatching = false
    @State private var isMountingEFI = false
    @State private var isRevertingSnapshot = false
    @State private var showRevertConfirm = false
    @State private var includeAudio = false
    @State private var audioKextPath: String? = nil
    @State private var logs: [String] = []
    @State private var bcmLoading = true
    @State private var showLogs = false
    @State private var showKDKInstructions = false
    
    var chipsetFamily: BCMDetector.ChipsetFamily {
        bcmInfo?.info?.family ?? .unknown
    }
    
    /// Root Patch só libera quando config está OK
    var canPatch: Bool {
        sipStatus.contains("Disabled") && efiMounted && payloadsReady && (configDiag?.isReady ?? false)
    }
    
    /// Audio só libera quando KDK está instalado, compatível e válido
    var canAudio: Bool {
        if let kdk = kdkInfo { return kdk.installed && kdk.matchesOS && kdk.isValid }
        return false
    }

    var body: some View {
        ZStack {
            VisualEffectView().ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    HStack(alignment: .top, spacing: 16) { systemStatus; bcmStatus }
                    configStatus
                    kdkStatus
                    if isPatching { patchProgress } else { actionButtons }
                    Spacer()
                }
                .padding()
            }
            .transparentScrolling()
        }
        .onAppear { checkSystem() }
        .frame(minWidth: 720, minHeight: 680)
    }
    
    // MARK: - Header
    var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64).shadow(radius: 5)
                VStack(alignment: .leading) {
                    Text("SafeMyHack")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Legacy Patcher — WiFi & Audio")
                        .font(.headline).foregroundColor(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(.yellow)
                Text("v1.0.0 • Tahoe Glass")
                Spacer()
                if osVersion != "Carregando..." { Text(osVersion).bold() }
            }
            .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
            .background(.regularMaterial).cornerRadius(20)
        }
        .padding(.top, 10).padding(.bottom, 10)
    }

    // MARK: - System Status
    var systemStatus: some View {
        GlassCard {
            Label("Estado do Sistema", systemImage: "macbook.gen2").font(.headline)
            Divider()
            StatusRow(label: "SIP Status:", value: sipStatus,
                      color: sipStatus.contains("Disabled") ? .green : .red, icon: "lock.shield")
            HStack {
                Image(systemName: "internaldrive").frame(width: 20).foregroundColor(.secondary)
                Text("EFI Partition:").foregroundColor(.secondary)
                Spacer()
                if efiMounted {
                    Text("Montada").bold().foregroundColor(.green)
                } else {
                    Button(action: mountEFI) {
                        HStack(spacing: 4) {
                            if isMountingEFI { ProgressView().controlSize(.mini) }
                            else { Image(systemName: "externaldrive.badge.plus") }
                            Text("Montar EFI")
                        }.font(.caption)
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                    .controlSize(.small).disabled(isMountingEFI)
                }
            }.font(.subheadline)
            StatusRow(label: "Payloads:", value: payloadsReady ? "Integrados" : "Ausentes",
                      color: payloadsReady ? .green : .red, icon: "shippingbox")
        }
    }
    
    // MARK: - BCM Status
    var bcmStatus: some View {
        GlassCard {
            Label("Hardware PCI", systemImage: "wifi.router").font(.headline)
            Divider()
            if bcmLoading {
                HStack { ProgressView().scaleEffect(0.8); Text("Escaneando PCI...").font(.caption).foregroundColor(.secondary) }.padding()
            } else if let bcm = bcmInfo {
                StatusRow(label: "Chipset:", value: bcm.chipset, color: bcm.isBroadcom ? .green : .orange, icon: "cpu")
                StatusRow(label: "Vendor ID:", value: bcm.vendorID, color: bcm.isBroadcom ? .green : .orange, icon: "barcode")
                StatusRow(label: "Device ID:", value: bcm.deviceID, color: (bcm.chipset != "Unknown") ? .green : .yellow, icon: "tag")
                if let info = bcm.info {
                    VStack(alignment: .leading, spacing: 4) {
                        if info.wifiSupport {
                            Label("WiFi compatível", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                        }
                        if info.airdropSupport {
                            Label("AirDrop suportado", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                        }
                        if info.family == .legacy {
                            Label("Legacy — boot-args extras", systemImage: "info.circle").foregroundColor(.orange).font(.caption)
                        }
                    }.padding(.top, 4)
                }
            } else {
                Text("Nenhuma placa WiFi detectada").foregroundColor(.red)
            }
        }
    }

    // MARK: - Config Status (instrui o usuário)
    var configStatus: some View {
        GlassCard {
            HStack {
                Label("OpenCore Config", systemImage: "gearshape.2").font(.headline)
                Spacer()
                if let diag = configDiag {
                    if diag.isReady {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                    } else {
                        Text("\(diag.issueCount) Problema(s)")
                            .font(.caption).padding(4)
                            .background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(4)
                    }
                }
            }
            Divider()
            
            if !efiMounted {
                Text("Monte a EFI para verificar").font(.subheadline).foregroundColor(.secondary)
            } else if let diag = configDiag {
                if diag.isReady {
                    Text("Config pronto para Root Patch").font(.subheadline).foregroundColor(.green)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Corrija os itens abaixo antes de prosseguir:")
                            .font(.caption).bold().foregroundColor(.orange)
                        
                        ForEach(Array(diag.issues.enumerated()), id: \.offset) { _, issue in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .top) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange).font(.caption2)
                                    Text("[\(issue.category.rawValue)] \(issue.description)")
                                        .font(.caption).bold()
                                }
                                Text("→ \(issue.fix)")
                                    .font(.caption2).foregroundColor(.secondary)
                                    .padding(.leading, 20)
                            }
                        }
                    }.padding(.vertical, 5)
                }
            }
        }
    }

    // MARK: - KDK Status + Audio
    var kdkStatus: some View {
        GlassCard {
            HStack {
                Label("Audio & KDK", systemImage: "speaker.wave.2").font(.headline)
                Spacer()
                if let kdk = kdkInfo {
                    if kdk.installed && kdk.matchesOS {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                    } else if kdk.installed {
                        Text("Versão errada").font(.caption).padding(4)
                            .background(Color.orange.opacity(0.8)).foregroundColor(.white).cornerRadius(4)
                    } else {
                        Text("Não instalado").font(.caption).padding(4)
                            .background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(4)
                    }
                }
            }
            Divider()
            
            if let kdk = kdkInfo {
                StatusRow(label: "KDK:", value: kdk.installed ? "\(kdk.version ?? "?") (\(kdk.build ?? "?"))" : "Não encontrado",
                          color: kdk.installed ? .green : .red, icon: "wrench.and.screwdriver")
                StatusRow(label: "macOS:", value: "\(kdk.osVersion) (Build \(kdk.osBuild))",
                          color: .primary, icon: "desktopcomputer")
                
                if kdk.installed && kdk.matchesOS && kdk.isValid {
                    if kdk.exactMatch {
                        StatusRow(label: "Match:", value: "Exato por build ✓", color: .green, icon: "checkmark.circle")
                    } else {
                        StatusRow(label: "Match:", value: "Aproximado (versão próxima)", color: .orange, icon: "checkmark.circle")
                    }
                    
                    // Toggle audio
                    Toggle(isOn: $includeAudio) {
                        Label("Incluir patch de Áudio", systemImage: "speaker.wave.2.fill")
                            .font(.subheadline)
                    }
                    .toggleStyle(.switch)
                    .padding(.top, 4)
                    
                    if includeAudio {
                        if let path = audioKextPath {
                            Text("Audio kext: \((path as NSString).lastPathComponent)")
                                .font(.caption).foregroundColor(.green)
                        }
                        
                        Button(action: selectAudioKext) {
                            Label("Carregar Kext de Áudio", systemImage: "folder.badge.plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }

                } else if kdk.installed && !kdk.matchesOS {
                    Text("KDK instalado não corresponde ao macOS \(kdk.osVersion) (Build \(kdk.osBuild))")
                        .font(.caption).foregroundColor(.orange)
                    Text("Baixe o KDK correto para seu build.")
                        .font(.caption2).foregroundColor(.secondary)
                    
                    Button(action: { showKDKInstructions.toggle() }) {
                        Label("Ver instruções", systemImage: "questionmark.circle")
                            .font(.caption)
                    }.buttonStyle(.bordered).controlSize(.small)
                } else if kdk.installed && !kdk.isValid {
                    Text("KDK corrompido — arquivos críticos ausentes")
                        .font(.caption).foregroundColor(.red)
                    Text("Reinstale o KDK via developer.apple.com")
                        .font(.caption2).foregroundColor(.secondary)
                    
                    Button(action: { showKDKInstructions.toggle() }) {
                        Label("Ver instruções", systemImage: "questionmark.circle")
                            .font(.caption)
                    }.buttonStyle(.bordered).controlSize(.small)
                } else {
                    Text("KDK necessário para ativar áudio no Hackintosh")
                        .font(.caption).foregroundColor(.secondary)
                    
                    Button(action: { showKDKInstructions.toggle() }) {
                        Label("Como instalar o KDK", systemImage: "arrow.down.circle")
                            .font(.caption)
                    }.buttonStyle(.borderedProminent).tint(.blue).controlSize(.small)
                }
                
                if showKDKInstructions {
                    let instructions = KDKDetector.getInstallInstructions()
                    VStack(alignment: .leading, spacing: 6) {
                        Divider()
                        Text("Instruções para instalar o KDK:").font(.caption).bold()
                        ForEach(instructions.steps, id: \.self) { step in
                            Text(step).font(.caption2).foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            if let url = URL(string: instructions.downloadURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Abrir Apple Developer", systemImage: "safari")
                                .font(.caption)
                        }.buttonStyle(.bordered).controlSize(.small)
                    }.padding(.top, 4)
                }
            } else {
                Text("Verificando KDK...").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Action Buttons
    var actionButtons: some View {
        VStack(spacing: 15) {
            HStack(spacing: 12) {
                Button(action: { applyPatches(dryRun: true) }) {
                    Label("Simular", systemImage: "eye")
                }.buttonStyle(.bordered).tint(.secondary).disabled(!canPatch)
                
                Button(action: { applyPatches(dryRun: false) }) {
                    HStack {
                        Image(systemName: "lock.open.rotation")
                        VStack(alignment: .leading) {
                            Text("Root Patch").bold()
                            Text(includeAudio ? "WiFi + Audio • Requer Reinício" : "WiFi • Requer Reinício")
                                .font(.caption2)
                        }
                    }.frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(canPatch ? .blue : .gray)
                .disabled(!canPatch)
                .opacity(canPatch ? 1.0 : 0.6)
                .shadow(color: canPatch ? .blue.opacity(0.4) : .clear, radius: 10)
            }
            
            if !canPatch {
                HStack {
                    Image(systemName: "info.circle").foregroundColor(.orange)
                    Text(blockReasonText).font(.caption)
                }
                .padding(8).background(Color.orange.opacity(0.15)).cornerRadius(8)
            }
            
            // Revert Snapshot
            Divider().padding(.horizontal)
            
            if showRevertConfirm {
                GlassCard {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("Reverter Snapshot?").font(.headline)
                    }
                    Text("Desfaz root patches e restaura o snapshot Apple. Necessário antes de atualizar macOS (delta update).")
                        .font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button("Cancelar") { showRevertConfirm = false }.buttonStyle(.bordered)
                        Button(action: revertSnapshot) {
                            HStack(spacing: 4) {
                                if isRevertingSnapshot { ProgressView().controlSize(.mini) }
                                else { Image(systemName: "arrow.counterclockwise") }
                                Text("Confirmar")
                            }
                        }.buttonStyle(.borderedProminent).tint(.orange).disabled(isRevertingSnapshot)
                    }
                }
            } else {
                Button(action: { showRevertConfirm = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reverter Snapshot")
                        Text("(para atualizar macOS)").foregroundColor(.secondary)
                    }.font(.caption)
                }.buttonStyle(.plain)
            }

            Button(action: { showLogs.toggle() }) {
                Text(showLogs ? "Ocultar Logs" : "Mostrar Logs")
                    .font(.caption)
            }.buttonStyle(.plain)
            
            if showLogs {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(logs, id: \.self) { log in
                            Text(log).font(.system(.caption, design: .monospaced))
                        }
                    }
                }.frame(height: 150).background(.regularMaterial).cornerRadius(8)
            }
        }
    }
    
    var blockReasonText: String {
        if !sipStatus.contains("Disabled") { return "SIP deve estar desabilitado" }
        if !efiMounted { return "Monte a EFI primeiro" }
        if !payloadsReady { return "Payloads ausentes" }
        if !(configDiag?.isReady ?? false) { return "Corrija o config.plist primeiro (veja acima)" }
        return ""
    }
    
    var patchProgress: some View {
        GlassCard {
            HStack { Text("Aplicando Patches...").font(.headline); Spacer(); ProgressView() }
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(logs, id: \.self) { Text($0).font(.caption) }
                }
            }.frame(height: 200).background(Color.black.opacity(0.1)).cornerRadius(8)
        }
    }
    
    // MARK: - Helper Views
    struct StatusRow: View {
        let label: String; let value: String
        var color: Color = .primary; var icon: String? = nil
        var body: some View {
            HStack {
                if let i = icon { Image(systemName: i).frame(width: 20).foregroundColor(.secondary) }
                Text(label).foregroundColor(.secondary); Spacer()
                Text(value).bold().foregroundColor(color)
            }.font(.subheadline)
        }
    }

    // MARK: - Actions
    
    func mountEFI() {
        isMountingEFI = true
        logs.append("Procurando partição EFI...")
        showLogs = true
        DispatchQueue.global().async {
            let efiDisk = EFIAnalyzer.findEFIPartition() ?? "não encontrado"
            DispatchQueue.main.async { self.logs.append("EFI disk: \(efiDisk)") }
            let result = EFIAnalyzer.mountEFI()
            DispatchQueue.main.async {
                isMountingEFI = false
                if result.success {
                    logs.append("✅ \(result.message)")
                    bcmLoading = true; configDiag = nil; showLogs = false
                    checkSystem()
                } else {
                    logs.append("❌ \(result.message)")
                }
            }
        }
    }
    
    func applyPatches(dryRun: Bool) {
        isPatching = true; logs.removeAll(); showLogs = true
        DispatchQueue.global().async {
            let res = RootPatcher.applyPatches(
                includeAudio: includeAudio,
                audioKextPath: audioKextPath,
                dryRun: dryRun
            )
            DispatchQueue.main.async {
                isPatching = false; logs = res.logs
                if res.success && res.requiresRestart {
                    logs.append("✅ SUCESSO! Reinicie o Mac.")
                }
            }
        }
    }
    
    func revertSnapshot() {
        isRevertingSnapshot = true; logs = ["Revertendo snapshot..."]; showLogs = true
        DispatchQueue.global().async {
            let result = EFIAnalyzer.revertSnapshot()
            DispatchQueue.main.async {
                isRevertingSnapshot = false; showRevertConfirm = false
                logs.append(result.success ? "✅ \(result.message)" : "❌ \(result.message)")
            }
        }
    }

    func selectAudioKext() {
        let panel = NSOpenPanel()
        panel.title = "Selecione a Kext de Áudio"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowedContentTypes = []
        panel.message = "Selecione a pasta da kext de áudio (ex: AppleALC.kext ou AppleHDA.kext)"
        panel.directoryURL = URL(fileURLWithPath: "/Volumes/EFI/EFI/OC/Kexts")
        
        if panel.runModal() == .OK, let url = panel.url {
            if url.lastPathComponent.hasSuffix(".kext") {
                audioKextPath = url.path
                logs.append("Audio kext selecionada: \(url.lastPathComponent)")
            } else {
                logs.append("⚠️ Selecione uma pasta .kext")
                showLogs = true
            }
        }
    }
    
    func checkSystem() {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process(); p.launchPath = "/usr/bin/sw_vers"; p.arguments = ["-productVersion"]
            let pipe = Pipe(); p.standardOutput = pipe; try? p.run(); p.waitUntilExit()
            let osVer = (String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            let s = Process(); s.launchPath = "/usr/bin/csrutil"; s.arguments = ["authenticated-root", "status"]
            let sp = Pipe(); s.standardOutput = sp; s.standardError = sp; try? s.run(); s.waitUntilExit()
            let sipOut = String(data: sp.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let sipStat = sipOut.lowercased().contains("disabled") ? "Disabled (OK)" : "Ativo (Erro)"
            
            let efiExists = EFIAnalyzer.isEFIMounted()
            let payloads = PayloadManager.arePayloadsBundled()
            let bcm = BCMDetector.detectChipset()
            let kdk = KDKDetector.detect()
            
            var diag: ConfigAnalyzer.Diagnostic? = nil
            if efiExists {
                diag = ConfigAnalyzer.analyze(
                    configPath: "/Volumes/EFI/EFI/OC/config.plist",
                    chipsetFamily: bcm.info?.family ?? .unknown
                )
            }
            
            DispatchQueue.main.async {
                self.osVersion = osVer; self.sipStatus = sipStat
                self.efiMounted = efiExists; self.payloadsReady = payloads
                self.bcmInfo = bcm; self.configDiag = diag
                self.kdkInfo = kdk; self.bcmLoading = false
            }
        }
    }
}

// MARK: - Extensions
extension View {
    @ViewBuilder
    func transparentScrolling() -> some View {
        if #available(macOS 13.0, *) { self.scrollContentBackground(.hidden).scrollIndicators(.visible) }
        else { self }
    }
}
