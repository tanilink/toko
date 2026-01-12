#!/bin/bash
# ==========================================================
# 🚀 KASIRLITE REMOTE v4.2 - SYNTAX FIXED
# Fitur: Fix Syntax Error (&;), Force Menu, Anti-Hang
# ==========================================================

# --- [BAGIAN ADMIN: ISI INI DULU] ---
BOT_TOKEN="8548080118:AAEUP_FzU1OcNb-l5G_dTb3TaBbDS8-oYjE"
CHAT_ID="7236113204"
GITHUB_URL="https://raw.githubusercontent.com/tanilink/toko/main/setup.sh"
# ------------------------------------

DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
MANAGER_FILE="$DIR_UTAMA/manager.sh"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"

update_system_files() {
    echo "💾 Memperbarui File Sistem..."

    # 1. TULIS SERVICE BOT
    cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
source "$HOME/.kasirlite/config.conf"
DB_PATH="/storage/emulated/0/KasirToko/database"
OFFSET=0
COUNTER=0

# A. PAKSA TOMBOL MENU MUNCUL
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/setMyCommands" \
    -d "commands=[{\"command\":\"status\", \"description\":\"📊 Cek Koneksi\"},{\"command\":\"backup\", \"description\":\"📦 Ambil Database\"},{\"command\":\"msg\", \"description\":\"💬 Kirim Pesan\"},{\"command\":\"restart\", \"description\":\"🔄 Restart\"},{\"command\":\"update\", \"description\":\"⬇️ Update Script\"}]" >/dev/null

# B. KIRIM BACKUP
kirim_backup_zip() {
    local TYPE=$1
    local TIMESTAMP=$(date +%Y%m%d-%H%M)
    local ZIP_NAME="Backup_${NAMA_TOKO}_${TIMESTAMP}.zip"
    if [ -d "$DB_PATH" ]; then
        cd "$DB_PATH" && zip -r -q "$HOME/$ZIP_NAME" . 
        if [ -f "$HOME/$ZIP_NAME" ]; then
            curl -s -F chat_id="$CHAT_ID" -F document=@"$HOME/$ZIP_NAME" \
            -F caption="📦 $TYPE: $NAMA_TOKO" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
            rm -f "$HOME/$ZIP_NAME"
        fi
    fi
}

# C. LAPOR ONLINE
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" -d text="✅ <b>$NAMA_TOKO ONLINE (v4.2)</b>%0A🚀 Sistem Normal & Menu Aktif" -d parse_mode="HTML" >/dev/null

# D. LOOP LISTENER
while true; do
    UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")
    NEW_OFFSET=$(echo "$UPDATES" | jq -r '.result[-1].update_id // empty')
    
    if [ ! -z "$NEW_OFFSET" ]; then 
        OFFSET=$NEW_OFFSET
        MSG=$(echo "$UPDATES" | jq -r '.result[-1].message.text // empty')
        
        if [[ "$MSG" == "/status"* ]]; then
            if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                -d chat_id="$CHAT_ID" -d text="📊 <b>STATUS $NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A🟢 Bot: Aktif" -d parse_mode="HTML" >/dev/null
        fi

        if [[ "$MSG" == "/backup"* ]]; then kirim_backup_zip "Remote Backup"; fi

        if [[ "$MSG" == "/restart"* ]]; then
             curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="🔄 Restarting Service..." >/dev/null
             bash "$HOME/.kasirlite/manager.sh" restart_remote &
        fi

        if [[ "$MSG" == "/msg"* ]]; then
            ISI=$(echo "$MSG" | sed 's/\/msg //')
            timeout 1s termux-toast "$ISI" 2>/dev/null
            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ Pesan Tampil." >/dev/null
        fi

        if [[ "$MSG" == "/update"* ]]; then
             curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="⬇️ Updating Script..." >/dev/null
             curl -sL "$GITHUB_URL" > "$HOME/update_temp.sh"
             bash "$HOME/update_temp.sh" mode_update
        fi
    fi

    # AUTO BACKUP
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 4320 ]; then kirim_backup_zip "Auto Backup"; COUNTER=0; fi
    sleep 5
done
EOF
    chmod +x "$SERVICE_FILE"

    # 2. TULIS MANAGER SCRIPT (FIXED SYNTAX)
    cat << 'EOF' > "$MANAGER_FILE"
#!/bin/bash
DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"

jalankan_layanan() {
    source "$CONFIG_FILE"
    echo "🚀 Menyalakan $NAMA_TOKO..."
    termux-wake-lock
    
    pkill -f "cloudflared"
    pkill -f "service_bot.sh"
    
    # FIX SYNTAX: Dipisah baris agar aman
    if [ -n "$TUNNEL_TOKEN" ]; then
        nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
    fi
    
    nohup bash "$SERVICE_FILE" >/dev/null 2>&1 &
    echo "✅ Service Started."
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    while true; do
        clear
        echo "=== KASIRLITE v4.2: $NAMA_TOKO ==="
        echo "1. Cek Status"
        echo "2. Backup ZIP"
        echo "3. Refresh Sistem"
        echo "0. Keluar"
        read -p "Pilih: " PIL
        case $PIL in
            1) curl -I http://127.0.0.1:7575; read -p "Enter..." ;;
            2) 
               echo "Backup ZIP..."
               cd "/storage/emulated/0/KasirToko/database" && zip -r -q "$HOME/manual.zip" .
               curl -s -F chat_id="$CHAT_ID" -F document=@"$HOME/manual.zip" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
               rm "$HOME/manual.zip"
               read -p "Enter..." ;;
            3) jalankan_layanan; sleep 2 ;;
            0) exit ;;
        esac
    done
}

