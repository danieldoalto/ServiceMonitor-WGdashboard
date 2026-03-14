#!/bin/bash
# =============================================================================
# wg-peer-monitor.sh — Monitor de peers WireGuard
# Instalar em: /usr/local/bin/wg-peer-monitor.sh
# =============================================================================

# ---------------------------------------------------------------------------
# Configurações e Caminhos
# ---------------------------------------------------------------------------
CONFIG_FILE="/etc/wg-peer-monitor.conf"
LOCAL_CONFIG="./wg-peer-monitor.conf"

# Carrega configuração (prioridade: /etc > local > padrões do script)
[ -f "$LOCAL_CONFIG" ] && source "$LOCAL_CONFIG"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

INTERFACE="${WG_INTERFACE:-wg0}"
DOCKER_CONTAINER="${WG_DOCKER_CONTAINER:-}"
STATE_DIR="/var/lib/wg-peer-monitor"
STATE_FILE="$STATE_DIR/peers_state"
LOG_TAG="${LOG_TAG:-wg-peer-monitor}"

# Tempo (segundos) sem handshake para considerar peer desconectado
INACTIVE_THRESHOLD="${WG_INACTIVE_THRESHOLD:-180}"

# Intervalo de verificação (segundos)
CHECK_INTERVAL="${WG_CHECK_INTERVAL:-5}"

# Define os comandos base (local ou docker)
WG_CMD="wg"
IP_CMD="ip"
if [ -n "$DOCKER_CONTAINER" ]; then
    WG_CMD="docker exec $DOCKER_CONTAINER wg"
    IP_CMD="docker exec $DOCKER_CONTAINER ip"
fi

# ---------------------------------------------------------------------------
log() {
    logger -t "$LOG_TAG" "$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ---------------------------------------------------------------------------
# AÇÕES — edite estas funções com o que quiser executar
# ---------------------------------------------------------------------------

send_notification() {
    local url_template="$1"
    local raw_text="$2"
    
    # URL Encode básica para o texto (substitui + por %2B e / por %2F)
    local encoded_text=$(echo "$raw_text" | sed 's/+/%%2B/g; s/\//%%2F/g')
    
    # Substitui o placeholder {TEXT} na URL
    local final_url="${url_template//"{TEXT}"/"$encoded_text"}"
    
    if [ -n "$url_template" ]; then
        log "Enviando notificação: $raw_text"
        curl -s "$final_url" > /dev/null &
    fi
}

on_peer_connect() {
    local peer="$1"
    local endpoint="$2"
    local peer7=$(echo "$peer" | cut -c1-7)
    local msg="WG_CONECTADO_${endpoint}_${peer7}"
    
    log "CONECTADO: peer=$peer endpoint=$endpoint"
    send_notification "$WG_ON_CONNECT_URL" "$msg"
}

on_peer_disconnect() {
    local peer="$1"
    local endpoint="$2" # Agora recebe o último endpoint conhecido
    local peer7=$(echo "$peer" | cut -c1-7)
    local msg="WG_DESCONECTADO_${endpoint}_${peer7}"
    
    log "DESCONECTADO: peer=$peer"
    send_notification "$WG_ON_DISCONNECT_URL" "$msg"
}

# ---------------------------------------------------------------------------
# Lógica principal
# ---------------------------------------------------------------------------

init() {
    mkdir -p "$STATE_DIR"
    if [ ! -f "$STATE_FILE" ]; then
        touch "$STATE_FILE"
    fi

    # Verifica se a interface existe
    if ! $IP_CMD link show "$INTERFACE" &>/dev/null; then
        log "ERRO: Interface $INTERFACE não encontrada. Aguardando..."
        while ! $IP_CMD link show "$INTERFACE" &>/dev/null; do
            sleep 5
        done
        log "Interface $INTERFACE encontrada, iniciando monitoramento."
    fi
}

# Retorna lista de peers ativos (com handshake recente)
get_active_peers() {
    local now
    # Obtém o tempo atual diretamente do ambiente onde o WireGuard roda
    if [ -n "$DOCKER_CONTAINER" ]; then
        now=$(docker exec "$DOCKER_CONTAINER" date +%s)
    else
        now=$(date +%s)
    fi

    # Processa tudo em um único pipeline para ser mais rápido e preciso
    $WG_CMD show "$INTERFACE" latest-handshakes 2>/dev/null | \
    awk -v now="$now" -v threshold="$INACTIVE_THRESHOLD" '
        $2 != 0 {
            age = now - $2
            if (age >= 0 && age <= threshold) {
                print $1
            }
        }
    ' | \
    while read -r peer; do
        # Busca endpoint apenas para peers que passaram no filtro de tempo
        local endpoint
        endpoint=$($WG_CMD show "$INTERFACE" endpoints 2>/dev/null | \
                   awk -v p="$peer" '$1 == p {print $2}')
        echo "$peer $endpoint"
    done
}

run_monitor() {
    local msg="Iniciando monitoramento da interface $INTERFACE"
    [ -n "$DOCKER_CONTAINER" ] && msg="$msg no contêiner $DOCKER_CONTAINER"
    log "$msg (threshold=${INACTIVE_THRESHOLD}s, intervalo=${CHECK_INTERVAL}s)"

    while true; do
        # Peers ativos agora
        declare -A current_peers
        while read -r peer endpoint; do
            current_peers["$peer"]="$endpoint"
        done < <(get_active_peers)

        # Peers conhecidos (estado anterior)
        declare -A known_peers
        while IFS='|' read -r peer endpoint; do
            [ -n "$peer" ] && known_peers["$peer"]="$endpoint"
        done < "$STATE_FILE"

        # Detecta novos peers (conectaram)
        for peer in "${!current_peers[@]}"; do
            if [ -z "${known_peers[$peer]+x}" ]; then
                on_peer_connect "$peer" "${current_peers[$peer]}"
            fi
        done

        # Detecta peers que saíram (desconectaram)
        for peer in "${!known_peers[@]}"; do
            if [ -z "${current_peers[$peer]+x}" ]; then
                on_peer_disconnect "$peer" "${known_peers[$peer]}"
            fi
        done

        # Salva estado atual
        : > "$STATE_FILE"
        for peer in "${!current_peers[@]}"; do
            echo "${peer}|${current_peers[$peer]}" >> "$STATE_FILE"
        done

        unset current_peers known_peers
        sleep "$CHECK_INTERVAL"
    done
}

# ---------------------------------------------------------------------------
init
run_monitor
