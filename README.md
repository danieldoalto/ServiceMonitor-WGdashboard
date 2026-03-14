# WireGuard Peer Monitor (Docker & WhatsApp)

Este projeto monitora em tempo real a conexão e desconexão de peers em uma interface **WireGuard** (rodando localmente ou dentro de um contêiner **Docker/wgdashboard**) e envia notificações automáticas via WhatsApp através da API do **CallMeBot**.

## 🚀 Funcionalidades

- **Monitoramento em tempo real**: Detecta conexões e desconexões baseadas no tempo de handshake.
- **Suporte a Docker**: Funciona perfeitamente com o `wgdashboard` ou outros WireGuard conteinerizados.
- **Notificação WhatsApp**: Envia mensagens personalizadas com o IP/Endpoint e o ID (7 caracteres da chave) do Peer.
- **Instalação como Serviço**: Inclui script de instalação para rodar como um serviço `systemd`.
- **Configuração Centralizada**: Arquivo de configuração simples em `/etc/wg-peer-monitor.conf`.

## 🛠️ Pré-requisitos

- Linux (Ubuntu/Debian recomendado)
- Docker (se o WireGuard estiver em contêiner)
- WireGuard Tools (`wg` command)
- API Key do [CallMeBot](https://www.callmebot.com/blog/free-api-whatsapp-messages/)

## 📦 Instalação

1. Clone o repositório:
   ```bash
   git clone <URL_DO_REPOSITORIO>
   cd "WG monitora Peer"
   ```

2. Configure seus dados:
   ```bash
   cp wg-peer-monitor.conf.example wg-peer-monitor.conf
   nano wg-peer-monitor.conf
   ```

3. Execute o instalador:
   ```bash
   sudo bash install.sh
   ```

## 📊 Monitoramento

Para acompanhar o funcionamento do serviço:
```bash
journalctl -u wg-peer-monitor -f
```

## ⚙️ Personalização

Você pode editar as ações executadas em caso de evento editando as funções `on_peer_connect()` e `on_peer_disconnect()` no arquivo:
`/usr/local/bin/wg-peer-monitor.sh`

---
Desenvolvido para monitoramento de VPNs WireGuard.
