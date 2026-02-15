# SafeMyHack

**Legacy Patcher para Hackintosh — WiFi Broadcom + Audio**

> 🛡️ 100% Local • Sem Telemetria • Sem API Externa • Código Aberto (GPL-3.0)

---

## 🇧🇷 Português

### O que é o SafeMyHack?

O SafeMyHack é uma ferramenta para Hackintosh Intel/AMD que restaura o WiFi Broadcom e o Áudio em macOS **Sonoma (14)**, **Sequoia (15)** e **Tahoe (26)**.

A Apple removeu o suporte às placas WiFi Broadcom (Fenvi T919, Dell DW1560, DW1820A, etc) a partir do Sonoma. O SafeMyHack resolve isso de forma segura, automática e transparente.

### O que ele faz?

- **Detecta seu hardware** via PCI (`ioreg`), sem depender de drivers carregados
- **Monta a EFI dinamicamente**, identificando o disco de boot correto (NVMe, SATA, USB)
- **Analisa o config.plist** do OpenCore e te mostra exatamente o que precisa corrigir
- **Verifica kexts na EFI** — confirma se todas as kexts necessárias estão presentes
- **Verifica o KDK** (Kernel Debug Kit) necessário para ativar áudio
- **Permite carregar a Kext de áudio** que o usuário fornece
- **Aplica Root Patches**: copia kexts da EFI → sistema, instala payloads WiFi + audio com proteção
- **Reverte Snapshot** para receber updates delta do macOS

### O que ele NÃO faz

- ❌ **Não modifica** seu config.plist — ele te instrui o que corrigir
- ❌ **Não injeta kexts** na EFI — você coloca suas kexts e faz OC Clean Snapshot no ProperTree
- ❌ Não envia dados para nenhum servidor
- ❌ Não requer internet para funcionar
- ❌ Não tem telemetria, analytics, ou qualquer API externa

### Requisitos

| Requisito | Detalhes |
|-----------|----------|
| macOS | 14 (Sonoma), 15 (Sequoia) ou 26 (Tahoe) |
| Hardware | Intel ou AMD (x86_64) |
| WiFi | Broadcom (Fenvi T919, Dell DW1560, DW1820A, etc) |
| SIP | Desabilitado (`csrutil authenticated-root disable` no Recovery) |
| OpenCore | Com config.plist configurado corretamente |
| KDK | Para ativar áudio (baixar em developer.apple.com) |
| Xcode | **NÃO necessário** — funciona sem Xcode instalado |

### Instalação

1. Baixe o `SafeMyHack-vX.X.X-Intel-AMD.zip` na aba [Releases](../../releases)
2. Extraia e mova `SafeMyHack.app` para `/Applications`
3. Primeira execução:
   - **Sonoma**: Botão direito → Abrir → Confirme
   - **Sequoia/Tahoe**: `xattr -cr SafeMyHack.app` no Terminal

### Como usar

1. **Coloque suas kexts** na EFI (`AMFIPass`, `IOSkywalkFamily`, `IO80211FamilyLegacy` em `/EFI/OC/Kexts/`)
2. **Faça OC Clean Snapshot** no ProperTree para registrar no config.plist
3. **Abra o SafeMyHack** — ele detecta seu hardware automaticamente
4. **Monte a EFI** — botão na interface
5. **Verifique o Config** — o app mostra tudo que falta com instruções claras
6. **Corrija no ProperTree/OCAT** — se necessário, siga as instruções do app
7. **Instale o KDK** — se quiser ativar áudio (instruções no app)
8. **Carregue a Kext de Áudio** — selecione sua kext de audio no botão do app
9. **Root Patch** — copia kexts da EFI pro sistema, instala payloads e audio
10. **Reinicie** — WiFi e Audio ativados

### Segurança e Transparência

O SafeMyHack é **100% local**:

- Todo o código fonte está disponível neste repositório
- Não há chamadas de rede, APIs, ou telemetria
- Não coleta, transmite, ou armazena dados do usuário
- O app roda inteiramente offline
- Licença GPL-3.0 — qualquer um pode auditar, modificar e redistribuir

### Estrutura do Projeto

