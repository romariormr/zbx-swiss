#!/usr/bin/env bash
# ================================================================================
# ZBX Swiss Manager — Zabbix Proxy Swiss Army Knife
# ================================================================================
# Descrição: Ferramenta completa para instalação e gerenciamento do Zabbix Proxy
#            com suporte multi-distro, expansão de disco SEM reboot e
#            configurações persistentes entre execuções.
#
# Distribuições Suportadas:
#   Ubuntu 20.04 / 22.04 / 24.04
#   Debian 11 / 12
#   Oracle Linux 8 / 9  |  Rocky Linux 8 / 9
#   AlmaLinux 8 / 9     |  CentOS Stream 8 / 9
#
# Repositório: https://github.com/romariormr/zbx-swiss
# ================================================================================
set -euo pipefail

# ================================================================================
# VERSÃO
# ================================================================================
VERSION="7.0"
SCRIPT_NAME="ZBX Swiss Manager"
SCRIPT_FILE="$(realpath "$0")"
GITHUB_RAW_URL="https://raw.githubusercontent.com/romariormr/zbx-swiss/main/zbx-swiss.sh"

# ================================================================================
# CONFIGURAÇÃO PERSISTENTE
# ================================================================================
CONFIG_DIR="/etc/zbx-swiss"
CONFIG_FILE="$CONFIG_DIR/config.conf"

DEFAULT_ZABBIX_VERSION="7.2"
DEFAULT_SERVER_IP=""
DEFAULT_TIMEZONE="America/Sao_Paulo"
DEFAULT_INSTALL_AGENT=true
DEFAULT_AGENT_VERSION=2
DEFAULT_ZBX_CONF="/etc/zabbix/zabbix_proxy.conf"
DEFAULT_DB_FILE="/var/lib/zabbix/zabbix.db"
DEFAULT_WEBHOOK_URL=""
DEFAULT_SEND_WEBHOOK=false
DEFAULT_CACHE_SIZE="128M"
DEFAULT_START_POLLERS=10
DEFAULT_START_POLLERS_UNREACHABLE=3
DEFAULT_LOG_SLOW_QUERIES=3000
DEFAULT_DATA_SENDER_FREQUENCY=5
DEFAULT_PROXY_TIMEOUT=30
DEFAULT_LOG_FILE="/var/log/zbx-swiss.log"

ZABBIX_VERSION="$DEFAULT_ZABBIX_VERSION"
SERVER_IP="$DEFAULT_SERVER_IP"
TIMEZONE="$DEFAULT_TIMEZONE"
INSTALL_AGENT="$DEFAULT_INSTALL_AGENT"
AGENT_VERSION="$DEFAULT_AGENT_VERSION"
ZBX_CONF="$DEFAULT_ZBX_CONF"
DB_FILE="$DEFAULT_DB_FILE"
WEBHOOK_URL="$DEFAULT_WEBHOOK_URL"
SEND_WEBHOOK="$DEFAULT_SEND_WEBHOOK"
CACHE_SIZE="$DEFAULT_CACHE_SIZE"
START_POLLERS="$DEFAULT_START_POLLERS"
START_POLLERS_UNREACHABLE="$DEFAULT_START_POLLERS_UNREACHABLE"
LOG_SLOW_QUERIES="$DEFAULT_LOG_SLOW_QUERIES"
DATA_SENDER_FREQUENCY="$DEFAULT_DATA_SENDER_FREQUENCY"
PROXY_TIMEOUT="$DEFAULT_PROXY_TIMEOUT"
LOG_FILE="$DEFAULT_LOG_FILE"

AUTO_YES="${AUTO_YES:-false}"
DRY_RUN="${DRY_RUN:-false}"

OS_TYPE="" OS_VERSION="" OS_CODENAME="" PKG_MANAGER=""

# ================================================================================
# CORES
# ================================================================================
amarelo="\e[33m"; verde="\e[32m"; branco="\e[97m"; bege="\e[93m"
vermelho="\e[91m"; azul="\e[34m"; roxo="\e[35m"; ciano="\e[36m"
cinza="\e[90m"; reset="\e[0m"; bold="\e[1m"

# ================================================================================
# LOGGING
# ================================================================================
setup_logging() {
  [[ $EUID -ne 0 ]] && return
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo ""; echo "=== $SCRIPT_NAME v${VERSION} — $(date '+%Y-%m-%d %H:%M:%S') ==="
}

log_info()    { echo -e "${azul}ℹ${reset}  $*"; }
log_success() { echo -e "${verde}✓${reset}  $*"; }
log_warning() { echo -e "${amarelo}⚠${reset}  $*"; }
log_error()   { echo -e "${vermelho}✗${reset}  $*" >&2; }

# ================================================================================
# ERROS / CONFIRM / DRY-RUN
# ================================================================================
error_exit() { log_error "$1"; exit 1; }
trap '_on_err=$?; log_error "Erro na linha $LINENO (código $_on_err)"; exit $_on_err' ERR

confirm() {
  local prompt="${1:-Confirmar?}"
  [[ $AUTO_YES == true ]] && { log_info "$prompt → [S] (auto)"; return 0; }
  local r; read -rp "$(echo -e "${amarelo}${prompt} (S/N): ${reset}")" r
  [[ ${r:-N} =~ ^[Ss]$ ]]
}

run_cmd() {
  [[ $DRY_RUN == true ]] && { log_warning "[DRY-RUN] $*"; return 0; }
  "$@"
}

# ================================================================================
# CONFIGURAÇÃO PERSISTENTE
# ================================================================================
_CONFIG_VARS=(
  ZABBIX_VERSION SERVER_IP TIMEZONE
  INSTALL_AGENT AGENT_VERSION
  WEBHOOK_URL SEND_WEBHOOK
  CACHE_SIZE START_POLLERS START_POLLERS_UNREACHABLE
  LOG_SLOW_QUERIES DATA_SENDER_FREQUENCY PROXY_TIMEOUT
)

