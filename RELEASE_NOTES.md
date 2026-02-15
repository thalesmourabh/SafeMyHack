# SafeMyHack v1.0.0 — Release Notes

## 🇧🇷 Notas (PT-BR)

### Primeiro Release
SafeMyHack é o sucessor espiritual do SafeBCM, agora com suporte a **WiFi + Áudio** para Hackintosh Intel/AMD.

### Funcionalidades
- **Detecção PCI via ioreg**: Lê hardware direto da árvore PCI, sem depender de drivers
- **EFI Mount dinâmico**: Identifica o disco de boot correto (NVMe, SATA, USB)
- **Análise de config.plist**: Mostra instruções claras do que corrigir (não modifica)
- **Verificação de kexts na EFI**: Confirma se todas as kexts necessárias estão presentes
- **Detecção de KDK**: Verifica se o Kernel Debug Kit está instalado e compatível
- **Carregamento de Kext de Áudio**: Usuário seleciona sua kext de audio no app
- **Root Patch**: Copia kexts da EFI → sistema + instala payloads WiFi + audio com proteção
- **Reverter Snapshot**: Para receber delta updates do macOS
- **100% Local**: Sem telemetria, sem API externa, código aberto GPL-3.0
- **Não injeta kexts na EFI**: Usuário prepara via ProperTree (OC Clean Snapshot)

### Instalação
1. Baixe `SafeMyHack-v1.0.0-Intel-AMD.zip`
2. Extraia e mova para Aplicativos
3. Primeira vez: `xattr -cr SafeMyHack.app` (Sequoia/Tahoe)

---

## 🇺🇸 Notes (EN)

### First Release
SafeMyHack is the spiritual successor to SafeBCM, now supporting **WiFi + Audio** for Intel/AMD Hackintosh.

### Features
- **PCI detection via ioreg**: Reads hardware directly from PCI tree, no driver dependency
- **Dynamic EFI mount**: Correctly identifies boot disk (NVMe, SATA, USB)
- **Config.plist analysis**: Shows clear instructions on what to fix (no auto-modification)
- **KDK detection**: Checks if Kernel Debug Kit is installed and compatible
- **Audio kext loading**: Option to select user's audio kext
- **Root Patch WiFi + Audio**: Applies patches with snapshot corruption protection
- **Snapshot revert**: For receiving delta macOS updates
- **100% Local**: No telemetry, no external APIs, open source GPL-3.0

### Installation
1. Download `SafeMyHack-v1.0.0-Intel-AMD.zip`
2. Extract and move to Applications
3. First run: `xattr -cr SafeMyHack.app` (Sequoia/Tahoe)
