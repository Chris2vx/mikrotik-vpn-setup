# MikroTik VPN Setup

A network-wide VPN setup using a MikroTik router, DigitalOcean VPS relay, and Mullvad VPN.

## How It Works

All devices connected to the MikroTik router are automatically routed through Mullvad VPN via a VPS relay server. Port 443 is used to bypass network firewalls.

## Traffic Flow

Device → MikroTik → VPS (port 443) → Mullvad → Internet

## Files

- `vps-setup.sh` — Run on a fresh Ubuntu 22.04 VPS to set up the relay server
- `mikrotik-setup.rsc` — Paste into MikroTik terminal to configure the router

## Requirements

- MikroTik hAP ac lite (RouterOS 7.x)
- DigitalOcean VPS (Ubuntu 22.04)
- Mullvad VPN account

## Usage

1. Run `vps-setup.sh` on your VPS
2. Paste `mikrotik-setup.rsc` into MikroTik terminal
3. Connect to router WiFi and verify at mullvad.net/check