load_config() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  local key value line
  while IFS= read -r line; do
    [[ $line =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    if [[ $line =~ ^([A-Z_]+)=\"(.*)\"$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      case "$key" in
        ZABBIX_VERSION|SERVER_IP|TIMEZONE|INSTALL_AGENT|AGENT_VERSION|\
        WEBHOOK_URL|SEND_WEBHOOK|CACHE_SIZE|START_POLLERS|\
        START_POLLERS_UNREACHABLE|LOG_SLOW_QUERIES|\
        DATA_SENDER_FREQUENCY|PROXY_TIMEOUT)
          printf -v "$key" '%s' "$value" ;;
      esac
    fi
  done < "$CONFIG_FILE"
}

save_config() {
  mkdir -p "$CONFIG_DIR"
  {
    echo "# ZBX Swiss Manager — configuração"
    echo "# Salvo em: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    for var in "${_CONFIG_VARS[@]}"; do
      echo "${var}=\"${!var}\""
    done
  } > "$CONFIG_FILE"
  log_success "Configuração salva em $CONFIG_FILE"
}

first_run_wizard() {
  clear
  echo -e "${azul}${bold}"
  cat <<'BANNER'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║              ██████╗ ██████╗ ██╗  ██╗    ███████╗██╗    ██╗██╗███████╗       ║
║             ╚════██╗██╔══██╗╚██╗██╔╝    ██╔════╝██║    ██║██║██╔════╝       ║
║              █████╔╝██████╔╝ ╚███╔╝     ███████╗██║ █╗ ██║██║███████╗       ║
║             ██╔═══╝ ██╔══██╗ ██╔██╗     ╚════██║██║███╗██║██║╚════██║       ║
║             ███████╗██████╔╝██╔╝ ██╗    ███████║╚███╔███╔╝██║███████║       ║
║             ╚══════╝╚═════╝ ╚═╝  ╚═╝    ╚══════╝ ╚══╝╚══╝ ╚═╝╚══════╝       ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
BANNER
  echo -e "${reset}"
  echo -e "${branco}${bold}  Bem-vindo ao ZBX Swiss Manager v${VERSION}!${reset}"
  echo -e "${cinza}  Primeira execução detectada — vamos configurar o ambiente.${reset}"
  echo ""
  echo -e "${ciano}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  echo ""
  echo -e "${amarelo}${bold}⚙️  Configuração do Zabbix Proxy${reset}"; echo ""

  local _v
  read -rp "$(echo -e "  ${branco}Versão do Zabbix${reset} [${ZABBIX_VERSION}]: ")"    _v; ZABBIX_VERSION="${_v:-$ZABBIX_VERSION}"
  read -rp "$(echo -e "  ${branco}IP do servidor Zabbix${reset} [obrigatório]: ")"      _v
  while [[ -z "${_v}" && -z "${SERVER_IP}" ]]; do
    echo -e "  ${vermelho}O IP do servidor Zabbix é obrigatório.${reset}"
    read -rp "$(echo -e "  ${branco}IP do servidor Zabbix${reset}: ")" _v
  done
  [[ -n "$_v" ]] && SERVER_IP="$_v"
  read -rp "$(echo -e "  ${branco}Timezone${reset} [${TIMEZONE}]: ")" _v; TIMEZONE="${_v:-$TIMEZONE}"

  echo ""; echo -e "${amarelo}${bold}⚙️  Agente Zabbix${reset}"
  read -rp "$(echo -e "  ${branco}Instalar agente?${reset} (S/N) [S]: ")" _v
  [[ ${_v:-S} =~ ^[Nn]$ ]] && INSTALL_AGENT=false || INSTALL_AGENT=true
  if [[ $INSTALL_AGENT == true ]]; then
    read -rp "$(echo -e "  ${branco}Versão do agente${reset} (1/2) [${AGENT_VERSION}]: ")" _v
    AGENT_VERSION="${_v:-$AGENT_VERSION}"
  fi

  echo ""; echo -e "${amarelo}${bold}⚙️  Notificação Webhook (opcional)${reset}"
  read -rp "$(echo -e "  ${branco}Enviar webhook após instalar?${reset} (S/N) [N]: ")" _v
  if [[ ${_v:-N} =~ ^[Ss]$ ]]; then
    SEND_WEBHOOK=true
    read -rp "$(echo -e "  ${branco}URL do webhook${reset}: ")" _v; WEBHOOK_URL="${_v:-$WEBHOOK_URL}"
  else
    SEND_WEBHOOK=false
  fi

  echo ""; echo -e "${amarelo}${bold}⚙️  Parâmetros avançados${reset} ${cinza}(Enter para manter padrão)${reset}"
  read -rp "$(echo -e "  ${branco}CacheSize${reset} [${CACHE_SIZE}]: ")"                 _v; CACHE_SIZE="${_v:-$CACHE_SIZE}"
  read -rp "$(echo -e "  ${branco}StartPollers${reset} [${START_POLLERS}]: ")"            _v; START_POLLERS="${_v:-$START_POLLERS}"
  read -rp "$(echo -e "  ${branco}DataSenderFrequency (s)${reset} [${DATA_SENDER_FREQUENCY}]: ")" _v; DATA_SENDER_FREQUENCY="${_v:-$DATA_SENDER_FREQUENCY}"
  read -rp "$(echo -e "  ${branco}Timeout (s)${reset} [${PROXY_TIMEOUT}]: ")"             _v; PROXY_TIMEOUT="${_v:-$PROXY_TIMEOUT}"

  echo ""
  echo -e "${ciano}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  echo -e "${branco}  Resumo:${reset}  Zabbix ${verde}${ZABBIX_VERSION}${reset}  |  Server: ${verde}${SERVER_IP}${reset}  |  Timezone: ${verde}${TIMEZONE}${reset}"
  echo ""
  confirm "Salvar configuração e continuar?" || { log_info "Usando padrões."; return 0; }
  save_config; echo ""; log_success "Configuração salva! Altere quando quiser: menu → opção 19"; sleep 2
}

reconfigure() {
  print_header
  echo -e "${amarelo}${bold}═══════════════════════════════════════════════════════════════════════════════"
  echo -e "                      ⚙️   RECONFIGURAR ZBX SWISS                             "
  echo -e "═══════════════════════════════════════════════════════════════════════════════${reset}"; echo ""
  echo -e "${cinza}  Config atual: $CONFIG_FILE${reset}"; echo ""

  local _v
  read -rp "$(echo -e "  ${branco}Versão do Zabbix${reset} [${ZABBIX_VERSION}]: ")"    _v; ZABBIX_VERSION="${_v:-$ZABBIX_VERSION}"
  read -rp "$(echo -e "  ${branco}IP do servidor Zabbix${reset} [${SERVER_IP}]: ")"    _v; SERVER_IP="${_v:-$SERVER_IP}"
  read -rp "$(echo -e "  ${branco}Timezone${reset} [${TIMEZONE}]: ")"                  _v; TIMEZONE="${_v:-$TIMEZONE}"
  echo ""
  read -rp "$(echo -e "  ${branco}Instalar agente?${reset} (S/N) [$([ "$INSTALL_AGENT" = true ] && echo S || echo N)]: ")" _v
  [[ ${_v:-$([ "$INSTALL_AGENT" = true ] && echo S || echo N)} =~ ^[Nn]$ ]] && INSTALL_AGENT=false || INSTALL_AGENT=true
  if [[ $INSTALL_AGENT == true ]]; then
    read -rp "$(echo -e "  ${branco}Versão do agente${reset} (1/2) [${AGENT_VERSION}]: ")" _v; AGENT_VERSION="${_v:-$AGENT_VERSION}"
  fi
  echo ""
  read -rp "$(echo -e "  ${branco}Enviar webhook?${reset} (S/N) [$([ "$SEND_WEBHOOK" = true ] && echo S || echo N)]: ")" _v
  if [[ ${_v:-N} =~ ^[Ss]$ ]]; then
    SEND_WEBHOOK=true; read -rp "$(echo -e "  ${branco}URL do webhook${reset} [${WEBHOOK_URL}]: ")" _v; WEBHOOK_URL="${_v:-$WEBHOOK_URL}"
  else
    SEND_WEBHOOK=false
  fi
  echo ""
  read -rp "$(echo -e "  ${branco}CacheSize${reset} [${CACHE_SIZE}]: ")"                 _v; CACHE_SIZE="${_v:-$CACHE_SIZE}"
  read -rp "$(echo -e "  ${branco}StartPollers${reset} [${START_POLLERS}]: ")"            _v; START_POLLERS="${_v:-$START_POLLERS}"
  read -rp "$(echo -e "  ${branco}DataSenderFrequency${reset} [${DATA_SENDER_FREQUENCY}]: ")" _v; DATA_SENDER_FREQUENCY="${_v:-$DATA_SENDER_FREQUENCY}"
  read -rp "$(echo -e "  ${branco}Timeout${reset} [${PROXY_TIMEOUT}]: ")"                 _v; PROXY_TIMEOUT="${_v:-$PROXY_TIMEOUT}"
  echo ""
  confirm "Salvar alterações?" && save_config || log_info "Alterações descartadas"
}

# ================================================================================
# AJUDA
# ================================================================================
show_help() {
  cat <<HELP
$(echo -e "${branco}${bold}${SCRIPT_NAME} v${VERSION}${reset}")

$(echo -e "${bold}Uso:${reset}") $0 [opções]

$(echo -e "${amarelo}${bold}Ações diretas:${reset}")
  --install           Instalar Zabbix Proxy
  --remove            Remover Zabbix Proxy
  --status            Exibir status e sair
  --health-check      Diagnóstico completo
  --expand-disk       Expandir disco LVM
  --backup            Executar backup agora
  --restore           Restaurar backup
  --tls-psk           Configurar TLS/PSK
  --restart           Reiniciar serviços
  --diagnose          Exportar relatório de diagnóstico
  --reconfigure       Reconfigurar e salvar
  --self-update       Atualizar o ZBX Swiss

$(echo -e "${amarelo}${bold}Parâmetros:${reset}")
  -v, --version X.Y           Versão do Zabbix         (padrão: $DEFAULT_ZABBIX_VERSION)
  -s, --server IP             IP do servidor Zabbix
  -t, --timezone TZ           Fuso horário              (padrão: $DEFAULT_TIMEZONE)
  -a, --agent / -N, --no-agent
      --agent-version 1|2     Versão do agente          (padrão: 2)
  -w, --webhook URL
  -W, --no-webhook
      --cache-size SIZE        CacheSize                 (padrão: $DEFAULT_CACHE_SIZE)
      --pollers NUM            StartPollers              (padrão: $DEFAULT_START_POLLERS)
      --timeout SEC            Timeout                   (padrão: $DEFAULT_PROXY_TIMEOUT)
      --log-file PATH          Arquivo de log
  -y, --yes                   Auto-confirmar tudo
      --dry-run                Simular sem alterar
  -h, --help                  Esta ajuda

$(echo -e "${amarelo}${bold}Exemplos:${reset}")
  $0                              # menu interativo
  $0 --install --yes              # instalação silenciosa
  $0 --health-check               # diagnóstico completo
  $0 --expand-disk                # expandir disco sem reboot
  $0 --self-update                # atualizar o script
HELP
  exit 0
}

# ================================================================================
# PARSER DE ARGUMENTOS
# ================================================================================
DIRECT_ACTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)            DIRECT_ACTION="install";      shift ;;
    --remove)             DIRECT_ACTION="remove";       shift ;;
    --status)             DIRECT_ACTION="status";       shift ;;
    --health-check)       DIRECT_ACTION="health";       shift ;;
    --expand-disk)        DIRECT_ACTION="expand";       shift ;;
    --backup)             DIRECT_ACTION="backup";       shift ;;
    --restore)            DIRECT_ACTION="restore";      shift ;;
    --tls-psk)            DIRECT_ACTION="tls";          shift ;;
    --restart)            DIRECT_ACTION="restart";      shift ;;
    --diagnose)           DIRECT_ACTION="diagnose";     shift ;;
    --reconfigure)        DIRECT_ACTION="reconf";       shift ;;
    --self-update)        DIRECT_ACTION="selfupdate";   shift ;;
    -v|--version)         ZABBIX_VERSION="$2";          shift 2 ;;
    -s|--server)          SERVER_IP="$2";               shift 2 ;;
    -t|--timezone)        TIMEZONE="$2";                shift 2 ;;
    -a|--agent)           INSTALL_AGENT=true;           shift ;;
    -N|--no-agent)        INSTALL_AGENT=false;          shift ;;
    --agent-version)      AGENT_VERSION="$2";           shift 2 ;;
    -w|--webhook)         WEBHOOK_URL="$2"; SEND_WEBHOOK=true; shift 2 ;;
    -W|--no-webhook)      SEND_WEBHOOK=false;           shift ;;
    --cache-size)         CACHE_SIZE="$2";              shift 2 ;;
    --pollers)            START_POLLERS="$2";           shift 2 ;;
    --unreachable-pollers) START_POLLERS_UNREACHABLE="$2"; shift 2 ;;
    --slow-queries)       LOG_SLOW_QUERIES="$2";        shift 2 ;;
    --data-sender-frequency) DATA_SENDER_FREQUENCY="$2"; shift 2 ;;
    --timeout)            PROXY_TIMEOUT="$2";           shift 2 ;;
    --log-file)           LOG_FILE="$2";                shift 2 ;;
    -y|--yes)             AUTO_YES=true;                shift ;;
    --dry-run)            DRY_RUN=true;                 shift ;;
    -h|--help)            show_help ;;
    *) log_error "Opção desconhecida: $1"; show_help ;;
  esac
done

[[ ! $ZABBIX_VERSION =~ ^[0-9]+\.[0-9]+$ ]] \
  && error_exit "Versão inválida: '$ZABBIX_VERSION'. Use X.Y (ex: 7.2)"

# ================================================================================
# DETECÇÃO DE SO
# ================================================================================
check_root() { [[ $EUID -eq 0 ]] || error_exit "Execute como root (sudo $0)"; }

detect_os() {
  log_info "Detectando sistema operacional..."
  if   [[ -f /etc/oracle-release    ]]; then OS_TYPE="oracle"; OS_VERSION=$(grep -oP '\d+' /etc/oracle-release    | head -1); PKG_MANAGER="dnf"
  elif [[ -f /etc/rocky-release     ]]; then OS_TYPE="rocky";  OS_VERSION=$(grep -oP '\d+' /etc/rocky-release     | head -1); PKG_MANAGER="dnf"
  elif [[ -f /etc/almalinux-release ]]; then OS_TYPE="alma";   OS_VERSION=$(grep -oP '\d+' /etc/almalinux-release | head -1); PKG_MANAGER="dnf"
  elif [[ -f /etc/centos-release    ]]; then OS_TYPE="centos"; OS_VERSION=$(grep -oP '\d+' /etc/centos-release    | head -1); PKG_MANAGER="dnf"
  elif [[ -f /etc/debian_version    ]]; then
    PKG_MANAGER="apt"
    if [[ -f /etc/lsb-release ]]; then
      source /etc/lsb-release
      OS_TYPE="ubuntu"; OS_VERSION="$DISTRIB_RELEASE"; OS_CODENAME="$DISTRIB_CODENAME"
    else
      OS_TYPE="debian"; OS_VERSION=$(cut -d. -f1 /etc/debian_version)
      case $OS_VERSION in 11) OS_CODENAME="bullseye";; 12) OS_CODENAME="bookworm";; *) OS_CODENAME="unknown";; esac
    fi
  else
    error_exit "SO não suportado."
  fi

  case $OS_TYPE in
    ubuntu)                [[ "$OS_VERSION" =~ ^(20\.04|22\.04|24\.04)$ ]] || error_exit "Ubuntu $OS_VERSION não suportado" ;;
    debian)                [[ "$OS_VERSION" =~ ^(11|12)$                ]] || error_exit "Debian $OS_VERSION não suportado" ;;
    oracle|rocky|alma|centos) [[ "$OS_VERSION" =~ ^(8|9)$              ]] || error_exit "$OS_TYPE $OS_VERSION não suportado" ;;
  esac
  log_success "$OS_TYPE $OS_VERSION detectado"
}

