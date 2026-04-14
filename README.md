# ZBX Swiss Manager

<p align="center">
  <img src="https://img.shields.io/badge/version-6.0-blue?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/bash-5.0+-green?style=for-the-badge&logo=gnubash" alt="Bash">
  <img src="https://img.shields.io/badge/zabbix-6.x%20%7C%207.x-red?style=for-the-badge" alt="Zabbix">
  <img src="https://img.shields.io/badge/license-MIT-yellow?style=for-the-badge" alt="License">
</p>

<p align="center">
  <b>Canivete suíço para Zabbix Proxy — instalação, gerenciamento e manutenção em um único script.</b>
</p>

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║              ██████╗ ██████╗ ██╗  ██╗    ███████╗██╗    ██╗██╗███████╗       ║
║             ╚════██╗██╔══██╗╚██╗██╔╝    ██╔════╝██║    ██║██║██╔════╝       ║
║              █████╔╝██████╔╝ ╚███╔╝     ███████╗██║ █╗ ██║██║███████╗       ║
║             ██╔═══╝ ██╔══██╗ ██╔██╗     ╚════██║██║███╗██║██║╚════██║       ║
║             ███████╗██████╔╝██╔╝ ██╗    ███████║╚███╔███╔╝██║███████║       ║
║             ╚══════╝╚═════╝ ╚═╝  ╚═╝    ╚══════╝ ╚══╝╚══╝ ╚═╝╚══════╝       ║
║                                                                               ║
║                     ZBX Swiss Manager v6.0                                   ║
║            Canivete suíço para Zabbix Proxy — Multi-distro                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## Recursos

- **Instalação completa** do Zabbix Proxy (SQLite) com uma única execução
- **Expansão de disco LVM sem reboot** — suporte a SCSI, virtio-blk, NVMe, Xen
- **Configuração persistente** — salva suas preferências em `/etc/zbx-swiss/config.conf`
- **Multi-distro** — Ubuntu · Debian · Oracle Linux · Rocky · AlmaLinux · CentOS Stream
- **Menu interativo** com barra de status em tempo real (proxy, disco, RAM)
- **CLI completo** — `--install`, `--status`, `--expand-disk`, `--backup` e mais
- **Backup automático** com cron, logrotate e VACUUM do SQLite
- **Notificação webhook** após instalação (n8n, Zapier, etc.)
- **Modo dry-run** e auto-confirm para automação

---

## Distribuições Suportadas

| Distro | Versões |
|--------|---------|
| Ubuntu | 20.04 · 22.04 · 24.04 |
| Debian | 11 · 12 |
| Oracle Linux | 8 · 9 |
| Rocky Linux | 8 · 9 |
| AlmaLinux | 8 · 9 |
| CentOS Stream | 8 · 9 |

---

## Instalação rápida

```bash
# Baixar o script
curl -fsSL https://raw.githubusercontent.com/SEU_USUARIO/zbx-swiss/main/zbx-swiss.sh \
  -o zbx-swiss.sh

# Dar permissão de execução
chmod +x zbx-swiss.sh

# Executar como root
sudo ./zbx-swiss.sh
```

Na primeira execução, um **wizard** guiará a configuração inicial (IP do servidor, timezone, webhook, etc.). As preferências são salvas em `/etc/zbx-swiss/config.conf` e carregadas automaticamente nas próximas execuções.

---

## Menu

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                       🔧  ZABBIX PROXY                                       ║
╚═══════════════════════════════════════════════════════════════════════════════╝
  1)  📦 Instalar Zabbix Proxy
  2)  🗑️  Remover Zabbix Proxy
  3)  📊 Status dos Serviços
  4)  🔁 Reiniciar Serviços
  5)  📜 Ver Logs ao Vivo
  6)  📡 Instalar Zabbix Agent2

╔═══════════════════════════════════════════════════════════════════════════════╗
║                       💾  DISCO & BANCO DE DADOS                             ║
╚═══════════════════════════════════════════════════════════════════════════════╝
  7)  📈 Expandir Disco LVM  (sem reboot — NVMe · SCSI · virtio)
  8)  🗜️  Otimizar SQLite (VACUUM)
  9)  💾 Backup Agora