if [ "$1" == "start" ] || [ "$1" == "restart_remote" ]; then 
    jalankan_layanan
else 
    tampilkan_menu
fi
EOF
    chmod +x "$MANAGER_FILE"
}

# --- LOGIKA INSTALASI ---

if [ "$1" == "mode_update" ]; then
    # MODE UPDATE
    source "$CONFIG_FILE"
    update_system_files
    bash "$MANAGER_FILE" start
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ <b>UPDATE v4.2 BERHASIL!</b>" -d parse_mode="HTML" >/dev/null
    rm "$HOME/update_temp.sh" 2>/dev/null
    exit 0
else
    # MODE INSTALL BARU
    clear
    termux-wake-lock
    pkg update -y >/dev/null 2>&1 && pkg install -y cloudflared curl jq termux-api zip >/dev/null 2>&1
    termux-setup-storage
    mkdir -p "$DIR_UTAMA"
    
    UNIT=$(tr -dc A-Z0-9 </dev/urandom | head -c 4)
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="🔔 Kode: <code>$UNIT</code>" -d parse_mode="HTML" >/dev/null
    echo "Menunggu Admin... Kode: $UNIT"
    
    OFFSET=0
    while true; do
        R=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")
        OFFSET=$(echo "$R" | jq -r '.result[-1].update_id // empty')
        TXT=$(echo "$R" | jq -r '.result[-1].message.text // empty')
        if [[ "$TXT" == "/deploy $UNIT"* ]]; then
             TOKEN=$(echo "$TXT" | awk '{print $3}')
             NAMA=$(echo "$TXT" | awk '{print $4}')
             [ -z "$NAMA" ] && NAMA="Cabang-$UNIT"
             break
        fi
        sleep 2
    done
    
    cat <<EOF > "$CONFIG_FILE"
NAMA_TOKO="$NAMA"
TUNNEL_TOKEN="$TOKEN"
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
GITHUB_URL="$GITHUB_URL"
EOF
    update_system_files
    source ~/.bashrc
    echo "alias menu='bash $MANAGER_FILE'" >> ~/.bashrc
    echo "alias nyala='bash $MANAGER_FILE start'" >> ~/.bashrc
    bash "$MANAGER_FILE" start
fi