pkg_update()  { case $PKG_MANAGER in apt) apt-get update -qq;; dnf) dnf makecache -q;; esac; }
pkg_install() { case $PKG_MANAGER in apt) DEBIAN_FRONTEND=noninteractive apt-get install -qqy "$@";; dnf) dnf install -y -q "$@";; esac; }
pkg_remove()  {
  case $PKG_MANAGER in
    apt) DEBIAN_FRONTEND=noninteractive apt-get purge -y "$@"; apt-get autoremove -y;;
    dnf) dnf remove -y -q "$@"; dnf autoremove -y -q;;
  esac
}

# ================================================================================
# INTERFACE VISUAL
# ================================================================================
_print_status_bar() {
  local zbx_status zbx_ver disk_pct ram_pct
  if command -v zabbix_proxy &>/dev/null; then
    if systemctl is-active --quiet zabbix-proxy 2>/dev/null; then
      zbx_status="${verde}● Ativo${reset}"
    else
      zbx_status="${vermelho}● Inativo${reset}"
    fi
    zbx_ver=$(zabbix_proxy -V 2>/dev/null | awk '{print $3}' | head -1 || echo "?")
  else
    zbx_status="${cinza}● Não instalado${reset}"; zbx_ver="—"
  fi
  disk_pct=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,""); print $5}')
  ram_pct=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $3*100/$2}')

  echo -e "${cinza}┌──────────────────────────────────────────────────────────────────────────────┐${reset}"
  echo -e "${cinza}│${reset}  ${branco}Proxy:${reset} ${zbx_status} ${cinza}(v${zbx_ver})${reset}   ${cinza}│${reset}   ${branco}Disco:${reset} ${verde}${disk_pct}%${reset}   ${cinza}│${reset}   ${branco}RAM:${reset} ${verde}${ram_pct}%${reset}   ${cinza}│${reset}   ${verde}🔒 root${reset}"
  echo -e "${cinza}└──────────────────────────────────────────────────────────────────────────────┘${reset}"; echo ""
}

print_header() {
  clear
  echo -e "${azul}${bold}"
  cat <<'BANNER'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║              ██████╗ ██████╗ ██╗  ██╗    ███████╗██╗    ██╗██╗███████╗       ║
║             ╚════██╗██╔══██╗╚██╗██╔╝    ██╔════╝██║    ██║██║██╔════╝       ║
║              █████╔╝██████╔╝ ╚███╔╝     ███████╗██║ █╗ ██║██║███████╗       ║
║             ██╔═══╝ ██╔══██╗ ██╔██╗     ╚════██║██║███╗██║██║╚════██║       ║
║             ███████╗██████╔╝██╔╝ ██╗    ███████║╚███╔███╔╝██║███████║       ║
║             ╚══════╝╚═════╝ ╚═╝  ╚═╝    ╚══════╝ ╚══╝╚══╝ ╚═╝╚══════╝       ║
║                                                                               ║
BANNER
  echo -e "║${reset}                   ${branco}${bold}ZBX Swiss Manager v${VERSION}${reset}                              ${azul}${bold}║"
  echo -e "║${reset}           ${cinza}Canivete suíço para Zabbix Proxy — Multi-distro${reset}                ${azul}${bold}║"
  echo -e "╚═══════════════════════════════════════════════════════════════════════════════╝${reset}"; echo ""
  _print_status_bar
}

show_main_menu() {
  print_header

  echo -e "${verde}${bold}╔═══════════════════════════════════════════════════════════════════════════════╗"
  echo -e "║                       🔧  ZABBIX PROXY                                       ║"
  echo -e "╚═══════════════════════════════════════════════════════════════════════════════╝${reset}"
  echo -e "  ${branco}1)${reset}  📦 ${verde}Instalar Zabbix Proxy${reset}"
  echo -e "  ${branco}2)${reset}  🗑️  ${vermelho}Remover Zabbix Proxy${reset}"
  echo -e "  ${branco}3)${reset}  📊 ${amarelo}Status dos Serviços${reset}"
  echo -e "  ${branco}4)${reset}  🔁 ${ciano}Reiniciar Serviços${reset}"
  echo -e "  ${branco}5)${reset}  📜 ${cinza}Ver Logs ao Vivo${reset}"
  echo -e "  ${branco}6)${reset}  📡 ${azul}Instalar Zabbix Agent2${reset}"
  echo -e "  ${branco}7)${reset}  🩺 ${verde}Health Check Completo${reset}"
  echo ""

  echo -e "${azul}${bold}╔═══════════════════════════════════════════════════════════════════════════════╗"
  echo -e "║                       💾  DISCO & BANCO DE DADOS                             ║"
  echo -e "╚═══════════════════════════════════════════════════════════════════════════════╝${reset}"
  echo -e "  ${branco}8)${reset}  📈 ${azul}Expandir Disco LVM${reset} ${verde}(sem reboot — NVMe · SCSI · virtio)${reset}"
  echo -e "  ${branco}9)${reset}  🗜️  ${ciano}Otimizar SQLite (VACUUM)${reset}"
  echo -e "  ${branco}10)${reset} 💾 ${verde}Backup Agora${reset}"
  echo -e "  ${branco}11)${reset} ♻️  ${amarelo}Restaurar Backup${reset}"
  echo ""

  echo -e "${vermelho}${bold}╔═══════════════════════════════════════════════════════════════════════════════╗"
  echo -e "║                       🔒  SEGURANÇA                                          ║"
  echo -e "╚═══════════════════════════════════════════════════════════════════════════════╝${reset}"
  echo -e "  ${branco}12)${reset} 🔐 ${vermelho}Configurar TLS/PSK${reset}"
  echo ""

  echo -e "${roxo}${bold}╔═══════════════════════════════════════════════════════════════════════════════╗"
  echo -e "║                       🔧  MANUTENÇÃO                                         ║"
  echo -e "╚═══════════════════════════════════════════════════════════════════════════════╝${reset}"
  echo -e "  ${branco}13)${reset} 🔄 ${roxo}Verificar Atualizações Zabbix${reset}"
  echo -e "  ${branco}14)${reset} ⚙️  ${bege}Configurar Manutenção Automática${reset}"
  echo -e "  ${branco}15)${reset} 🧹 ${ciano}Limpeza de Sistema${reset}"
  echo ""

  echo -e "${amarelo}${bold}╔═══════════════════════════════════════════════════════════════════════════════╗"
  echo -e "║                       📊  SISTEMA                                            ║"
  echo -e "╚═══════════════════════════════════════════════════════════════════════════════╝${reset}"
  echo -e "  ${branco}16)${reset} 📋 ${verde}Informações Completas${reset}"
  echo -e "  ${branco}17)${reset} 🔍 ${azul}Monitor em Tempo Real${reset}"
  echo -e "  ${branco}18)${reset} 📄 ${cinza}Exportar Diagnóstico${reset}"
  echo ""

  echo -e "${cinza}${bold}╔═══════════════════════════════════════════════════════════════════════════════╗"
  echo -e "║                       ⚙️   CONFIGURAÇÕES                                     ║"
  echo -e "╚═══════════════════════════════════════════════════════════════════════════════╝${reset}"
  echo -e "  ${branco}19)${reset} 🛠️  ${bege}Reconfigurar ZBX Swiss${reset} ${cinza}(Server IP, Timezone, Webhook...)${reset}"
  echo -e "  ${branco}20)${reset} ⬆️  ${verde}Atualizar ZBX Swiss${reset} ${cinza}(busca versão mais recente no GitHub)${reset}"
  echo -e "  ${branco}0)${reset}  🚪 ${cinza}Sair${reset}"
  echo ""

  echo -e "${ciano}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  echo -e "  ${cinza}Config: $CONFIG_FILE${reset}  ${cinza}|${reset}  ${cinza}Log: $LOG_FILE${reset}"
  echo -e "${ciano}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"; echo ""
}

pause_prompt() {
  echo ""
  echo -e "${ciano}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  [[ $AUTO_YES == true ]] && return
  read -rp "$(echo -e "${amarelo}  Pressione ${verde}[ENTER]${amarelo} para voltar ao menu...${reset}")"
}

# ================================================================================
# CONECTIVIDADE
# ================================================================================
check_connectivity() {
  log_info "Verificando acesso ao repo.zabbix.com..."
  curl -sf --max-time 10 "https://repo.zabbix.com" -o /dev/null \
    || error_exit "Sem acesso a repo.zabbix.com. Verifique a conexão."
  log_success "Conectividade OK"
}

connectivity_check_server() {
  [[ -z "$SERVER_IP" ]] && { log_warning "SERVER_IP não configurado — pulando teste"; return 0; }
  log_info "Testando conexão com $SERVER_IP:10051..."
  if bash -c "echo >/dev/tcp/$SERVER_IP/10051" 2>/dev/null; then
    log_success "Porta 10051 acessível em $SERVER_IP"
    return 0
  else
    log_error "Porta 10051 INACESSÍVEL em $SERVER_IP"
    log_warning "Verifique: firewall no servidor Zabbix, IP correto, serviço rodando"
    return 1
  fi
}

# ================================================================================
# INSTALAÇÃO
# ================================================================================
configure_timezone() {
  log_info "Configurando timezone: $TIMEZONE..."
  run_cmd timedatectl set-timezone "$TIMEZONE" || error_exit "Timezone inválido: $TIMEZONE"
  log_success "Timezone configurado"
}

add_zabbix_repo() {
  log_info "Adicionando repositório Zabbix $ZABBIX_VERSION..."
  case $PKG_MANAGER in
    apt)
      local pkg="zabbix-release_latest_${ZABBIX_VERSION}+${OS_TYPE}${OS_VERSION}_all.deb"
      local url="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/${OS_TYPE}/pool/main/z/zabbix-release/${pkg}"
      if [[ $DRY_RUN == false ]]; then
        wget -q --show-progress "$url" -O "/tmp/${pkg}" || error_exit "Falha ao baixar $pkg"
        dpkg -i "/tmp/${pkg}" &>/dev/null || error_exit "Falha ao instalar repositório"
      fi; pkg_update ;;
    dnf)
      run_cmd dnf install -y \
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/el/${OS_VERSION}/x86_64/zabbix-release-latest-${OS_VERSION}.noarch.rpm" \
        || error_exit "Falha ao instalar repositório RPM"
      pkg_update ;;
  esac
  log_success "Repositório adicionado"
}

install_dependencies() {
  log_info "Instalando dependências..."
  case $PKG_MANAGER in
    apt) run_cmd pkg_install wget gnupg sqlite3 zabbix-proxy-sqlite3 zabbix-sql-scripts ;;
    dnf) run_cmd pkg_install wget sqlite zabbix-proxy-sqlite3 zabbix-sql-scripts ;;
  esac
  log_success "Dependências instaladas"
}

