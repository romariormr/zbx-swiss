# Changelog

Todas as mudanças notáveis deste projeto estão documentadas aqui.

---

## [7.0] — 2025

### Novas funcionalidades

**Health Check Completo (opção 7 / `--health-check`)**
- 12 verificações automáticas: proxy instalado, serviço ativo, config válida, integridade do banco SQLite (`PRAGMA integrity_check`), conectividade proxy→server na porta 10051, acesso a repo.zabbix.com, uso de disco, uso de RAM, logrotate, cron de backup, backups disponíveis e TLS/PSK
- Score visual (ex: `10/12 checks OK — 83%`) com status: OK / Atenção / Crítico

**Restaurar Backup (opção 11 / `--restore`)**
- Lista backups disponíveis em `/var/backups/zabbix-proxy/` com tamanho e data
- Verifica integridade do backup antes de restaurar (`PRAGMA integrity_check`)
- Preserva o banco atual como `.pre-restore-*` antes de sobrescrever
- Para o proxy, restaura, reinicia — rollback automático se backup corrompido

**TLS/PSK (opção 12 / `--tls-psk`)**
- Gera chave PSK via `openssl rand -hex 32`
- Salva em `/etc/zabbix/zabbix_proxy.psk` (permissão 640, dono zabbix)
- Adiciona `TLSConnect`, `TLSAccept`, `TLSPSKFile`, `TLSPSKIdentity` no `zabbix_proxy.conf`
- Exibe identidade e chave para configurar no servidor Zabbix (Administration → Proxies → Encryption)
- Suporte a regeneração de chave existente

**Exportar Diagnóstico (opção 18 / `--diagnose`)**
- Gera relatório completo em `/tmp/zbx-swiss-diag-YYYYMMDD_HHMMSS.txt`
- Inclui: OS, hardware, disco, processos Zabbix, status do serviço, configuração sanitizada (sem PSK/senhas), integridade do banco, rede, portas, logs (50 linhas), crontab e lista de backups

**Self-Update (opção 20 / `--self-update`)**
- Baixa a versão mais recente de `raw.githubusercontent.com/romariormr/zbx-swiss/main/zbx-swiss.sh`
- Compara versão local vs remota — não atualiza se já estiver na versão mais recente
- Valida sintaxe (`bash -n`) antes de substituir
- Faz backup do script atual antes de atualizar

**Teste de conectividade Proxy→Server**
- `connectivity_check_server()` via `/dev/tcp` — verifica porta 10051
- Chamado automaticamente ao final da instalação
- Disponível como verificação isolada no Health Check

### GitHub Actions
- Workflow `shellcheck.yml`: valida sintaxe (`bash -n`) + ShellCheck em todo push/PR

### Menu atualizado
- 20 opções organizadas em 6 seções: Zabbix Proxy · Disco & Banco · Segurança · Manutenção · Sistema · Configurações

### CLI
- Novos flags: `--health-check`, `--restore`, `--tls-psk`, `--diagnose`, `--self-update`

---

## [6.0] — 2025

### Novo nome
- Renomeado para **ZBX Swiss Manager** (`zbx-swiss.sh`) — sem dados pessoais

### Configuração persistente
- `/etc/zbx-swiss/config.conf` com parser seguro (sem `eval`)
- Wizard de primeira execução; opção 15 para reconfigurar

### Menu renovado (15 opções em 5 categorias)
- Novo: Reiniciar (4), Logs ao Vivo (5), Backup Agora (9)

### Barra de status no cabeçalho
- Status do proxy, versão, disco %, RAM %, indicador root

### CLI
- `--install`, `--remove`, `--status`, `--expand-disk`, `--backup`, `--restart`, `--reconfigure`

---

## [5.0] — 2025

### Correções críticas
- **NVMe**: regex `^(/dev/nvme[0-9]+n[0-9]+)p([0-9]+)$` — corrige detecção
- **validate_config()**: avalia exit code de `zabbix_proxy -T`, não do `grep`
- **Rescan completo**: SCSI, virtio, NVMe, Xen via sysfs + `partx -u` + `udevadm settle`
- **Correção GPT**: `sgdisk -e` / `gdisk` / `fdisk` fallback
- **cron automático**: adicionado sem intervenção manual

### Multi-distro
- Ubuntu · Debian · Oracle Linux · Rocky · AlmaLinux · CentOS Stream
- Abstração `pkg_update()` / `pkg_install()` / `pkg_remove()`

---

## [4.1] — 2025

- Suporte multi-distro inicial (apt + dnf)
- 11 opções de menu
- `system_cleanup()`, `show_system_info()`, `monitor_resources()`

---

## [3.0] — 2025 (base original)

- Ubuntu/Debian apenas
- 9 opções de menu
- Instalação básica Zabbix Proxy + Agent + webhook