╔═══════════════════════════════════════════════════════════════════════════════╗
║                       🔧  MANUTENÇÃO                                         ║
╚═══════════════════════════════════════════════════════════════════════════════╝
  10) 🔄 Verificar Atualizações Zabbix
  11) ⚙️  Configurar Manutenção Automática
  12) 🧹 Limpeza de Sistema

╔═══════════════════════════════════════════════════════════════════════════════╗
║                       📊  SISTEMA                                            ║
╚═══════════════════════════════════════════════════════════════════════════════╝
  13) 📋 Informações Completas
  14) 🔍 Monitor em Tempo Real

╔═══════════════════════════════════════════════════════════════════════════════╗
║                       ⚙️   CONFIGURAÇÕES                                     ║
╚═══════════════════════════════════════════════════════════════════════════════╝
  15) 🛠️  Reconfigurar ZBX Swiss
  0)  🚪 Sair
```

---

## Uso via CLI (sem menu)

```bash
# Instalar Zabbix Proxy
sudo ./zbx-swiss.sh --install --server 192.168.1.10

# Instalar sem confirmações (automação)
sudo ./zbx-swiss.sh --install --server 192.168.1.10 --yes

# Verificar status
sudo ./zbx-swiss.sh --status

# Expandir disco LVM sem reboot
sudo ./zbx-swiss.sh --expand-disk

# Fazer backup agora
sudo ./zbx-swiss.sh --backup

# Reiniciar serviços
sudo ./zbx-swiss.sh --restart

# Simular instalação sem alterar nada
sudo ./zbx-swiss.sh --install --dry-run

# Alterar configuração salva
sudo ./zbx-swiss.sh --reconfigure
```

### Todas as opções

```
Ações diretas:
  --install           Instalar Zabbix Proxy
  --remove            Remover Zabbix Proxy
  --status            Exibir status e sair
  --expand-disk       Expandir disco LVM
  --backup            Executar backup agora
  --restart           Reiniciar serviços
  --reconfigure       Reconfigurar e salvar

Parâmetros:
  -v, --version X.Y           Versão do Zabbix  (padrão: 7.2)
  -s, --server IP             IP do servidor Zabbix
  -t, --timezone TZ           Fuso horário      (padrão: America/Sao_Paulo)
  -a, --agent / -N, --no-agent
      --agent-version 1|2     Versão do agente  (padrão: 2)
  -w, --webhook URL
  -W, --no-webhook
      --cache-size SIZE        CacheSize         (padrão: 128M)
      --pollers NUM            StartPollers      (padrão: 10)
      --timeout SEC            Timeout           (padrão: 30)
  -y, --yes                   Auto-confirmar tudo
      --dry-run                Simular sem alterar
  -h, --help                  Esta ajuda
```

---

## Expansão de Disco sem Reboot

O recurso mais importante: expandir o volume LVM **sem precisar reiniciar o servidor**.

Basta:
1. Expandir o disco no hypervisor (vSphere, Proxmox, Hyper-V, etc.)
2. Executar `sudo ./zbx-swiss.sh --expand-disk`
3. O script detecta o novo tamanho via sysfs, corrige o GPT se necessário, expande a partição e o LV, e redimensiona o filesystem — tudo online.

**Suporte:** SCSI (`sda`) · virtio-blk (`vda`) · virtio-scsi · NVMe (`nvme0n1`) · Xen (`xvda`)

---

## Configuração Persistente

As configurações são salvas em `/etc/zbx-swiss/config.conf` e recarregadas automaticamente:

```ini
# ZBX Swiss Manager — configuração
ZABBIX_VERSION="7.2"
SERVER_IP="192.168.1.10"
TIMEZONE="America/Sao_Paulo"
INSTALL_AGENT="true"
AGENT_VERSION="2"
CACHE_SIZE="128M"
START_POLLERS="10"
```

Para alterar: menu → opção 15, ou `sudo ./zbx-swiss.sh --reconfigure`.

---

## Apoie o projeto

Se este script te economizou tempo, considere um cafezinho! ☕

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/P5P21XLC5G)

---

## Contribuindo

1. Fork o repositório
2. Crie uma branch: `git checkout -b minha-melhoria`
3. Commit: `git commit -m 'Adiciona suporte a XYZ'`
4. Push: `git push origin minha-melhoria`
5. Abra um Pull Request

---

## Licença

MIT © [Seu Nome](https://github.com/SEU_USUARIO)