import_schema() {
  log_info "Verificando schema SQLite..."
  if [[ -s "$DB_FILE" ]] && command -v sqlite3 &>/dev/null; then
    local cnt
    cnt=$(sqlite3 "$DB_FILE" \
      "SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null || echo "0")
    (( cnt > 0 )) && { log_success "Schema já existe ($cnt tabelas)"; return; }
  fi
  local schema
  schema=$(find /usr/share/zabbix-sql-scripts -name "proxy.sql*" 2>/dev/null | head -1 || true)
  [[ -n "$schema" ]] || error_exit "Schema SQLite não encontrado"
  run_cmd mkdir -p "$(dirname "$DB_FILE")"
  run_cmd chown zabbix:zabbix "$(dirname "$DB_FILE")"
  if [[ $DRY_RUN == false ]]; then
    if [[ "$schema" == *.gz ]]; then
      zcat "$schema" | sudo -u zabbix sqlite3 "$DB_FILE" || error_exit "Falha ao importar schema"
    else
      sudo -u zabbix sqlite3 "$DB_FILE" < "$schema" || error_exit "Falha ao importar schema"
    fi
    chown zabbix:zabbix "$DB_FILE"; chmod 640 "$DB_FILE"
  fi
  log_success "Schema importado"
}

configure_proxy() {
  log_info "Gerando zabbix_proxy.conf..."
  run_cmd mkdir -p "$(dirname "$ZBX_CONF")"
  [[ -f "$ZBX_CONF" ]] && run_cmd cp "$ZBX_CONF" "${ZBX_CONF}.bak-$(date +%F_%T)"

  local managed=(ProxyMode Server AllowedHosts Hostname DBName LogFile PidFile SocketDir
    LogFileSize EnableRemoteCommands LogSlowQueries ProxyOfflineBuffer
    ProxyConfigFrequency DataSenderFrequency StartPollers StartPollersUnreachable
    StartTrappers StartPingers StartDiscoverers CacheSize Timeout LogType DebugLevel
    SNMPTrapperFile ProxyBufferMode ProxyMemoryBufferSize StatsAllowedIP)

  local tmp; tmp=$(mktemp)
  if [[ -f "$ZBX_CONF" ]]; then
    grep -v -E "^($(IFS=\|; echo "${managed[*]}"))=.*" "$ZBX_CONF" \
      | grep -v -E "^# ?($(IFS=\|; echo "${managed[*]}"))=.*" > "$tmp" || true
  fi

  if [[ $DRY_RUN == false ]]; then
    cat > "$ZBX_CONF" <<EOF
# Zabbix Proxy — ${SCRIPT_NAME} v${VERSION}
# Gerado: $(date '+%Y-%m-%d %H:%M:%S')
ProxyMode=0
Server=$SERVER_IP
AllowedHosts=$SERVER_IP
Hostname=$(hostname)
DBName=$DB_FILE
LogFile=/var/log/zabbix/zabbix_proxy.log
PidFile=/var/run/zabbix/zabbix_proxy.pid
SocketDir=/var/run/zabbix
LogFileSize=0
EnableRemoteCommands=1
LogSlowQueries=$LOG_SLOW_QUERIES
ProxyOfflineBuffer=240
ProxyConfigFrequency=300
DataSenderFrequency=$DATA_SENDER_FREQUENCY
StartPollers=$START_POLLERS
StartPollersUnreachable=$START_POLLERS_UNREACHABLE
StartTrappers=5
StartPingers=1
StartDiscoverers=5
CacheSize=$CACHE_SIZE
Timeout=$PROXY_TIMEOUT
LogType=file
DebugLevel=3
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
ProxyBufferMode=hybrid
ProxyMemoryBufferSize=16M
StatsAllowedIP=127.0.0.1

EOF
    cat "$tmp" >> "$ZBX_CONF"
    chown zabbix:zabbix "$ZBX_CONF"; chmod 640 "$ZBX_CONF"
  fi
  rm -f "$tmp"
  log_success "Configuração gerada"
}

_validate_config() {
  [[ -f /usr/sbin/zabbix_proxy ]] || return 0
  [[ $DRY_RUN == true ]] && return 0
  local code=0
  local out; out=$(/usr/sbin/zabbix_proxy -T -c "$ZBX_CONF" 2>&1) || code=$?
  if [[ $code -ne 0 ]]; then
    log_error "Configuração inválida:"
    echo "$out" | grep -v "ConfigFrequency" | grep -v "^$" >&2
    error_exit "Corrija $ZBX_CONF"
  fi
  log_success "Configuração válida"
}

start_services() {
  log_info "Iniciando zabbix-proxy..."
  run_cmd mkdir -p /var/log/zabbix /var/run/zabbix
  run_cmd chown zabbix:zabbix /var/log/zabbix /var/run/zabbix
  _validate_config
  if [[ $DRY_RUN == false ]]; then
    systemctl restart zabbix-proxy 2>/dev/null || true
    systemctl enable --now zabbix-proxy || {
      journalctl -u zabbix-proxy -n 20 --no-pager
      error_exit "Falha ao iniciar zabbix-proxy"
    }
  fi
  log_success "Serviço ativo"
}

send_webhook() {
  [[ $SEND_WEBHOOK == true && $DRY_RUN == false ]] || return 0
  local pub; pub=$(curl -sf --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
  local payload="{\"status\":\"success\",\"host\":\"$(hostname)\",\"ip_public\":\"$pub\",\"os\":\"$OS_TYPE $OS_VERSION\",\"zabbix\":\"$ZABBIX_VERSION\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
  curl -sf --max-time 10 -X POST -H "Content-Type: application/json" \
    -d "$payload" "$WEBHOOK_URL" &>/dev/null \
    && log_success "Webhook enviado" \
    || log_warning "Falha ao enviar webhook para $WEBHOOK_URL"
}

_install_agent1() {
  log_info "Instalando Zabbix Agent v1..."
  run_cmd pkg_install zabbix-agent || return 1
  local conf="/etc/zabbix/zabbix_agentd.conf"
  local r=5; while [[ ! -f "$conf" && $r -gt 0 ]]; do sleep 2; (( r-- )); done
  [[ -f "$conf" ]] || { log_warning "Arquivo do agente não criado"; return 1; }
  sed -i "s|^Server=.*|Server=127.0.0.1|; s|^ServerActive=.*|ServerActive=127.0.0.1|" "$conf"
  run_cmd systemctl enable --now zabbix-agent
  log_success "Agent v1 configurado"
}

_install_agent2() {
  log_info "Instalando Zabbix Agent2..."
  run_cmd pkg_install zabbix-agent2 || return 1
  local conf="/etc/zabbix/zabbix_agent2.conf"
  [[ -f "$conf" ]] && cp "$conf" "${conf}.bak-$(date +%F_%T)"
  local managed=(Include AllowKey Plugins.SystemRun.LogRemoteCommands Server ServerActive
                 Hostname HostnameItem HostMetadata Timeout LogFile LogFileSize
                 PidFile ControlSocket PluginSocket)
  local tmp; tmp=$(mktemp)
  grep -v -E "^($(IFS=\|; echo "${managed[*]}"))=" "$conf" > "$tmp" 2>/dev/null || true
  if [[ $DRY_RUN == false ]]; then
    cat > "$conf" <<EOF
# Zabbix Agent2 — ${SCRIPT_NAME} v${VERSION}
Include=/etc/zabbix/zabbix_agent2.d/*.conf
AllowKey=system.run[*]
Plugins.SystemRun.LogRemoteCommands=1
Server=$SERVER_IP
ServerActive=$SERVER_IP
HostnameItem=system.hostname
Timeout=$PROXY_TIMEOUT
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0
PidFile=/run/zabbix/zabbix_agent2.pid
ControlSocket=/run/zabbix/agent.sock
PluginSocket=/run/zabbix/agent.plugin.sock

EOF
    cat "$tmp" >> "$conf"
    run_cmd systemctl enable --now zabbix-agent2
  fi
  rm -f "$tmp"; log_success "Agent2 configurado"
}

install_agent() { [[ "$AGENT_VERSION" == "2" ]] && _install_agent2 || _install_agent1; }

install_zabbix_proxy() {
  print_header
  echo -e "${verde}${bold}═══ 📦 INSTALAÇÃO DO ZABBIX PROXY ═══════════════════════════════════════════${reset}"; echo ""
  echo -e "  ${branco}Server:${reset}  ${verde}$SERVER_IP${reset}   ${branco}Zabbix:${reset} ${verde}v$ZABBIX_VERSION${reset}   ${branco}Agente:${reset} ${verde}$([ "$INSTALL_AGENT" = true ] && echo "v$AGENT_VERSION" || echo "Não")${reset}"; echo ""
  confirm "Iniciar instalação?" || return
  echo ""
  check_connectivity
  configure_timezone
  add_zabbix_repo
  install_dependencies
  import_schema
  configure_proxy
  start_services
  [[ $INSTALL_AGENT == true ]] && install_agent || true
  echo ""; log_info "Verificando conectividade com o servidor Zabbix..."
  connectivity_check_server || log_warning "Verifique a conectividade com $SERVER_IP antes de ativar o proxy no servidor"
  send_webhook
  echo ""; log_success "Instalação concluída!"; echo ""
  check_status_inline
}

# ================================================================================
# REMOÇÃO
# ================================================================================
remove_zabbix() {
  print_header
  echo -e "${vermelho}${bold}═══ 🗑️  REMOÇÃO DO ZABBIX PROXY ════════════════════════════════════════════${reset}"; echo ""
  echo -e "${amarelo}${bold}⚠️  IRREVERSÍVEL: pacotes · config · banco · logs serão removidos${reset}"; echo ""
  local r; read -rp "$(echo -e "${vermelho}Digite ${bold}SIM${reset}${vermelho} para confirmar: ${reset}")" r
  [[ "$r" == "SIM" ]] || { log_info "Cancelado."; return; }
  systemctl stop zabbix-proxy zabbix-agent zabbix-agent2 2>/dev/null || true
  systemctl disable zabbix-proxy zabbix-agent zabbix-agent2 2>/dev/null || true
  case $PKG_MANAGER in
    apt) pkg_remove zabbix-proxy-sqlite3 zabbix-proxy-mysql zabbix-proxy-pgsql \
                    zabbix-agent zabbix-agent2 zabbix-sql-scripts zabbix-release 2>/dev/null || true ;;
    dnf) pkg_remove zabbix-proxy-sqlite3 zabbix-agent zabbix-agent2 \
                    zabbix-sql-scripts zabbix-release 2>/dev/null || true ;;
  esac
  rm -rf /etc/zabbix /var/lib/zabbix /var/log/zabbix /usr/share/zabbix 2>/dev/null || true
  rm -f /etc/logrotate.d/zabbix-proxy /usr/local/sbin/zabbix-backup.sh 2>/dev/null || true
  log_success "Zabbix removido com sucesso!"
}

# ================================================================================
# STATUS E LOGS
# ================================================================================
check_status_inline() {
  echo -e "${amarelo}${bold}═══ 📊 STATUS ═══════════════════════════════════════════════════════════════${reset}"; echo ""
  if ! command -v zabbix_proxy &>/dev/null; then log_error "Zabbix Proxy não instalado"; return; fi
  systemctl is-active --quiet zabbix-proxy 2>/dev/null \
    && log_success "zabbix-proxy: ${verde}Ativo${reset}" \
    || log_error   "zabbix-proxy: ${vermelho}Inativo${reset}"
  for svc in zabbix-agent2 zabbix-agent; do
    systemctl is-active --quiet "$svc" 2>/dev/null \
      && { log_success "${svc}: ${verde}Ativo${reset}"; break; } || true
  done
  log_info "Versão: $(zabbix_proxy -V 2>/dev/null | head -1 || echo N/A)"
  [[ -f "$ZBX_CONF" ]] && log_success "Config: $ZBX_CONF" || log_error "Config não encontrada"
  [[ -f "$DB_FILE"  ]] && log_success "Banco: $DB_FILE ($(du -h "$DB_FILE" | cut -f1))" \
                        || log_error   "Banco não encontrado"
  echo ""; log_info "Logs recentes:"
  journalctl -u zabbix-proxy -n 8 --no-pager 2>/dev/null || true
}

check_status() { print_header; check_status_inline; }

view_logs() {
  print_header
  echo -e "${cinza}${bold}═══ 📜 LOGS AO VIVO ═══════════════════════════════════════════════════════${reset}"
  echo -e "${amarelo}  Pressione ${vermelho}CTRL+C${amarelo} para sair${reset}"; echo ""
  journalctl -u zabbix-proxy -f --no-pager 2>/dev/null \
    || { log_warning "journalctl não disponível — exibindo arquivo de log:"
         tail -f /var/log/zabbix/zabbix_proxy.log 2>/dev/null || log_error "Log não encontrado"; }
}

# ================================================================================
# REINICIAR SERVIÇOS
# ================================================================================
restart_services() {
  print_header
  echo -e "${ciano}${bold}═══ 🔁 REINICIAR SERVIÇOS ══════════════════════════════════════════════════${reset}"; echo ""
  confirm "Reiniciar zabbix-proxy e agentes?" || return
  for svc in zabbix-proxy zabbix-agent2 zabbix-agent; do
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
      systemctl restart "$svc" 2>/dev/null \
        && log_success "$svc reiniciado" \
        || log_warning "$svc falhou ao reiniciar"
    fi
  done
  echo ""; check_status_inline
}

# ================================================================================
# HEALTH CHECK COMPLETO
# ================================================================================
health_check() {
  print_header
  echo -e "${verde}${bold}═══ 🩺 HEALTH CHECK COMPLETO ═══════════════════════════════════════════════${reset}"; echo ""

  local score=0 total=0

  _hc() {
    local label="$1" ok="$2" detail="${3:-}"
    (( total++ ))
    if [[ "$ok" == "true" ]]; then
      (( score++ ))
      echo -e "  ${verde}✓${reset}  ${branco}$label${reset}${detail:+  ${cinza}($detail)${reset}}"
    else
      echo -e "  ${vermelho}✗${reset}  ${branco}$label${reset}${detail:+  ${cinza}($detail)${reset}}"
    fi
  }

  echo -e "${azul}${bold}  ── Zabbix Proxy ────────────────────────────────────────────────────────────${reset}"

  # 1. Instalado
  if command -v zabbix_proxy &>/dev/null; then
    _hc "Zabbix Proxy instalado" true "$(zabbix_proxy -V 2>/dev/null | head -1 | awk '{print $3}')"
  else
    _hc "Zabbix Proxy instalado" false "não encontrado"
  fi

  # 2. Serviço ativo
  systemctl is-active --quiet zabbix-proxy 2>/dev/null \
    && _hc "Serviço ativo" true \
    || _hc "Serviço ativo" false "execute: systemctl start zabbix-proxy"

  # 3. Config válida
  if [[ -f /usr/sbin/zabbix_proxy && -f "$ZBX_CONF" ]]; then
    /usr/sbin/zabbix_proxy -T -c "$ZBX_CONF" &>/dev/null \
      && _hc "Configuração válida" true "$ZBX_CONF" \
      || _hc "Configuração válida" false "erro em $ZBX_CONF"
  else
    _hc "Configuração válida" false "arquivo não encontrado"
  fi

  # 4. Banco de dados
  if [[ -f "$DB_FILE" ]]; then
    local integrity; integrity=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;" 2>/dev/null | head -1)
    [[ "$integrity" == "ok" ]] \
      && _hc "Banco SQLite íntegro" true "$(du -h "$DB_FILE" | cut -f1)" \
      || _hc "Banco SQLite íntegro" false "$integrity"
  else
    _hc "Banco SQLite íntegro" false "não encontrado em $DB_FILE"
  fi

  echo ""
  echo -e "${azul}${bold}  ── Rede & Conectividade ────────────────────────────────────────────────────${reset}"

  # 5. Conectividade com servidor Zabbix
  if [[ -n "$SERVER_IP" ]]; then
    bash -c "echo >/dev/tcp/$SERVER_IP/10051" 2>/dev/null \
      && _hc "Conectividade Proxy→Server (10051)" true "$SERVER_IP" \
      || _hc "Conectividade Proxy→Server (10051)" false "$SERVER_IP inacessível"
  else
    _hc "Conectividade Proxy→Server (10051)" false "SERVER_IP não configurado"
  fi

  # 6. Acesso à internet (repo)
  curl -sf --max-time 5 "https://repo.zabbix.com" -o /dev/null 2>/dev/null \
    && _hc "Acesso a repo.zabbix.com" true \
    || _hc "Acesso a repo.zabbix.com" false "sem internet ou DNS"

  echo ""
  echo -e "${azul}${bold}  ── Recursos do Sistema ─────────────────────────────────────────────────────${reset}"

  # 7. Disco
  local disk_pct; disk_pct=$(df / | awk 'NR==2{gsub(/%/,""); print $5}')
  (( disk_pct < 85 )) \
    && _hc "Uso de disco" true "${disk_pct}% (< 85%)" \
    || _hc "Uso de disco" false "${disk_pct}% — CRÍTICO (> 85%)"

  # 8. RAM
  local ram_pct; ram_pct=$(free | awk '/^Mem:/{printf "%.0f", $3*100/$2}')
  (( ram_pct < 90 )) \
    && _hc "Uso de RAM" true "${ram_pct}% (< 90%)" \
    || _hc "Uso de RAM" false "${ram_pct}% — CRÍTICO (> 90%)"

  echo ""
  echo -e "${azul}${bold}  ── Manutenção ──────────────────────────────────────────────────────────────${reset}"

  # 9. Logrotate
  [[ -f /etc/logrotate.d/zabbix-proxy ]] \
    && _hc "Logrotate configurado" true \
    || _hc "Logrotate configurado" false "execute opção 14"

  # 10. Cron backup
  crontab -l 2>/dev/null | grep -q "zabbix-backup" \
    && _hc "Cron de backup ativo" true "todo dia às 02:00" \
    || _hc "Cron de backup ativo" false "execute opção 14"

  # 11. Backups existentes
  local nbak; nbak=$(ls /var/backups/zabbix-proxy/zabbix_db_*.db.gz 2>/dev/null | wc -l)
  (( nbak > 0 )) \
    && _hc "Backups disponíveis" true "$nbak arquivo(s) em /var/backups/zabbix-proxy" \
    || _hc "Backups disponíveis" false "nenhum — execute opção 10"

  # 12. TLS/PSK
  [[ -f /etc/zabbix/zabbix_proxy.psk ]] \
    && _hc "TLS/PSK configurado" true \
    || _hc "TLS/PSK configurado" false "opcional — execute opção 12"

  echo ""
  echo -e "${ciano}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  local pct=$(( score * 100 / total ))
  echo -e "  Resultado: ${verde}${bold}${score}/${total}${reset} checks OK  (${pct}%)"
  echo ""
  if   (( score == total ));          then echo -e "  ${verde}${bold}✓  Tudo OK — proxy completamente saudável!${reset}"
  elif (( pct >= 75 ));               then echo -e "  ${amarelo}${bold}⚠  Atenção: alguns itens merecem revisão.${reset}"
  else                                     echo -e "  ${vermelho}${bold}✗  Problemas críticos detectados! Ação necessária.${reset}"
  fi
  echo ""
}

# ================================================================================
# AGENT2 STANDALONE
# ================================================================================
install_agent2_menu() {
  print_header
  echo -e "${azul}${bold}═══ 📡 INSTALAR ZABBIX AGENT2 ══════════════════════════════════════════════${reset}"; echo ""
  command -v zabbix_agent2 &>/dev/null || add_zabbix_repo
  _install_agent2
  echo ""; systemctl status zabbix-agent2 --no-pager 2>/dev/null | head -10 || true
}

# ================================================================================
# EXPANSÃO DE DISCO LVM — SEM REBOOT
# ================================================================================
_detect_disk_and_part() {
  local pv="$1"
  if   [[ $pv =~ ^(/dev/nvme[0-9]+n[0-9]+)p([0-9]+)$ ]]; then echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
  elif [[ $pv =~ ^(/dev/[a-z]+)([0-9]+)$               ]]; then echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
  else log_error "Dispositivo não reconhecido: $pv"; return 1; fi
}

_rescan_block_device() {
  local disk="$1"; local dn; dn=$(basename "$disk")
  log_info "Rescaneando ${disk}..."
  local before; before=$(blockdev --getsize64 "$disk" 2>/dev/null || echo "0")

  if   [[ $dn =~ ^sd  ]]; then
    [[ -w "/sys/class/block/${dn}/device/rescan" ]] \
      && echo "1" > "/sys/class/block/${dn}/device/rescan" 2>/dev/null || true
    for h in /sys/class/scsi_host/host*/scan; do [[ -w "$h" ]] && echo "- - -" > "$h" 2>/dev/null || true; done
    while IFS= read -r f; do echo "1" > "$f" 2>/dev/null || true
    done < <(find /sys/class/scsi_device -name "rescan" 2>/dev/null)
  elif [[ $dn =~ ^vd  ]]; then
    [[ -w "/sys/class/block/${dn}/device/rescan" ]] \
      && echo "1" > "/sys/class/block/${dn}/device/rescan" 2>/dev/null || true
  elif [[ $dn =~ ^nvme ]]; then
    local ctrl="${dn%%n[0-9]*}"
    if [[ -w "/sys/class/nvme/${ctrl}/rescan_controller" ]]; then
      echo "1" > "/sys/class/nvme/${ctrl}/rescan_controller" 2>/dev/null || true
    elif command -v nvme &>/dev/null; then
      nvme reset "/dev/${ctrl}" 2>/dev/null || true
    fi
  elif [[ $dn =~ ^xvd ]]; then
    [[ -w "/sys/class/block/${dn}/device/rescan" ]] \
      && echo "1" > "/sys/class/block/${dn}/device/rescan" 2>/dev/null || true
  fi

  blockdev --rereadpt "$disk" 2>/dev/null || true
  command -v partx &>/dev/null && { partx -u "$disk" 2>/dev/null || true; }
  partprobe "$disk" 2>/dev/null || true
  udevadm settle --timeout=15 2>/dev/null || sleep 3

  local after; after=$(blockdev --getsize64 "$disk" 2>/dev/null || echo "0")
  if (( after > before )); then
    log_success "Tamanho: $(( before/1024/1024/1024 ))GB → $(( after/1024/1024/1024 ))GB"
    return 0
  else
    log_warning "Tamanho não mudou após rescan ($(( after/1024/1024/1024 ))GB)"
    log_warning "  Certifique-se de ter expandido o disco no hypervisor primeiro."
    return 1
  fi
}

_fix_gpt() {
  local disk="$1"
  log_info "Verificando GPT..."
  if fdisk -l "$disk" 2>&1 | grep -qE "PMBR size mismatch|backup GPT table is not on the end"; then
    log_warning "GPT desatualizado — corrigindo..."
    if   command -v sgdisk &>/dev/null && sgdisk -e "$disk" &>/dev/null; then log_success "GPT corrigido (sgdisk)"
    elif command -v gdisk  &>/dev/null && printf "w\ny\n" | gdisk "$disk" &>/dev/null; then log_success "GPT corrigido (gdisk)"
    else printf "w\n" | fdisk "$disk" &>/dev/null || true; fi
    partprobe "$disk" 2>/dev/null || true
    udevadm settle --timeout=10 2>/dev/null || sleep 2
  else
    log_success "GPT em ordem"
  fi
}

expand_disk() {
  print_header
  echo -e "${azul}${bold}═══ 📈 EXPANSÃO DE DISCO LVM — SEM REBOOT ══════════════════════════════════${reset}"
  echo -e "${cinza}  SCSI (sda) · virtio-blk (vda) · virtio-scsi · NVMe (nvme0n1) · Xen${reset}"; echo ""

  case $PKG_MANAGER in
    apt) pkg_install lvm2 parted cloud-guest-utils gdisk 2>/dev/null || true ;;
    dnf) pkg_install lvm2 parted cloud-utils-growpart gdisk 2>/dev/null || true ;;
  esac

  log_info "Estado atual:"; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT; echo ""

  local root_dev; root_dev=$(findmnt -n -o SOURCE /)
  [[ $root_dev =~ ^/dev/mapper/ ]] || { log_warning "Raiz não está em LVM."; return 1; }

  local vg lv pv disk part_num pt_type
  vg=$(lvs --noheadings -o vg_name "$root_dev" | awk '{print $1}')
  lv=$(lvs --noheadings -o lv_name "$root_dev" | awk '{print $1}')
  pv=$(pvs --noheadings -o pv_name 2>/dev/null | grep -v "/dev/loop" | head -1 | tr -d ' ')
  [[ -n "$pv" ]] || error_exit "Physical Volume não detectado"

  local di; di=$(_detect_disk_and_part "$pv") || error_exit "Formato de PV não suportado"
  read -r disk part_num <<< "$di"
  pt_type=$(parted -s "$disk" print 2>/dev/null | awk '/Partition Table:/ {print $3}' || echo "gpt")

  log_info "Disco: ${verde}${disk}${reset}  (${pt_type})  |  PV: ${verde}${pv}${reset}  |  VG/LV: ${verde}${vg}/${lv}${reset}"
  echo ""; pvs; vgs; lvs; echo ""; df -h /; echo ""

  echo -e "${amarelo}${bold}⚠️  Tenha um snapshot/backup antes de continuar.${reset}"
  confirm "Prosseguir com a expansão?" || return

  echo ""
  echo -e "${ciano}━━━ [0/5] Rescan — detectar novo tamanho sem reboot ━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  _rescan_block_device "$disk" || log_warning "Continuando mesmo sem crescimento detectado..."

  local dsz dsz_gb psz psz_gb unalloc
  dsz=$(blockdev --getsize64 "$disk" 2>/dev/null); dsz_gb=$(( dsz/1024/1024/1024 ))
  psz=$(lsblk -b -n -o SIZE "$pv" | head -1 | tr -d ' \n\r'); psz_gb=$(( psz/1024/1024/1024 ))
  unalloc=$(( dsz_gb - psz_gb ))
  log_info "Disco: ${dsz_gb}GB  |  Partição: ${psz_gb}GB  |  Não alocado: ~${unalloc}GB"
  (( unalloc < 1 )) && { log_warning "< 1GB livre. Verifique o hypervisor."; confirm "Continuar mesmo assim?" || return; }

  echo -e "${ciano}━━━ [1/5] Corrigir GPT ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  [[ $pt_type == "gpt" ]] && { _fix_gpt "$disk"; partprobe "$disk" 2>/dev/null || true; sleep 1; } \
    || log_info "MBR — passo GPT ignorado"

  echo -e "${ciano}━━━ [2/5] Expandir partição ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  local pb; pb=$(lsblk -b -n -o SIZE "$pv" | head -1 | tr -d ' \n\r')
  local expanded=false
  if command -v growpart &>/dev/null; then
    local go; go=$(growpart "$disk" "$part_num" 2>&1) \
      && { log_success "Expandido (growpart)"; expanded=true; } \
      || { echo "$go" | grep -q "NOCHANGE" && { log_info "Já no tamanho máximo"; expanded=true; } \
           || log_warning "growpart falhou — tentando parted..."; }
  fi
  [[ $expanded == false ]] && {
    parted -s "$disk" resizepart "$part_num" 100% 2>/dev/null \
      && { log_success "Expandido (parted)"; expanded=true; } \
      || error_exit "Falha ao expandir partição $pv"
  }
  command -v partx &>/dev/null && { partx -u "$disk" 2>/dev/null || true; }
  partprobe "$disk" 2>/dev/null || true; udevadm settle --timeout=10 2>/dev/null || sleep 3
  local pa; pa=$(lsblk -b -n -o SIZE "$pv" | head -1 | tr -d ' \n\r')
  (( pa > pb )) && log_success "Partição +$(( (pa-pb)/1024/1024/1024 ))GB" || log_info "Tamanho estável"

  echo -e "${ciano}━━━ [3/5] pvresize ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  local pv_b; pv_b=$(pvs --noheadings -o pv_size "$pv" 2>/dev/null | tr -d ' ' || echo "?")
  pvresize "$pv" 2>/dev/null \
    && log_success "PV: ${pv_b} → $(pvs --noheadings -o pv_size "$pv" 2>/dev/null | tr -d ' ')" \
    || error_exit "Falha ao redimensionar PV"

  echo -e "${ciano}━━━ [4/5] Verificar VG ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  log_info "Espaço livre no VG: $(vgs --noheadings -o vg_free "$vg" | tr -d ' ')"

  echo -e "${ciano}━━━ [5/5] lvextend + resize filesystem ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  local lv_path="/dev/${vg}/${lv}"
  local lv_b; lv_b=$(lvs --noheadings -o lv_size "$lv_path" 2>/dev/null | tr -d ' ' || echo "?")
  if lvextend -r -l +100%FREE "$lv_path" 2>/dev/null; then
    log_success "LV: ${lv_b} → $(lvs --noheadings -o lv_size "$lv_path" 2>/dev/null | tr -d ' ')"
  else
    log_warning "lvextend sem espaço — tentando resize direto..."
    local fs; fs=$(lsblk -n -o FSTYPE "$lv_path" 2>/dev/null || echo "")
    case "$fs" in
      ext4|ext3|ext2) resize2fs "$lv_path" 2>/dev/null && log_success "resize2fs OK" || log_warning "Sem espaço adicional" ;;
      xfs)            xfs_growfs / 2>/dev/null && log_success "xfs_growfs OK" || log_warning "Sem espaço adicional" ;;
      *)              log_warning "Filesystem '$fs' — resize manual necessário" ;;
    esac
  fi

  echo ""
  local pct; pct=$(df / | awk 'NR==2{gsub(/%/,""); print $5}')
  local sz;  sz=$(df -h / | awk 'NR==2{print $2}')
  df -hT /; echo ""; vgs; lvs; echo ""

  if (( pct < 90 )); then
    echo -e "${verde}${bold}╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║  ✓  Expansão concluída! Tamanho: ${sz}  —  Uso: ${pct}%                      ║"
    echo -e "║  ✓  REINICIALIZAÇÃO NÃO FOI NECESSÁRIA                                       ║"
    echo -e "╚═══════════════════════════════════════════════════════════════════════════════╝${reset}"
  else
    log_warning "Uso ainda alto (${pct}%). Verifique se o disco foi expandido no hypervisor."
  fi
}

