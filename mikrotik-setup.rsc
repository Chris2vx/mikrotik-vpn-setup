# ============================================================
# MikroTik Setup Script — VPN Router Config
# Paste this into the MikroTik terminal (Winbox)
#
# SETUP INSTRUCTIONS:
# 1. Fill in the placeholder values below
# 2. Paste into MikroTik Winbox terminal
# ============================================================

# ── Configuration — FILL THESE IN ──────────────────────────
# VPS_PUBLIC_KEY    — from vps-setup.sh output
# VPS_IP            — your DigitalOcean droplet public IP
# MULLVAD_IP        — from your Mullvad WireGuard config file
# MULLVAD_ENDPOINT  — from your Mullvad WireGuard config file
# HOME_GATEWAY      — your home router IP (usually 192.168.1.1)
# ───────────────────────────────────────────────────────────

# ── Step 1: Create WireGuard Interfaces ────────────────────
/interface wireguard add name=mullvad listen-port=51820
/interface wireguard add name=vps listen-port=51821

# ── Step 2: Add Mullvad Peer ────────────────────────────────
# Get MULLVAD_PUBKEY and MULLVAD_ENDPOINT from your .conf file
# at mullvad.net/en/account/wireguard-config
/interface wireguard peers add \
    interface=mullvad \
    public-key="MULLVAD_PUBLIC_KEY" \
    endpoint-address=MULLVAD_ENDPOINT_IP \
    endpoint-port=MULLVAD_ENDPOINT_PORT \
    allowed-address=0.0.0.0/0 \
    persistent-keepalive=25

# ── Step 3: Add VPS Peer ────────────────────────────────────
# VPS_PUBLIC_KEY comes from running vps-setup.sh on your VPS
/interface wireguard peers add \
    interface=vps \
    public-key="VPS_PUBLIC_KEY" \
    endpoint-address=VPS_IP \
    endpoint-port=443 \
    allowed-address=0.0.0.0/0 \
    persistent-keepalive=25

# ── Step 4: Assign IP Addresses ─────────────────────────────
# MULLVAD_VPN_IP comes from your Mullvad config file (Address field)
/ip address add address=MULLVAD_VPN_IP/32 interface=mullvad
/ip address add address=10.8.0.2/32 interface=vps

# ── Step 5: Configure DNS ───────────────────────────────────
/ip dns set servers=10.64.0.1 allow-remote-requests=yes

# ── Step 6: Configure WAN (Home - DHCP) ─────────────────────
/ip dhcp-client add interface=ether1 disabled=no add-default-route=yes use-peer-dns=no

# ── Step 7: Add Routes ──────────────────────────────────────
# Replace HOME_GATEWAY with your home router IP (e.g. 192.168.1.1)
/ip route add dst-address=VPS_IP/32 gateway=HOME_GATEWAY comment="VPS direct route"
/ip route add dst-address=10.8.0.1/32 gateway=vps comment="VPS tunnel gateway"

# ── Step 8: Policy Routing ──────────────────────────────────
/routing table add name=vpn fib
/ip firewall mangle add \
    chain=prerouting \
    in-interface=bridge \
    action=mark-routing \
    new-routing-mark=vpn \
    passthrough=yes \
    comment="Mark LAN traffic for VPN routing"
/ip route add \
    dst-address=0.0.0.0/0 \
    gateway=vps \
    routing-table=vpn \
    distance=1 \
    comment="VPN default route"

# ── Step 9: NAT ─────────────────────────────────────────────
/ip firewall nat add \
    chain=srcnat \
    out-interface=vps \
    action=masquerade \
    comment="NAT for VPN traffic"

# ── Step 10: Firewall — Allow VPN Interface ─────────────────
/interface list add name=VPN
/interface list member add interface=vps list=VPN
/interface list member add interface=mullvad list=VPN
/ip firewall filter add \
    chain=input \
    in-interface-list=VPN \
    action=accept \
    place-before=0 \
    comment="Allow VPN input"
/ip firewall filter add \
    chain=forward \
    in-interface-list=VPN \
    action=accept \
    place-before=0 \
    comment="Allow VPN forward"

# ── Done! ───────────────────────────────────────────────────
# Verify with:
# /interface wireguard peers print detail
# /ip route print where routing-table=vpn
# Then check mullvad.net/check on a connected device


# ============================================================
# SCHOOL NETWORK — Run these when at school
# Replace SCHOOL_IP, SCHOOL_SUBNET, SCHOOL_GATEWAY with your
# school's network values (get from ipconfig /all on school PC)
# ============================================================
# /ip address add address=SCHOOL_IP/SCHOOL_SUBNET interface=ether1
# /ip route add dst-address=0.0.0.0/0 gateway=SCHOOL_GATEWAY distance=1
# /ip route add dst-address=VPS_IP/32 gateway=SCHOOL_GATEWAY


# ============================================================
# HOME NETWORK — Run these when back at home
# ============================================================
# /ip dhcp-client set [find interface=ether1] disabled=no
# /ip route set [find comment="VPS direct route"] gateway=HOME_GATEWAY
