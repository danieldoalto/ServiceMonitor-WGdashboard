#!/bin/bash
# =============================================================================
# install.sh — Instala o wg-peer-monitor no sistema
# Execute como root: sudo bash install.sh
# =============================================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()    { echo -e "${GREEN}[✔]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✘]${NC} $*"; exit 1; }

[ "$EUID" -ne 0 ] && error "Execute como root: sudo bash install.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Copia o script monitor
info "Instalando script em /usr/local/bin/wg-peer-monitor.sh..."
cp "$SCRIPT_DIR/wg-peer-monitor.sh" /usr/local/bin/wg-peer-monitor.sh
chmod +x /usr/local/bin/wg-peer-monitor.sh

# 2. Cria diretório de estado
info "Criando diretório de estado em /var/lib/wg-peer-monitor..."
mkdir -p /var/lib/wg-peer-monitor

# 3. Instala arquivo de configuração (não sobrescreve se já existir)
if [ ! -f /etc/wg-peer-monitor.conf ]; then
    info "Instalando configuração em /etc/wg-peer-monitor.conf..."
    cp "$SCRIPT_DIR/wg-peer-monitor.conf" /etc/wg-peer-monitor.conf
else
    warn "Arquivo /etc/wg-peer-monitor.conf já existe. Pulando cópia."
fi

# 4. Instala o serviço systemd
info "Instalando serviço systemd..."
cp "$SCRIPT_DIR/wg-peer-monitor.service" /etc/systemd/system/wg-peer-monitor.service

# 5. Recarrega o systemd
systemctl daemon-reload

# 6. Habilita e inicia o serviço
info "Habilitando e iniciando o serviço..."
systemctl enable wg-peer-monitor.service
systemctl start wg-peer-monitor.service

echo ""
info "Instalação concluída!"
echo ""
echo "  Configurações:     nano /etc/wg-peer-monitor.conf"
echo "  Editar ações:      nano /usr/local/bin/wg-peer-monitor.sh"
echo "  Verificar status:  systemctl status wg-peer-monitor"
echo "  Ver logs:          journalctl -u wg-peer-monitor -f"
echo ""
warn "Lembre-se de editar as funções on_peer_connect() e on_peer_disconnect()"
warn "no arquivo /usr/local/bin/wg-peer-monitor.sh com suas ações personalizadas."
