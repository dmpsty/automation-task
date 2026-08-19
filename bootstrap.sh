#!/usr/bin/env bash
# ==============================================================================
# SCRIPT 1	: BOOTSTRAP & PRE-INSTALLATION DEPENDENCIES
# Author    : Damay Prasetya
# OS	   	: AlmaLinux 10
# Spek VPS 	: 2GB RAM / 2 vCPU / 20GB Storage
# ==============================================================================

set -euo pipefail

# --- DEFINISI VARIABEL REPOSITORY GITHUB | SESUAIKAN DENGAN TASK ---
GITHUB_REPO_URL="https://github.com/dmpsty/automation-task.git"
DEST_DIR="/home/damay/automation-test"

echo "=== [SECTION 1] Update System & Install EPEL Repository ==="
dnf update -y
dnf install -y epel-release curl wget git tar unzip policycoreutils-python-utils iptables-services

echo "=== [SECTION 2] Clone Main Script Repository ==="
if [ -d "$DEST_DIR" ]; then
    echo "[-] Direktori $DEST_DIR sudah ada. Melakukan git pull..."
    cd "$DEST_DIR" && git pull
else
    echo "[+] Cloning repository dari $GITHUB_REPO_URL ..."
    git clone "$GITHUB_REPO_URL" "$DEST_DIR"
fi

echo "=== [SECTION 3] Menyiapkan Izin Eksekusi Main Script ==="
chmod +x "$DEST_DIR/main_setup.sh"

echo "[SUCCESS] Inisialisasi selesai. Silakan jalankan script utama:"
# --- SESUAIKAN DAN PASTIKAN ISI FILE main_setup.sh SUDAH AMAN TERLEBIH DAHULU SEBELUM MENGEKSEKUSINYA ---
# echo "cd $DEST_DIR && ./main_setup.sh"