```
SafeMyHack/
├── SafeMyHackApp.swift          # Entry point
├── Frontend/
│   ├── ContentView.swift        # UI principal (Tahoe Glass)
│   └── EFIAnalyzer.swift        # Mount EFI dinâmico
├── Helper/
│   ├── BCMDetector.swift        # Detecção PCI via ioreg
│   ├── ConfigAnalyzer.swift     # Análise config.plist (read-only, instrui)
│   ├── KDKDetector.swift        # Detecção KDK + instruções
│   ├── PayloadManager.swift     # Gerência de payloads WiFi
│   └── RootPatcher.swift        # Root patch (EFI→sistema + payloads + audio)
├── Resources/
│   └── Payloads/                # Payloads WiFi (frameworks OCLP)
├── build.sh                     # Build script (sem Xcode dep)
└── .github/workflows/           # CI/CD
```

---

## 🇺🇸 English

### What is SafeMyHack?

SafeMyHack is a tool for Intel/AMD Hackintosh that restores Broadcom WiFi and Audio on macOS **Sonoma (14)**, **Sequoia (15)**, and **Tahoe (26)**.

Apple removed Broadcom WiFi support (Fenvi T919, Dell DW1560, DW1820A, etc) starting with Sonoma. SafeMyHack fixes this safely, automatically, and transparently.

### Features

- **Hardware detection** via PCI (`ioreg`), works without loaded drivers
- **Dynamic EFI mount**, correctly identifies boot disk (NVMe, SATA, USB)
- **Config.plist analysis** — shows exactly what needs fixing with clear instructions
- **EFI kext verification** — confirms all required kexts are present
- **KDK verification** (Kernel Debug Kit) required for audio activation
- **Audio kext loading** — user provides their own audio kext
- **Root Patches**: copies kexts from EFI → system, installs WiFi payloads + audio with protection
- **Snapshot revert** for receiving delta macOS updates

### What it does NOT do

- ❌ Does **NOT** modify your config.plist — it instructs you
- ❌ Does **NOT** inject kexts into EFI — you add kexts and OC Clean Snapshot in ProperTree
- ❌ Does NOT send data to any server
- ❌ Does NOT require internet to work
- ❌ No telemetry, analytics, or external APIs

### Requirements

| Requirement | Details |
|-------------|---------|
| macOS | 14 (Sonoma), 15 (Sequoia) or 26 (Tahoe) |
| Hardware | Intel or AMD (x86_64) |
| WiFi | Broadcom (Fenvi T919, Dell DW1560, DW1820A, etc) |
| SIP | Disabled (`csrutil authenticated-root disable` in Recovery) |
| OpenCore | With properly configured config.plist |
| KDK | For audio activation (download from developer.apple.com) |
| Xcode | **NOT required** — works without Xcode installed |

### Installation

1. Download `SafeMyHack-vX.X.X-Intel-AMD.zip` from [Releases](../../releases)
2. Extract and move `SafeMyHack.app` to `/Applications`
3. First run:
   - **Sonoma**: Right-click → Open → Confirm
   - **Sequoia/Tahoe**: `xattr -cr SafeMyHack.app` in Terminal

### How to use

1. **Place your kexts** in EFI (`AMFIPass`, `IOSkywalkFamily`, `IO80211FamilyLegacy` in `/EFI/OC/Kexts/`)
2. **OC Clean Snapshot** in ProperTree to register in config.plist
3. **Open SafeMyHack** — auto-detects your hardware
4. **Mount EFI** — button in the UI
5. **Check Config** — app shows what's missing with clear instructions
6. **Fix in ProperTree/OCAT** — if needed, follow the app's instructions
7. **Install KDK** — for audio activation (instructions in app)
8. **Load Audio Kext** — select your audio kext via the app button
9. **Root Patch** — copies kexts from EFI to system, installs payloads and audio
10. **Reboot** — WiFi and Audio activated

### Security & Transparency

SafeMyHack is **100% local**:

- Full source code available in this repository
- No network calls, APIs, or telemetry
- Does not collect, transmit, or store user data
- Runs entirely offline
- GPL-3.0 License — anyone can audit, modify, and redistribute

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

## Credits

- [OCLP](https://github.com/dortania/OpenCore-Legacy-Patcher) — Modern Wireless patch logic
- [OpenCore](https://github.com/acidanthera/OpenCorePkg) — Bootloader
- Gabriel Luchina — Feedback e testes na live
- Comunidade Hackintosh BR
