#!/bin/bash
# ============================================================
# VPS Setup Script — MikroTik VPN Relay
# Run this on a fresh Ubuntu 22.04 DigitalOcean droplet
#
# SETUP INSTRUCTIONS:
# 1. Fill in the configuration values below
# 2. Run: bash vps-setup.sh
# ============================================================

set -e

echo "============================================"
echo " MikroTik VPN Relay — VPS Setup Script"
echo "============================================"

# ── Configuration — FILL THESE IN ──────────────────────────
VPS_IP="YOUR_VPS_PUBLIC_IP"               # e.g. 1.2.3.4
VPS_WG_PORT="443"                          # Port for MikroTik tunnel
VPS_TUNNEL_IP="10.8.0.1/24"               # VPS tunnel IP (keep as is)

MIKROTIK_PUBKEY="YOUR_MIKROTIK_VPS_INTERFACE_PUBLIC_KEY"  # From /interface wireguard print
MIKROTIK_TUNNEL_IP="10.8.0.2/32"          # MikroTik tunnel IP (keep as is)

MULLVAD_PRIVKEY="YOUR_MULLVAD_PRIVATE_KEY"  # From Mullvad config file
MULLVAD_PUBKEY="YOUR_MULLVAD_PUBLIC_KEY"    # From Mullvad config file
MULLVAD_IP="YOUR_MULLVAD_VPN_IP/32"        # From Mullvad config file e.g. 10.x.x.x
MULLVAD_ENDPOINT="YOUR_MULLVAD_ENDPOINT"   # From Mullvad config e.g. 1.2.3.4:3444
# ───────────────────────────────────────────────────────────

# Validate config
if [[ "$VPS_IP" == "YOUR_VPS_PUBLIC_IP" ]]; then
    echo "ERROR: Please fill in the configuration values before running this script."
    exit 1
fi

echo ""
echo "[1/7] Installing WireGuard..."
apt update -qq && apt install -y wireguard

echo ""
echo "[2/7] Generating VPS WireGuard keys..."
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
chmod 600 /etc/wireguard/private.key
VPS_PRIVKEY=$(cat /etc/wireguard/private.key)
VPS_PUBKEY=$(cat /etc/wireguard/public.key)
echo "VPS Public Key: $VPS_PUBKEY"

echo ""
echo "[3/7] Creating MikroTik tunnel config (wg0)..."
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $VPS_PRIVKEY
Address = $VPS_TUNNEL_IP
ListenPort = $VPS_WG_PORT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $MIKROTIK_PUBKEY
AllowedIPs = $MIKROTIK_TUNNEL_IP
PersistentKeepalive = 25
EOF

echo ""
echo "[4/7] Creating Mullvad tunnel config..."
cat > /etc/wireguard/mullvad.conf << EOF
[Interface]
PrivateKey = $MULLVAD_PRIVKEY
Address = $MULLVAD_IP
Table = off

[Peer]
PublicKey = $MULLVAD_PUBKEY
AllowedIPs = 0.0.0.0/0
Endpoint = $MULLVAD_ENDPOINT
PersistentKeepalive = 25
EOF

echo ""
echo "[5/7] Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

echo ""
echo "[6/7] Creating startup script..."
MULLVAD_BARE_IP="${MULLVAD_IP%/*}"
cat > /root/setup-vpn.sh << EOF
#!/bin/bash
# VPN Relay Startup Script

# Keep SSH accessible
ip rule add from $VPS_IP table main priority 10 2>/dev/null || true

# Start tunnels
wg-quick up wg0 2>/dev/null || true
wg-quick up mullvad 2>/dev/null || true

# Route MikroTik traffic through Mullvad
ip rule add from 10.8.0.0/24 table 200 priority 100 2>/dev/null || true
ip rule add from $MULLVAD_BARE_IP table 200 priority 101 2>/dev/null || true
ip route replace default dev mullvad table 200 2>/dev/null || true

# NAT rules
iptables -F FORWARD 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -A FORWARD -i wg0 -o mullvad -j ACCEPT
iptables -A FORWARD -i mullvad -o wg0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o mullvad -j SNAT --to-source $MULLVAD_BARE_IP
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

echo "VPN relay is running!"
EOF
chmod +x /root/setup-vpn.sh

echo ""
echo "[7/7] Enabling auto-start services..."
cat > /etc/systemd/system/vpn-setup.service << EOF
[Unit]
Description=VPN Relay Setup
After=network.target wg-quick@wg0.service wg-quick@mullvad.service

[Service]
Type=oneshot
ExecStart=/root/setup-vpn.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable wg-quick@wg0
systemctl enable wg-quick@mullvad
systemctl enable vpn-setup
systemctl daemon-reload

echo ""
echo "Running startup script..."
bash /root/setup-vpn.sh

echo ""
echo "============================================"
echo " Setup Complete!"
echo "============================================"
echo "VPS Public Key: $VPS_PUBKEY"
echo ""
echo "Add this public key to your MikroTik vps peer."
echo "Test with: wg show"
echo "============================================"
