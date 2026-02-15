# SafeMyHack (Legacy Patcher — WiFi & Audio)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![macOS](https://img.shields.io/badge/macOS-Sonoma%20%7C%20Sequoia%20%7C%20Tahoe-brightgreen)](https://www.apple.com/macos/)
[![Platform](https://img.shields.io/badge/Platform-Intel%20%7C%20AMD-orange)](https://github.com/thalesmourabh/SafeMyHack)
[![Build](https://github.com/thalesmourabh/SafeMyHack/actions/workflows/release.yml/badge.svg)](https://github.com/thalesmourabh/SafeMyHack/actions)

O SafeMyHack é uma ferramenta **open-source** para ativar **WiFi Broadcom + Audio** no macOS Tahoe (26), Sequoia (15) e Sonoma (14).

Funciona em Hackintoshes **Intel e AMD**, sem precisar de Xcode ou qualquer ferramenta de desenvolvimento instalada.

> ⚠️ **Projeto em Desenvolvimento**: Este é um projeto da comunidade. Use por sua conta e risco.

---

## 🇧🇷 Português

### Por que SafeMyHack?

| Característica | OCLP-Mod | SafeMyHack |
|----------------|----------|------------|
| API Remota | ✅ SimpleHacAPI | ❌ **100% Local** |
| Modifica config.plist | ✅ Automaticamente | ❌ **Apenas instrui** |
| WiFi + Audio | WiFi apenas | ✅ **WiFi + Audio** |
| Código Auditável | Parcial | ✅ **Totalmente Aberto** |
| Compilado no GitHub | Não | ✅ **CI público** |
| Xcode Necessário | Depende | ❌ **Não precisa** |
| Telemetria | Desconhecido | ❌ **Zero** |

### Instalação

#### Baixe e use

1. Vá na aba [Releases](https://github.com/thalesmourabh/SafeMyHack/releases)
2. Baixe o arquivo `SafeMyHack-vX.X.X-Intel-AMD.zip`
3. Extraia o `.zip` e mova `SafeMyHack.app` para `/Applications`
4. Na primeira vez que abrir:

**macOS Sonoma (14):**
- Botão direito no app → Abrir → Confirmar "Abrir"

**macOS Sequoia (15) / Tahoe (26):**
- Abra o Terminal e execute:
```bash
xattr -cr /Applications/SafeMyHack.app
```
- Depois abra o SafeMyHack normalmente

> 💡 **Alternativa para qualquer macOS:** Duplo-clique (vai bloquear) → Ajustes do Sistema → Privacidade e Segurança → "Abrir Mesmo Assim"

#### Compilar do Código-Fonte (Desenvolvedores)

```bash
git clone https://github.com/thalesmourabh/SafeMyHack.git
cd SafeMyHack
chmod +x build.sh
bash build.sh
# O .zip estará em dist/
```

### Requisitos

- **macOS**: Sonoma (14), Sequoia (15), ou Tahoe (26)
- **Hardware**: Hackintosh Intel ou AMD
- **Placa WiFi**: Broadcom compatível (Fenvi T919, Dell DW1560, DW1820A, etc)
- **SIP**: Desabilitado (`csr-active-config=03080000`)
- **OpenCore**: Com config.plist configurado (kexts + boot-args + blocks)
- **KDK**: Para ativar áudio (baixar em developer.apple.com — instruções no app)
- **Xcode**: **NÃO necessário** — funciona sem Xcode instalado

### Como Funciona

```
┌─────────────────────────────────────────────────┐
│  1. DETECÇÃO AUTOMÁTICA                         │
│     - Detecta macOS via sw_vers                 │
│     - Verifica SIP via csrutil                  │
│     - Localiza e monta partição EFI             │
│     - Identifica chipset Broadcom via PCI       │
│     - Detecta KDK instalado                     │
├─────────────────────────────────────────────────┤
│  2. DIAGNÓSTICO (INFORMACIONAL)                 │
│     - Analisa config.plist do OpenCore          │
│     - Verifica kexts na EFI/OC/Kexts/           │
│     - Verifica boot-args necessários            │
│     - Verifica blocks (IOSkywalkFamily)         │
│     - Verifica SecureBootModel                  │
│     - ⚠️ NÃO modifica — apenas INSTRUI         │
├─────────────────────────────────────────────────┤
│  3. PREPARAÇÃO (feita pelo USUÁRIO)             │
│     - Coloque suas kexts em EFI/OC/Kexts/      │
│     - Faça OC Clean Snapshot no ProperTree      │
│     - Corrija boot-args e blocks conforme       │
│       instruído pelo app                        │
├─────────────────────────────────────────────────┤
│  4. AUDIO (Opcional)                            │
│     - Instale o KDK (instruções no app)         │
│     - Selecione sua kext de áudio no app        │
├─────────────────────────────────────────────────┤
│  5. ROOT PATCH                                  │
│     - Copia kexts da EFI → sistema              │
│     - Instala payloads WiFi (frameworks)        │
│     - Instala kext de áudio (se selecionada)    │
│     - Reconstrói kernel cache (kmutil)          │
│     - Cria snapshot bootável (bless)            │
│     - Requer reinício após aplicar              │
├─────────────────────────────────────────────────┤
│  6. REVERTER SNAPSHOT                           │
│     - Desfaz root patches                       │
│     - Necessário antes de atualizar macOS       │
└─────────────────────────────────────────────────┘
```

### Como Usar (Passo a Passo)

1. **Coloque suas kexts** na EFI (`AMFIPass`, `IOSkywalkFamily`, `IO80211FamilyLegacy` em `/EFI/OC/Kexts/`)
2. **Faça OC Clean Snapshot** no ProperTree para registrar no config.plist
3. **Abra o SafeMyHack** — detecta hardware automaticamente
4. **Monte a EFI** — botão na interface
5. **Verifique o Config** — o app mostra o que falta com instruções claras
6. **Corrija no ProperTree/OCAT** — siga as instruções do app
7. **Instale o KDK** — se quiser ativar áudio (instruções no app)
8. **Selecione a Kext de Áudio** — clique no botão e selecione sua kext
9. **Root Patch** — copia kexts da EFI pro sistema + instala payloads e audio
10. **Reinicie** — WiFi e Audio ativados!

### O que ele NÃO faz

- ❌ **Não modifica** seu config.plist — apenas instrui o que corrigir
- ❌ **Não injeta kexts** na EFI — você coloca e faz OC Clean Snapshot
- ❌ **Não envia dados** para nenhum servidor
- ❌ **Não requer internet** para funcionar
- ❌ **Sem telemetria**, analytics, ou qualquer API externa

### Verificação de Integridade

O app é compilado pelo **GitHub Actions** — qualquer pessoa pode verificar o processo de build. Cada release inclui um arquivo `.sha256` para verificação:

```bash
# Verificar que o arquivo baixado não foi alterado
shasum -a 256 -c SafeMyHack-v1.0.0-Intel-AMD.zip.sha256
```

### Estrutura do Projeto

```
SafeMyHack/
├── SafeMyHackApp.swift              # Entry point
├── Package.swift                    # Swift Package Manager
├── build.sh                         # Build script (local + CI)
├── .github/workflows/release.yml    # GitHub Actions CI/CD
├── Frontend/
│   ├── ContentView.swift            # Interface SwiftUI (Tahoe Glass)
│   └── EFIAnalyzer.swift            # Detecção e mount EFI dinâmico
├── Helper/
│   ├── BCMDetector.swift            # Detecção de chipset Broadcom via PCI
│   ├── ConfigAnalyzer.swift         # Diagnóstico config.plist (read-only)
│   ├── KDKDetector.swift            # Detecção KDK + instruções
│   ├── PayloadManager.swift         # Gerenciamento de payloads WiFi
│   └── RootPatcher.swift            # Root patch (EFI→sistema + audio)
├── Resources/
│   └── Payloads/                    # Frameworks WiFi (OCLP)
├── LICENSE                          # GPL-3.0
├── RELEASE_NOTES.md                 # Notas de release bilíngues
└── README.md                        # Este arquivo
```

### Segurança

- 🔒 **GPL-3.0**: Forks maliciosos são forçados a manter código aberto
- 📝 **Transparente**: Mostra tudo que vai fazer antes de agir
- 🔄 **Recuperação**: Reverter Snapshot desfaz tudo
- 🚫 **Sem Telemetria**: Zero comunicação externa
- 📦 **100% Local**: Nenhuma API remota, tudo roda na sua máquina
- ⚙️ **CI Público**: Compilado no GitHub Actions, processo 100% auditável
- 🛡️ **Não toca no config.plist**: Suas configurações são intocáveis

---

## 🇺🇸 English

### What is SafeMyHack?

SafeMyHack is an **open-source** tool for Intel/AMD Hackintosh that restores **Broadcom WiFi + Audio** on macOS **Sonoma (14)**, **Sequoia (15)**, and **Tahoe (26)**.

Apple removed Broadcom WiFi support starting with Sonoma. SafeMyHack fixes this safely, transparently, and without touching your config.plist.

### Why SafeMyHack?

| Feature | OCLP-Mod | SafeMyHack |
|---------|----------|------------|
| Remote API | ✅ SimpleHacAPI | ❌ **100% Local** |
| Modifies config.plist | ✅ Automatically | ❌ **Only instructs** |
| WiFi + Audio | WiFi only | ✅ **WiFi + Audio** |
| Auditable Code | Partial | ✅ **Fully Open** |
| Built on GitHub | No | ✅ **Public CI** |
| Xcode Required | Depends | ❌ **Not needed** |
| Telemetry | Unknown | ❌ **Zero** |

### Installation

1. Download `SafeMyHack-vX.X.X-Intel-AMD.zip` from [Releases](https://github.com/thalesmourabh/SafeMyHack/releases)
2. Extract and move `SafeMyHack.app` to `/Applications`
3. First run:
   - **Sonoma**: Right-click → Open → Confirm
   - **Sequoia/Tahoe**: `xattr -cr /Applications/SafeMyHack.app` in Terminal

### Requirements

- **macOS**: Sonoma (14), Sequoia (15), or Tahoe (26)
- **Hardware**: Intel or AMD Hackintosh (x86_64)
- **WiFi**: Broadcom card (Fenvi T919, Dell DW1560, DW1820A, etc)
- **SIP**: Disabled (`csr-active-config=03080000`)
- **OpenCore**: With configured config.plist (kexts + boot-args + blocks)
- **KDK**: For audio activation (download from developer.apple.com — instructions in app)
- **Xcode**: **NOT required**

### How to Use

1. **Place your kexts** in EFI (`AMFIPass`, `IOSkywalkFamily`, `IO80211FamilyLegacy` in `/EFI/OC/Kexts/`)
2. **OC Clean Snapshot** in ProperTree to register in config.plist
3. **Open SafeMyHack** — auto-detects your hardware
4. **Mount EFI** — button in the UI
5. **Check Config** — app shows what's missing with clear instructions
6. **Fix in ProperTree/OCAT** — follow the app's instructions
7. **Install KDK** — for audio activation (instructions in app)
8. **Select Audio Kext** — click button and select your audio kext
9. **Root Patch** — copies kexts from EFI to system + installs payloads and audio
10. **Reboot** — WiFi and Audio activated!

### What it does NOT do

- ❌ Does **NOT** modify your config.plist — only instructs you
- ❌ Does **NOT** inject kexts into EFI — you add them and OC Clean Snapshot
- ❌ Does **NOT** send data to any server
- ❌ Does **NOT** require internet to work
- ❌ **No telemetry**, analytics, or external APIs

### Security

- 🔒 **GPL-3.0**: Malicious forks must keep code open
- 📝 **Transparent**: Shows everything before acting
- 🔄 **Recovery**: Revert Snapshot undoes everything
- 🚫 **No Telemetry**: Zero external communication
- 📦 **100% Local**: No remote APIs, runs entirely on your machine
- ⚙️ **Public CI**: Built on GitHub Actions, fully auditable
- 🛡️ **Config-safe**: Never touches your config.plist

---

## Créditos / Credits

- [OCLP](https://github.com/dortania/OpenCore-Legacy-Patcher) — Modern Wireless patch logic & payloads
- [OpenCore](https://github.com/acidanthera/OpenCorePkg) — Bootloader
- [Acidanthera](https://github.com/acidanthera) — Kexts essenciais
- Gabriel Luchina — Feedback e testes na live
- Comunidade Hackintosh BR

## Licença / License

[GPL-3.0](LICENSE) — Código deve permanecer aberto / Code must remain open.

---

**Feito com ❤️ para a comunidade Hackintosh brasileira**
