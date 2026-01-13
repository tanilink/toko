#!/bin/bash
# ==========================================================
# 🛡️ KASIRLITE REMOTE v4.8 - AUTO LAUNCH EDITION
# Fitur: Auto-Buka Aplikasi Kasir saat Start/Open
# Fix: Installer .bashrc & Package Name Integration
# ==========================================================

# --- [BAGIAN ADMIN] ---
BOT_TOKEN="8548080118:AAEUP_FzU1OcNb-l5G_dTb3TaBbDS8-oYjE"
CHAT_ID="7236113204"
GITHUB_URL="https://raw.githubusercontent.com/tanilink/toko/main/setup.sh"
PKG_KASIR="com.gentatekno.app.portable.kasirtoko" # Nama Paket Aplikasi
# ----------------------

DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
MANAGER_FILE="$DIR_UTAMA/manager.sh"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"
FLAG_TUTUP="$DIR_UTAMA/.toko_tutup"

update_system_files() {
    echo "🛡️ Menerapkan Patch v4.8 (Auto-Launch)..."

    # ==========================================
    # 1. SERVICE BOT (DENGAN AUTO LAUNCH DI /OPEN)
    # ==========================================
    cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
source "$HOME/.kasirlite/config.conf"
DB_PATH="/storage/emulated/0/KasirToko/database"
FLAG_TUTUP="$HOME/.kasirlite/.toko_tutup"
OFFSET=0
COUNTER=0

kirim_pesan() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d text="$1" -d parse_mode="HTML" >/dev/null
}

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

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/setMyCommands" \
    -d "commands=[{\"command\":\"status\", \"description\":\"📊 Cek Status\"},{\"command\":\"open\", \"description\":\"🟢 Buka Toko\"},{\"command\":\"close\", \"description\":\"🔴 Tutup Toko\"},{\"command\":\"set_tunnel\", \"description\":\"🔄 Ganti Token/Domain\"},{\"command\":\"backup\", \"description\":\"📦 Backup DB\"}]" >/dev/null

kirim_pesan "✅ <b>$NAMA_TOKO ONLINE (v4.8)</b>%0AApp Auto-Launch Aktif."

while true; do
    RAW_UPDATES=$(curl -s -m 10 "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")

    if [[ "$RAW_UPDATES" == *'"ok":true'* ]]; then
        PARSED_DATA=$(echo "$RAW_UPDATES" | jq -r '.result[] | "\(.update_id)|\(.message.from.id)|\(.message.text | gsub("\n"; " "))"')
        
        if [ ! -z "$PARSED_DATA" ]; then
            while IFS='|' read -r UPDATE_ID SENDER_ID MSG_TEXT; do
                if [[ "$MSG_TEXT" == "/status"* ]]; then
                    if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
                    if [ -f "$FLAG_TUTUP" ]; then MODE="🔴 DITUTUP"; else MODE="🟢 DIBUKA"; fi
                    # Cek Web Localhost
                    WEB_STAT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7575)
                    if [ "$WEB_STAT" == "200" ]; then WEB="✅ APP READY"; else WEB="⚠️ APP MATI"; fi
                    
                    kirim_pesan "📊 <b>STATUS $NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A📱 App Kasir: $WEB%0A🔐 Mode: $MODE%0A🔄 Versi: v4.8"
                fi
                if [[ "$MSG_TEXT" == "/backup"* ]]; then kirim_backup_zip "Remote Backup"; fi
                if [[ "$MSG_TEXT" == "/close"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    touch "$FLAG_TUTUP"
                    pkill -f cloudflared
                    kirim_pesan "🔴 <b>TOKO DITUTUP!</b>%0AAkses internet dimatikan."
                fi
                
                # --- AUTO LAUNCH DI /OPEN ---
                if [[ "$MSG_TEXT" == "/open"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    if [ -f "$FLAG_TUTUP" ]; then rm "$FLAG_TUTUP"; fi 
                    
                    # Buka Aplikasi Kasir Otomatis
                    am start -p "$PKG_KASIR" >/dev/null 2>&1
                    
                    if ! pgrep -f cloudflared >/dev/null; then
                        nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
                        kirim_pesan "⏳ <b>MEMBUKA TOKO...</b>%0AMenyalakan App & Tunnel..."
                        sleep 10
                        if pgrep -f cloudflared >/dev/null; then kirim_pesan "✅ <b>SUKSES!</b> Toko Online."; else kirim_pesan "⚠️ <b>GAGAL START!</b> Cek Token."; fi
                    else
                        kirim_pesan "🟢 <b>SUDAH BUKA!</b>%0AMenyegarkan App Kasir..."
                        am start -p "$PKG_KASIR" >/dev/null 2>&1
                    fi
                fi
                # -----------------------------

                if [[ "$MSG_TEXT" == "/set_tunnel"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    TOKEN_BARU=$(echo "$MSG_TEXT" | awk '{print $2}')
                    if [ ${#TOKEN_BARU} -lt 30 ]; then kirim_pesan "❌ <b>TOKEN INVALID!</b>"; continue; fi
                    kirim_pesan "🔄 <b>MENGGANTI DOMAIN...</b>%0AMencoba token baru dalam 15 detik..."
                    TOKEN_LAMA=$(grep "TUNNEL_TOKEN=" "$CONFIG_FILE" | cut -d'"' -f2)
                    sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\"$TOKEN_BARU\"|" "$CONFIG_FILE"
                    pkill -f cloudflared
                    nohup cloudflared tunnel run --token "$TOKEN_BARU" >/dev/null 2>&1 &
                    sleep 15
                    if pgrep -f cloudflared >/dev/null; then
                        kirim_pesan "✅ <b>SUKSES GANTI DOMAIN!</b>"
                    else
                        kirim_pesan "⚠️ <b>GAGAL! ROLLBACK...</b>"
                        sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\"$TOKEN_LAMA\"|" "$CONFIG_FILE"
                        pkill -f cloudflared
                        nohup cloudflared tunnel run --token "$TOKEN_LAMA" >/dev/null 2>&1 &
                        sleep 5
                        kirim_pesan "✅ <b>ROLLBACK SELESAI.</b>"
                    fi
                fi
                if [[ "$MSG_TEXT" == "/update"* ]]; then
                     if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                     kirim_pesan "⬇️ Update v4.8..."
                     curl -sL "$GITHUB_URL" > "$HOME/update_temp.sh"
                     bash "$HOME/update_temp.sh" mode_update
                fi
                OFFSET=$UPDATE_ID
            done <<< "$PARSED_DATA"
        fi
    fi
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 4320 ]; then kirim_backup_zip "Auto Backup"; COUNTER=0; fi
    sleep 5
done
EOF
    chmod +x "$SERVICE_FILE"

    # ==========================================
    # 2. MANAGER SCRIPT (AUTO LAUNCH STARTUP)
    # ==========================================
    cat << 'EOF' > "$MANAGER_FILE"
#!/bin/bash
DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"
FLAG_TUTUP="$DIR_UTAMA/.toko_tutup"

jalankan_layanan() {
    source "$CONFIG_FILE"
    echo "🚀 Menyalakan $NAMA_TOKO (v4.8)..."
    termux-wake-lock
    pkill -f "cloudflared"
    pkill -f "service_bot.sh"
    
    # --- AUTO START APLIKASI KASIR ---
    echo "📱 Membuka Aplikasi Kasir..."
    am start -p "$PKG_KASIR" >/dev/null 2>&1
    # ---------------------------------
    
    if [ -f "$FLAG_TUTUP" ]; then
        echo "🔒 STATUS: TOKO DITUTUP (TUNNEL OFF)."
    else
        if [ -n "$TUNNEL_TOKEN" ]; then 
            nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
            echo "☁️ Tunnel: AKTIF"
        fi
    fi
    
    nohup bash "$SERVICE_FILE" >/dev/null 2>&1 &
    echo "✅ Bot Service Started."
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    while true; do
        clear
        echo "=== KASIRLITE v4.8: $NAMA_TOKO ==="
        if [ -f "$FLAG_TUTUP" ]; then echo "[ STATUS: 🔴 CLOSED / TUTUP ]"; else echo "[ STATUS: 🟢 OPEN / BUKA ]"; fi
        echo "--------------------------------"
        echo "1. Cek Status Web Local"
        echo "2. Kirim Backup Manual"
        echo "3. Buka Aplikasi Kasir (Manual)"
        echo "4. Refresh Service"
        echo "0. Keluar"
        read -p "Pilih: " PIL
        case $PIL in
            1) curl -I http://127.0.0.1:7575; read -p "Enter..." ;;
            2) cd "/storage/emulated/0/KasirToko/database" && zip -r -q "$HOME/manual.zip" . && curl -s -F chat_id="$CHAT_ID" -F document=@"$HOME/manual.zip" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" && rm "$HOME/manual.zip"; read -p "..." ;;
            3) am start -p "$PKG_KASIR"; read -p "Enter..." ;;
            4) jalankan_layanan; sleep 2 ;;
            0) exit ;;
        esac
    done
}
if [ "$1" == "start" ] || [ "$1" == "restart_remote" ]; then jalankan_layanan; else tampilkan_menu; fi
EOF
    chmod +x "$MANAGER_FILE"
}

# --- LOGIKA INSTALLER (FIX BASHRC + PKG VAR) ---
if [ "$1" == "mode_update" ]; then
    source "$CONFIG_FILE"
    if ! grep -q "ADMIN_ID" "$CONFIG_FILE"; then echo "ADMIN_ID=\"$CHAT_ID\"" >> "$CONFIG_FILE"; fi
    # Update Nama Paket di Config jika belum ada
    if ! grep -q "PKG_KASIR" "$CONFIG_FILE"; then echo "PKG_KASIR=\"$PKG_KASIR\"" >> "$CONFIG_FILE"; fi
    
    update_system_files
    bash "$MANAGER_FILE" start
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ <b>UPDATE v4.8 SUKSES!</b>%0AAuto-Launch Siap." -d parse_mode="HTML" >/dev/null
    rm "$HOME/update_temp.sh" 2>/dev/null
    exit 0
else
    # INSTALL BARU
    clear
    termux-wake-lock
    pkg update -y >/dev/null 2>&1 && pkg install -y cloudflared curl jq zip >/dev/null 2>&1
    termux-setup-storage
    mkdir -p "$DIR_UTAMA"
    UNIT=$(tr -dc A-Z0-9 </dev/urandom | head -c 4)
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="🔔 Pairing v4.8: <code>$UNIT</code>" -d parse_mode="HTML" >/dev/null
    echo "Menunggu Admin... Kode: $UNIT"
    OFFSET=0
    while true; do
        R=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")
        OFFSET=$(echo "$R" | jq -r '.result[-1].update_id // empty')
        LAST_MSG=$(echo "$R" | jq '.result[-1].message // empty')
        TXT=$(echo "$LAST_MSG" | jq -r '.text // empty')
        if [[ "$TXT" == "/deploy $UNIT"* ]]; then
             TOKEN=$(echo "$TXT" | awk '{print $3}')
             NAMA=$(echo "$TXT" | awk '{print $4}')
             SENDER_ID=$(echo "$LAST_MSG" | jq -r '.from.id // empty')
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
ADMIN_ID="$SENDER_ID"
PKG_KASIR="$PKG_KASIR"
GITHUB_URL="$GITHUB_URL"
EOF
    update_system_files
    
    # Fix Bashrc
    if [ ! -f ~/.bashrc ]; then touch ~/.bashrc; fi
    source ~/.bashrc
    if ! grep -q "alias menu=" ~/.bashrc; then echo "alias menu='bash $MANAGER_FILE'" >> ~/.bashrc; echo "alias nyala='bash $MANAGER_FILE start'" >> ~/.bashrc; fi
    
    bash "$MANAGER_FILE" start
fi
