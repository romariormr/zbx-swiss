# Changelog

Todas as mudanças notáveis deste projeto estão documentadas aqui.

---

## [6.0] — ZBX Swiss Manager — 2025

### Novo nome
- Renomeado de "Universal Zabbix & System Manager" para **ZBX Swiss Manager** (`zbx-swiss.sh`)
- Dados pessoais removidos — script público e neutro

### Configuração persistente
- Arquivo de configuração em `/etc/zbx-swiss/config.conf`
- Parser seguro (sem `eval` ou `source`) — lê linha a linha com `case` allowlist
- Wizard interativo na primeira execução (SERVER_IP obrigatório)
- Opção 15 no menu para reconfigurar a qualquer momento
- CLI `--reconfigure` para reconfigurar sem entrar no menu

### Menu renovado (15 opções em 5 categorias)
- **Zabbix Proxy**: Instalar · Remover · Status · Reiniciar (novo) · Logs ao Vivo (novo) · Agent2
- **Disco & Banco**: Expandir LVM · VACUUM · Backup Agora (novo)
- **Manutenção**: Atualizações · Manutenção Automática · Limpeza
- **Sistema**: Informações · Monitor
- **Configurações**: Reconfigurar ZBX Swiss

### Barra de status no cabeçalho
- Status do proxy (ativo/inativo/não instalado) + versão
- Uso de disco (%) e RAM (%) em tempo real
- Indicador root

### CLI direto (sem entrar no menu)
- `--install`, `--remove`, `--status`, `--expand-disk`, `--backup`, `--restart`, `--reconfigure`

---

## [5.0] — 2025

### Correções críticas de bugs
- **NVMe detection**: regex `^(/dev/nvme[0-9]+n[0-9]+)p([0-9]+)$` substitui `${PV_DEV%[0-9]*}` que produzia `/dev/nvme` sem número
- **validate_config()**: avalia exit code do `zabbix_proxy -T`, não do `grep`
- **Rescan de disco completo**: cobre SCSI, virtio-blk, virtio-scsi, NVMe (rescan_controller), Xen — via sysfs + `partx -u` + `udevadm settle`
- **Correção GPT**: `sgdisk -e` / `gdisk` / `fdisk` fallback após expansão no hypervisor
- **cron automático**: `setup_maintenance()` adiciona cron automaticamente em vez de instruir edição manual

### Segurança
- `curl` com `--max-time` em todas as chamadas externas
- CLI args `--data-sender-frequency` e `--timeout` implementados
- `show_help()` movido antes do parser

### Multi-distro
- Suporte completo: Ubuntu · Debian · Oracle Linux · Rocky · AlmaLinux · CentOS Stream
- Abstração `pkg_update()` / `pkg_install()` / `pkg_remove()` para apt e dnf

---

## [4.1] — 2025

- Suporte multi-distro inicial
- Menu com 11 opções
- `system_cleanup()`, `show_system_info()`, `monitor_resources()`
- Disco expandido com fallback para `parted` além de `growpart`
- Abstração de pacotes (apt/dnf)

---

## [3.0] — 2025 (base original)

- Ubuntu/Debian only
- Menu com 9 opções
- Instalação básica Zabbix Proxy + Agent
- Webhook de notificação
- VACUUM SQLite
- Informações do sistema