# ================================================================================
# BANCO DE DADOS / BACKUP / RESTORE
# ================================================================================
optimize_database() {
  print_header
  echo -e "${ciano}${bold}═══ 🗜️  OTIMIZAR SQLITE (VACUUM) ════════════════════════════════════════════${reset}"; echo ""
  [[ -f "$DB_FILE" ]] || { log_error "Banco não encontrado: $DB_FILE"; return; }
  local b; b=$(du -h "$DB_FILE" | cut -f1)
  log_info "Tamanho atual: $b"
  local bak="${DB_FILE}.bak-$(date +%F_%T)"
  cp "$DB_FILE" "$bak"; log_success "Backup: $bak"
  log_info "Executando VACUUM..."; echo -e "${cinza}  Aguarde sem interromper...${reset}"
  if sudo -u zabbix sqlite3 "$DB_FILE" "VACUUM;" 2>/dev/null; then
    local a; a=$(du -h "$DB_FILE" | cut -f1)
    log_success "VACUUM OK  |  $b → $a"; rm -f "$bak"
  else
    log_error "Falha! Restaurando..."; cp "$bak" "$DB_FILE"; log_success "Backup restaurado"
  fi
}

backup_now() {
  print_header
  echo -e "${verde}${bold}═══ 💾 BACKUP AGORA ════════════════════════════════════════════════════════${reset}"; echo ""
  local dir="/var/backups/zabbix-proxy"
  local ts; ts=$(date +%Y-%m-%d_%H-%M-%S)
  mkdir -p "$dir"

  if [[ -f "$DB_FILE" ]]; then
    local bak="${dir}/zabbix_db_${ts}.db"
    if sqlite3 "$DB_FILE" ".backup '${bak}'" 2>/dev/null; then
      gzip -f "$bak" && log_success "Banco: ${bak}.gz"
    else log_error "Falha no backup do banco"; fi
  else
    log_warning "Banco não encontrado: $DB_FILE"
  fi

  if [[ -f "$ZBX_CONF" ]]; then
    cp "$ZBX_CONF" "${dir}/zabbix_conf_${ts}.conf"
    log_success "Config: ${dir}/zabbix_conf_${ts}.conf"
  fi

  log_success "Backup salvo em: $dir"
}

restore_backup() {
  print_header
  echo -e "${amarelo}${bold}═══ ♻️  RESTAURAR BACKUP ════════════════════════════════════════════════════${reset}"; echo ""

  local dir="/var/backups/zabbix-proxy"
  [[ -d "$dir" ]] || { log_error "Diretório de backup não encontrado: $dir"; return; }

  local -a backups
  while IFS= read -r f; do backups+=("$f"); done < <(ls -t "$dir"/zabbix_db_*.db.gz 2>/dev/null || true)
  [[ ${#backups[@]} -eq 0 ]] && { log_error "Nenhum backup encontrado em $dir"; log_info "Execute primeiro o Backup (opção 10)"; return; }

  echo -e "${branco}  Backups disponíveis:${reset}"; echo ""
  local i=1
  for f in "${backups[@]}"; do
    local ts_label; ts_label=$(basename "$f" | sed 's/zabbix_db_//;s/\.db\.gz//')
    echo -e "  ${bege}${i})${reset}  ${ts_label}  ${cinza}($(du -h "$f" | cut -f1))${reset}"
    (( i++ ))
  done
  echo ""

  local sel
  read -rp "$(echo -e "${amarelo}  Escolha o backup (1-${#backups[@]}): ${reset}")" sel
  [[ "$sel" =~ ^[0-9]+$ && "$sel" -ge 1 && "$sel" -le "${#backups[@]}" ]] \
    || { log_error "Opção inválida"; return; }

  local chosen="${backups[$((sel-1))]}"
  echo ""
  echo -e "${vermelho}${bold}  ⚠️  ATENÇÃO: o banco de dados atual será substituído!${reset}"
  echo -e "  Arquivo: ${verde}$(basename "$chosen")${reset}"
  echo ""
  confirm "Restaurar este backup?" || return

  systemctl stop zabbix-proxy 2>/dev/null || true
  local bak_current="${DB_FILE}.pre-restore-$(date +%F_%T)"
  [[ -f "$DB_FILE" ]] && { cp "$DB_FILE" "$bak_current"; log_info "Banco atual preservado: $bak_current"; }

  mkdir -p "$(dirname "$DB_FILE")"
  local tmp_restore="${DB_FILE}.restore.tmp"

  if zcat "$chosen" > "$tmp_restore" 2>/dev/null; then
    local check; check=$(sqlite3 "$tmp_restore" "PRAGMA integrity_check;" 2>/dev/null | head -1)
    if [[ "$check" == "ok" ]]; then
      mv "$tmp_restore" "$DB_FILE"
      chown zabbix:zabbix "$DB_FILE"; chmod 640 "$DB_FILE"
      log_success "Banco restaurado com sucesso!"
      systemctl start zabbix-proxy 2>/dev/null \
        && log_success "zabbix-proxy reiniciado" \
        || log_error "Falha ao reiniciar — verifique: journalctl -u zabbix-proxy"
    else
      rm -f "$tmp_restore"
      log_error "Backup corrompido (integrity: $check)! Restaurando versão anterior..."
      [[ -f "$bak_current" ]] && cp "$bak_current" "$DB_FILE" && log_success "Banco anterior restaurado"
      systemctl start zabbix-proxy 2>/dev/null || true
    fi
  else
    log_error "Falha ao descompactar backup"
    rm -f "$tmp_restore"
    systemctl start zabbix-proxy 2>/dev/null || true
  fi
}

# ================================================================================
# SEGURANÇA — TLS/PSK
# ================================================================================
setup_tls_psk() {
  print_header
  echo -e "${vermelho}${bold}═══ 🔐 CONFIGURAR TLS/PSK ══════════════════════════════════════════════════${reset}"; echo ""

  command -v openssl &>/dev/null || pkg_install openssl

  local psk_file="/etc/zabbix/zabbix_proxy.psk"
  local psk_identity="zbx-proxy-$(hostname)"

  if [[ -f "$psk_file" ]]; then
    log_info "PSK já configurado: $psk_file"
    local cur_id; cur_id=$(grep -i "TLSPSKIdentity" "$ZBX_CONF" 2>/dev/null | cut -d= -f2 || echo "não encontrada")
    log_info "Identidade atual: $cur_id"
    echo ""
    confirm "Regenerar chave PSK (substitui a atual)?" || return
  fi

  local psk_key
  psk_key=$(openssl rand -hex 32 2>/dev/null \
    || dd if=/dev/urandom bs=32 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')

  echo "$psk_key" > "$psk_file"
  chown zabbix:zabbix "$psk_file" 2>/dev/null || true
  chmod 640 "$psk_file"
  log_success "Chave PSK gerada: $psk_file"

  if [[ -f "$ZBX_CONF" ]]; then
    sed -i '/^TLS/d' "$ZBX_CONF"
    cat >> "$ZBX_CONF" <<EOF

# TLS/PSK — configurado por ZBX Swiss Manager
TLSConnect=psk
TLSAccept=psk
TLSPSKFile=$psk_file
TLSPSKIdentity=$psk_identity
EOF
    log_success "TLS configurado em $ZBX_CONF"
  fi

  systemctl restart zabbix-proxy 2>/dev/null \
    && log_success "Proxy reiniciado com TLS/PSK" \
    || log_warning "Reinicie manualmente: systemctl restart zabbix-proxy"

  echo ""
  echo -e "${amarelo}${bold}═══ Configure no Servidor Zabbix ════════════════════════════════════════════${reset}"
  echo -e "  Vá em: ${verde}Administration → Proxies → [seu proxy] → Encryption${reset}"
  echo -e "  Connections from proxy: ${verde}PSK${reset}"
  echo -e ""
  echo -e "  ${branco}PSK identity:${reset}  ${verde}${psk_identity}${reset}"
  echo -e "  ${branco}PSK value:${reset}     ${verde}${psk_key}${reset}"
  echo ""
  echo -e "${cinza}  Chave salva em: $psk_file — guarde em lugar seguro!${reset}"
}

# ================================================================================
# MANUTENÇÃO
# ================================================================================
check_updates() {
  print_header
  echo -e "${roxo}${bold}═══ 🔄 VERIFICAR ATUALIZAÇÕES ══════════════════════════════════════════════${reset}"; echo ""
  command -v zabbix_proxy &>/dev/null || { log_error "Zabbix Proxy não instalado"; return; }
  pkg_update
  local updates=""
  case $PKG_MANAGER in
    apt) updates=$(apt list --upgradable 2>/dev/null | grep -i zabbix || true) ;;
    dnf) updates=$(dnf list updates 2>/dev/null | grep -i zabbix || true) ;;
  esac
  if [[ -n "$updates" ]]; then
    log_success "Atualizações disponíveis:"; echo -e "${verde}$updates${reset}"; echo ""
    confirm "Atualizar agora?" && {
      case $PKG_MANAGER in
        apt) DEBIAN_FRONTEND=noninteractive apt-get upgrade -y "zabbix-*" ;;
        dnf) dnf update -y "zabbix-*" ;;
      esac
      log_success "Atualização concluída!"; log_warning "Recomendado: systemctl restart zabbix-proxy"
    } || log_info "Adiado"
  else
    log_success "Todos os pacotes Zabbix estão atualizados!"
  fi
}

setup_maintenance() {
  print_header
  echo -e "${bege}${bold}═══ ⚙️  MANUTENÇÃO AUTOMÁTICA ═══════════════════════════════════════════════${reset}"; echo ""
  log_info "Configurando logrotate..."
  cat > /etc/logrotate.d/zabbix-proxy <<'EOF'
/var/log/zabbix/zabbix_proxy.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 zabbix zabbix
    sharedscripts
    postrotate
        systemctl reload zabbix-proxy >/dev/null 2>&1 || true
    endscript
}
EOF
  log_success "Logrotate: rotação diária, 7 dias, compressão"

  log_info "Criando script de backup..."
  cat > /usr/local/sbin/zabbix-backup.sh <<'BACKUP'
#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="/var/backups/zabbix-proxy"
DB_FILE="/var/lib/zabbix/zabbix.db"
CONF_FILE="/etc/zabbix/zabbix_proxy.conf"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
KEEP_DAYS=7
mkdir -p "$BACKUP_DIR"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S')  $1"; }
log "=== Backup Zabbix Proxy ==="
if [[ -f "$DB_FILE" ]]; then
  bak="${BACKUP_DIR}/zabbix_db_${DATE}.db"
  sqlite3 "$DB_FILE" ".backup '${bak}'" && gzip -f "$bak" && log "Banco: ${bak}.gz"
  find "$BACKUP_DIR" -name "zabbix_db_*.db.gz"  -mtime +"$KEEP_DAYS" -delete
else log "AVISO: $DB_FILE não encontrado"; fi
if [[ -f "$CONF_FILE" ]]; then
  cp "$CONF_FILE" "${BACKUP_DIR}/zabbix_conf_${DATE}.conf" && log "Config: salva"
  find "$BACKUP_DIR" -name "zabbix_conf_*.conf" -mtime +"$KEEP_DAYS" -delete
fi
log "Concluído."
BACKUP
  chmod +x /usr/local/sbin/zabbix-backup.sh
  log_success "Script de backup: /usr/local/sbin/zabbix-backup.sh"

  log_info "Configurando cron automático (02:00 diário)..."
  local cron_line="0 2 * * * /usr/local/sbin/zabbix-backup.sh >> /var/log/zabbix-backup.log 2>&1"
  if crontab -l 2>/dev/null | grep -q "zabbix-backup"; then
    log_info "Cron já configurado — mantendo"
  else
    ( crontab -l 2>/dev/null || true; echo "$cron_line" ) | crontab -
    log_success "Cron adicionado: todo dia às 02:00"
  fi
  echo ""; log_success "Manutenção automática configurada!"
}

system_cleanup() {
  print_header
  echo -e "${ciano}${bold}═══ 🧹 LIMPEZA DE SISTEMA ══════════════════════════════════════════════════${reset}"; echo ""
  case $PKG_MANAGER in
    apt) apt-get clean; apt-get autoclean; apt-get autoremove -y; log_success "Cache APT limpo" ;;
    dnf) dnf clean all; dnf autoremove -y; log_success "Cache DNF limpo" ;;
  esac
  journalctl --vacuum-time=7d 2>/dev/null && log_success "Logs do systemd (7d)" || true
  rm -rf /tmp/* /var/tmp/* 2>/dev/null || true; log_success "Arquivos temporários removidos"
  echo ""; log_success "Limpeza concluída!"
  df -h / | awk 'NR==2{printf "  Livre: %s de %s (%s usado)\n", $4, $2, $5}'
}

# ================================================================================
# SISTEMA — INFO, MONITOR, DIAGNÓSTICO
# ================================================================================
show_system_info() {
  print_header
  echo -e "${verde}${bold}═══ 📋 INFORMAÇÕES DO SISTEMA ══════════════════════════════════════════════${reset}"; echo ""
  echo -e "${azul}${bold}🖥️  SO${reset}"
  echo -e "  ${verde}$OS_TYPE $OS_VERSION${reset}  |  Kernel: ${verde}$(uname -r)${reset}  |  Arch: ${verde}$(uname -m)${reset}"
  echo -e "  Hostname: ${verde}$(hostname)${reset}  |  Uptime: ${verde}$(uptime -p)${reset}"; echo ""
  echo -e "${azul}${bold}💻 HARDWARE${reset}"
  [[ -f /proc/cpuinfo ]] && echo -e "  CPU: ${verde}$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)${reset}"
  echo -e "  Cores: ${verde}$(nproc)${reset}  |  RAM: ${verde}$(free -h | awk '/^Mem:/{print $2}') total / $(free -h | awk '/^Mem:/{print $7}') livre${reset}"; echo ""
  echo -e "${azul}${bold}💾 DISCO${reset}"
  df -h | grep "^/dev/" | awk '{printf "  %-22s  livre: %-8s  total: %-8s  (%s)\n", $1, $4, $2, $5}'; echo ""
  echo -e "${azul}${bold}🌐 REDE${reset}"
  ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' \
    | while read -r ip; do echo -e "  Privado: ${verde}${ip}${reset}"; done
  echo -e "  Público: ${verde}$(curl -sf --max-time 5 ifconfig.me 2>/dev/null || echo N/A)${reset}"; echo ""
  if command -v zabbix_proxy &>/dev/null; then
    echo -e "${azul}${bold}📊 ZABBIX PROXY${reset}"
    echo -e "  Versão: ${verde}$(zabbix_proxy -V 2>/dev/null | head -1 | awk '{print $3}')${reset}"
    systemctl is-active --quiet zabbix-proxy \
      && echo -e "  Status: ${verde}✓ Ativo${reset}" \
      || echo -e "  Status: ${vermelho}✗ Inativo${reset}"
    [[ -f "$DB_FILE" ]] && echo -e "  Banco: ${verde}$(du -h "$DB_FILE" | cut -f1)${reset}"; echo ""
  fi
  echo -e "${azul}${bold}⚡ PERFORMANCE${reset}"
  echo -e "  Load: ${verde}$(uptime | awk -F'load average:' '{print $2}')${reset}"
  local mt mu mp
  read -r mt mu <<< "$(free | awk '/^Mem:/{print $2, $3}')"
  mp=$(( mu * 100 / mt ))
  echo -e "  CPU: ${verde}$(top -bn1 | awk '/Cpu\(s\)/{print $2}')%${reset}  |  RAM: ${verde}${mp}%${reset}"
}

monitor_resources() {
  print_header
  echo -e "${roxo}${bold}═══ 🔍 MONITOR EM TEMPO REAL ═══════════════════════════════════════════════${reset}"
  echo -e "${amarelo}  CTRL+C para sair${reset}"; sleep 1
  while true; do
    clear; print_header
    echo -e "${roxo}${bold}🔍 MONITOR${reset}  ${cinza}(refresh 2s)${reset}"; echo ""
    echo -e "${ciano}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    local mt mu mp; read -r mt mu <<< "$(free | awk '/^Mem:/{print $2, $3}')"
    mp=$(( mu * 100 / mt ))
    echo -e "  ${azul}${bold}CPU:${reset}          ${verde}$(top -bn1 | awk '/Cpu\(s\)/{print $2}')% usado${reset}"
    echo -e "  ${azul}${bold}RAM:${reset}          ${verde}${mp}%${reset}  ($(free -h | awk '/^Mem:/{print $3}') / $(free -h | awk '/^Mem:/{print $2}'))"
    echo -e "  ${azul}${bold}Disco (/):${reset}    ${verde}$(df / | awk 'NR==2{gsub(/%/,""); print $5}')%${reset}  ($(df -h / | awk 'NR==2{print $3}') / $(df -h / | awk 'NR==2{print $2}'))"
    echo -e "  ${azul}${bold}Load:${reset}         ${verde}$(uptime | awk -F'load average:' '{print $2}')${reset}"
    echo -e "  ${azul}${bold}Processos:${reset}    ${verde}$(ps aux | wc -l)${reset}"
    command -v zabbix_proxy &>/dev/null && {
      systemctl is-active --quiet zabbix-proxy \
        && echo -e "  ${azul}${bold}zabbix-proxy:${reset} ${verde}Ativo${reset}" \
        || echo -e "  ${azul}${bold}zabbix-proxy:${reset} ${vermelho}Inativo${reset}"
    }
    echo ""
    echo -e "${ciano}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    echo -e "  ${amarelo}${bold}Top 5 — CPU:${reset}"
    ps aux --sort=-%cpu | awk 'NR>1&&NR<=6{printf "    %-35s %5.1f%%\n",$11,$3}'
    echo ""
    echo -e "  ${amarelo}${bold}Top 5 — RAM:${reset}"
    ps aux --sort=-%mem | awk 'NR>1&&NR<=6{printf "    %-35s %5.1f%%\n",$11,$4}'
    sleep 2
  done
}

export_diagnostics() {
  print_header
  echo -e "${cinza}${bold}═══ 📄 EXPORTAR DIAGNÓSTICO ════════════════════════════════════════════════${reset}"; echo ""

  local out="/tmp/zbx-swiss-diag-$(date +%Y%m%d_%H%M%S).txt"
  log_info "Coletando informações..."

  {
    echo "========================================================"
    echo "  ZBX Swiss Manager v${VERSION} — Relatório de Diagnóstico"
    echo "  Gerado: $(date)"
    echo "  Hostname: $(hostname)"
    echo "========================================================"
    echo ""
    echo "--- Sistema Operacional ---"
    uname -a
    cat /etc/os-release 2>/dev/null | grep -E "^(NAME|VERSION)=" || true
    echo "Uptime: $(uptime)"
    echo ""
    echo "--- Hardware ---"
    echo "CPU cores: $(nproc)"
    grep -m1 'model name' /proc/cpuinfo 2>/dev/null || true
    free -h
    echo ""
    echo "--- Disco ---"
    df -hT
    echo ""
    echo "--- Processos Zabbix ---"
    ps aux 2>/dev/null | grep -i zabbix | grep -v grep || echo "(nenhum)"
    echo ""
    echo "--- Zabbix Proxy ---"
    zabbix_proxy -V 2>/dev/null || echo "não instalado"
    echo ""
    echo "--- Status do Serviço ---"
    systemctl status zabbix-proxy --no-pager 2>/dev/null | head -25 || true
    echo ""
    echo "--- Configuração (dados sensíveis omitidos) ---"
    if [[ -f "$ZBX_CONF" ]]; then
      grep -v -iE "^(TLSPSKFile|PSK|Password|Secret)" "$ZBX_CONF" \
        | grep -v "^#" | grep -v "^$" || true
    else
      echo "Arquivo não encontrado: $ZBX_CONF"
    fi
    echo ""
    echo "--- Banco de Dados ---"
    if [[ -f "$DB_FILE" ]]; then
      echo "Tamanho: $(du -h "$DB_FILE" | cut -f1)"
      echo "Integrity check: $(sqlite3 "$DB_FILE" 'PRAGMA integrity_check;' 2>/dev/null | head -1)"
      echo "Tabelas: $(sqlite3 "$DB_FILE" "SELECT count(*) FROM sqlite_master WHERE type='table';" 2>/dev/null)"
    else
      echo "Banco não encontrado: $DB_FILE"
    fi
    echo ""
    echo "--- Rede ---"
    ip -4 addr show 2>/dev/null | grep -E "(inet|UP)" || true
    echo ""
    echo "--- Portas Zabbix ---"
    ss -tlnp 2>/dev/null | grep -E "(10050|10051)" || echo "(nenhuma porta Zabbix detectada)"
    echo ""
    echo "--- Logs Recentes (50 linhas) ---"
    journalctl -u zabbix-proxy -n 50 --no-pager 2>/dev/null || \
      tail -50 /var/log/zabbix/zabbix_proxy.log 2>/dev/null || echo "(sem logs)"
    echo ""
    echo "--- Crontab ---"
    crontab -l 2>/dev/null | grep -i zabbix || echo "(sem cron zabbix)"
    echo ""
    echo "--- Backups Disponíveis ---"
    ls -lh /var/backups/zabbix-proxy/ 2>/dev/null || echo "(nenhum backup)"
    echo ""
    echo "========================================================"
    echo "  Fim do relatório"
    echo "========================================================"
  } > "$out" 2>&1

  log_success "Diagnóstico salvo: ${verde}$out${reset}"
  echo ""
  echo -e "${amarelo}  ATENÇÃO: revise o arquivo antes de compartilhar — pode conter IPs internos.${reset}"
  echo -e "${cinza}  Para copiar: scp root@$(hostname):${out} ./diagnóstico.txt${reset}"
}

# ================================================================================
# SELF-UPDATE
# ================================================================================
self_update() {
  print_header
  echo -e "${verde}${bold}═══ ⬆️  ATUALIZAR ZBX SWISS ════════════════════════════════════════════════${reset}"; echo ""
  log_info "Buscando versão mais recente em GitHub..."
  log_info "URL: $GITHUB_RAW_URL"; echo ""

  local tmp; tmp=$(mktemp /tmp/zbx-swiss-update.XXXXXX)

  if ! curl -sf --max-time 30 "$GITHUB_RAW_URL" -o "$tmp"; then
    log_error "Falha ao baixar. Verifique a conexão com o GitHub."
    rm -f "$tmp"; return
  fi

  local remote_ver; remote_ver=$(grep '^VERSION=' "$tmp" | head -1 | cut -d'"' -f2 || echo "")
  [[ -z "$remote_ver" ]] && { log_error "Não foi possível determinar a versão do arquivo baixado"; rm -f "$tmp"; return; }

  log_info "Versão atual:     ${amarelo}${VERSION}${reset}"
  log_info "Versão disponível: ${verde}${remote_ver}${reset}"; echo ""

  if [[ "$remote_ver" == "$VERSION" ]]; then
    log_success "Você já está na versão mais recente ($VERSION)!"
    rm -f "$tmp"; return
  fi

  if ! bash -n "$tmp" 2>/dev/null; then
    log_error "Arquivo baixado com erro de sintaxe — abortando por segurança"
    rm -f "$tmp"; return
  fi

  confirm "Atualizar de v${VERSION} para v${remote_ver}?" || { rm -f "$tmp"; return; }

  local bak="${SCRIPT_FILE}.bak-$(date +%F_%T)"
  cp "$SCRIPT_FILE" "$bak"
  log_info "Versão atual salva em: $bak"

  cp "$tmp" "$SCRIPT_FILE"
  chmod +x "$SCRIPT_FILE"
  rm -f "$tmp"

  log_success "ZBX Swiss atualizado para v${remote_ver}!"
  log_info "Reinicie o script para usar a nova versão."
  exit 0
}

# ================================================================================
# MAIN
# ================================================================================
main() {
  setup_logging
  check_root
  detect_os
  load_config

  if [[ ! -f "$CONFIG_FILE" && -z "$DIRECT_ACTION" ]]; then
    first_run_wizard
  fi

  case "$DIRECT_ACTION" in
    install)     install_zabbix_proxy; exit 0 ;;
    remove)      remove_zabbix;        exit 0 ;;
    status)      check_status;         exit 0 ;;
    health)      health_check;         exit 0 ;;
    expand)      expand_disk;          exit 0 ;;
    backup)      backup_now;           exit 0 ;;
    restore)     restore_backup;       exit 0 ;;
    tls)         setup_tls_psk;        exit 0 ;;
    restart)     restart_services;     exit 0 ;;
    diagnose)    export_diagnostics;   exit 0 ;;
    reconf)      reconfigure;          exit 0 ;;
    selfupdate)  self_update;          exit 0 ;;
  esac

  while true; do
    show_main_menu
    read -rp "$(echo -e "${branco}${bold}  ➤ Opção: ${reset}")" opt
    case "$opt" in
      1)  install_zabbix_proxy  ;;
      2)  remove_zabbix         ;;
      3)  check_status          ;;
      4)  restart_services      ;;
      5)  view_logs             ;;
      6)  install_agent2_menu   ;;
      7)  health_check          ;;
      8)  expand_disk           ;;
      9)  optimize_database     ;;
      10) backup_now            ;;
      11) restore_backup        ;;
      12) setup_tls_psk         ;;
      13) check_updates         ;;
      14) setup_maintenance     ;;
      15) system_cleanup        ;;
      16) show_system_info      ;;
      17) monitor_resources     ;;
      18) export_diagnostics    ;;
      19) reconfigure           ;;
      20) self_update           ;;
      0)
        echo -e "${verde}${bold}  Até logo!${reset}"; echo ""
        exit 0 ;;
      *)
        print_header
        log_error "Opção inválida: '$opt'. Use 0–20."
        sleep 1
        continue ;;
    esac
    pause_prompt
  done
}

main "$@"
