#!/bin/bash
# ==========================================================
# 🛡️ KASIRLITE REMOTE v4.6.1 - LOOP FIX
# Fix: Perintah /open tidak lagi mematikan bot (Anti-Bootloop)
# ==========================================================

# --- [BAGIAN ADMIN] ---
BOT_TOKEN="8548080118:AAEUP_FzU1OcNb-l5G_dTb3TaBbDS8-oYjE"
CHAT_ID="7236113204"
GITHUB_URL="https://raw.githubusercontent.com/tanilink/toko/main/setup.sh"
# ----------------------

DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
MANAGER_FILE="$DIR_UTAMA/manager.sh"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"
FLAG_TUTUP="$DIR_UTAMA/.toko_tutup"

update_system_files() {
    echo "🛡️ Menerapkan Patch v4.6.1 (Fix Loop)..."

    # ==========================================
    # 1. SERVICE BOT (LOGIKA FIX DI BAGIAN /OPEN)
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
    -d "commands=[{\"command\":\"status\", \"description\":\"📊 Cek Status\"},{\"command\":\"open\", \"description\":\"🟢 Buka Toko\"},{\"command\":\"close\", \"description\":\"🔴 Tutup Toko\"},{\"command\":\"backup\", \"description\":\"📦 Backup DB\"},{\"command\":\"cek\", \"description\":\"🔍 Cek Terminal\"}]" >/dev/null

kirim_pesan "✅ <b>$NAMA_TOKO ONLINE (v4.6.1)</b>%0AAnti-Loop Fixed."

while true; do
    RAW_UPDATES=$(curl -s -m 10 "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")

    if [[ "$RAW_UPDATES" == *'"ok":true'* ]]; then
        PARSED_DATA=$(echo "$RAW_UPDATES" | jq -r '.result[] | "\(.update_id)|\(.message.from.id)|\(.message.text | gsub("\n"; " "))"')
        
        if [ ! -z "$PARSED_DATA" ]; then
            while IFS='|' read -r UPDATE_ID SENDER_ID MSG_TEXT; do
                
                # --- A. STATUS ---
                if [[ "$MSG_TEXT" == "/status"* ]]; then
                    if pgrep -f cloudflared >/dev/null; then CF="✅ ON (Online)"; else CF="❌ OFF (Offline)"; fi
                    if [ -f "$FLAG_TUTUP" ]; then MODE="🔴 DITUTUP (Manual)"; else MODE="🟢 DIBUKA"; fi
                    kirim_pesan "📊 <b>STATUS $NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A🔐 Mode: $MODE%0A🛡️ Versi: v4.6.1"
                fi

                # --- B. BACKUP ---
                if [[ "$MSG_TEXT" == "/backup"* ]]; then kirim_backup_zip "Remote Backup"; fi

                # --- C. ADMIN ONLY ---
                
                # 1. CLOSE
                if [[ "$MSG_TEXT" == "/close"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    touch "$FLAG_TUTUP"
                    pkill -f cloudflared
                    kirim_pesan "🔴 <b>TOKO DITUTUP!</b>%0AAkses internet dimatikan."
                fi

                # 2. OPEN (BAGIAN YANG DIPERBAIKI)
                if [[ "$MSG_TEXT" == "/open"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    
                    # Hapus flag tutup
                    if [ -f "$FLAG_TUTUP" ]; then rm "$FLAG_TUTUP"; fi 
                    
                    # Cek Tunnel: Jika mati, nyalakan. Jika hidup, biarkan.
                    # JANGAN PANGGIL MANAGER RESTART (Karena itu membunuh bot)
                    if ! pgrep -f cloudflared >/dev/null; then
                        nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
                        kirim_pesan "🟢 <b>TOKO DIBUKA!</b>%0AMenyalakan tunnel..."
                    else
                        kirim_pesan "🟢 <b>TOKO SUDAH BUKA!</b>%0ATunnel sudah aktif sebelumnya."
                    fi
                fi

                # 3. CEK
                if [[ "$MSG_TEXT" == "/cek"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then kirim_pesan "⛔ Ditolak."; continue; fi
                    CMD_SHELL=$(echo "$MSG_TEXT" | sed 's/\/cek //')
                    if [[ "$CMD_SHELL" == *"rm "* ]] || [[ "$CMD_SHELL" == *"mv "* ]] || \
                       [[ "$CMD_SHELL" == *"reboot"* ]] || [[ "$CMD_SHELL" == *">"* ]] || \
                       [[ "$CMD_SHELL" == *";"* ]] || [[ "$CMD_SHELL" == *"|"* ]]; then
                        kirim_pesan "⚠️ Command Dangerous."; continue
                    fi
                    kirim_pesan "🔍 Cek: <code>$CMD_SHELL</code>"
                    HASIL=$(timeout 5s bash -c "$CMD_SHELL" 2>&1 | head -c 2000)
                    if [ -z "$HASIL" ]; then HASIL="(Kosong)"; fi
                    kirim_pesan "<pre>$HASIL</pre>"
                fi

                # 4. SET TUNNEL
                if [[ "$MSG_TEXT" == "/set_tunnel"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    TOKEN_BARU=$(echo "$MSG_TEXT" | awk '{print $2}')
                    if [ ${#TOKEN_BARU} -lt 30 ]; then kirim_pesan "❌ Token Invalid"; continue; fi
                    kirim_pesan "🔄 Ganti Tunnel..."
                    TOKEN_LAMA=$(grep "TUNNEL_TOKEN=" "$CONFIG_FILE" | cut -d'"' -f2)
                    sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\"$TOKEN_BARU\"|" "$CONFIG_FILE"
                    
                    # Khusus ini kita restart bot tidak apa-apa karena jarang dipakai
                    bash "$HOME/.kasirlite/manager.sh" restart_remote &
                    
                    sleep 15
                    if pgrep -f cloudflared >/dev/null; then
                        kirim_pesan "✅ Sukses Ganti Domain."
                    else
                        kirim_pesan "⚠️ Gagal! Revert..."
                        sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\"$TOKEN_LAMA\"|" "$CONFIG_FILE"
                        bash "$HOME/.kasirlite/manager.sh" restart_remote &
                    fi
                fi

                # 5. UPDATE
                if [[ "$MSG_TEXT" == "/update"* ]]; then
                     if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                     kirim_pesan "⬇️ Update v4.6.1..."
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
    # 2. MANAGER SCRIPT (SAMA, NO CHANGE)
    # ==========================================
    cat << 'EOF' > "$MANAGER_FILE"
#!/bin/bash
DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"
FLAG_TUTUP="$DIR_UTAMA/.toko_tutup"

jalankan_layanan() {
    source "$CONFIG_FILE"
    echo "🚀 Menyalakan $NAMA_TOKO (v4.6.1)..."
    termux-wake-lock
    pkill -f "cloudflared"
    pkill -f "service_bot.sh"
    
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
        echo "=== KASIRLITE v4.6.1: $NAMA_TOKO ==="
        if [ -f "$FLAG_TUTUP" ]; then echo "[ STATUS: 🔴 CLOSED / TUTUP ]"; else echo "[ STATUS: 🟢 OPEN / BUKA ]"; fi
        echo "--------------------------------"
        echo "1. Cek Status Web Local"
        echo "2. Kirim Backup Manual"
        echo "3. Refresh Service"
        echo "0. Keluar"
        read -p "Pilih: " PIL
        case $PIL in
            1) curl -I http://127.0.0.1:7575; read -p "Enter..." ;;
            2) cd "/storage/emulated/0/KasirToko/database" && zip -r -q "$HOME/manual.zip" . && curl -s -F chat_id="$CHAT_ID" -F document=@"$HOME/manual.zip" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" && rm "$HOME/manual.zip"; read -p "..." ;;
            3) jalankan_layanan; sleep 2 ;;
            0) exit ;;
        esac
    done
}
if [ "$1" == "start" ] || [ "$1" == "restart_remote" ]; then jalankan_layanan; else tampilkan_menu; fi
EOF
    chmod +x "$MANAGER_FILE"
}

# --- LOGIKA UTAMA ---
if [ "$1" == "mode_update" ]; then
    source "$CONFIG_FILE"
    if ! grep -q "ADMIN_ID" "$CONFIG_FILE"; then echo "ADMIN_ID=\"$CHAT_ID\"" >> "$CONFIG_FILE"; fi
    update_system_files
    bash "$MANAGER_FILE" start
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ <b>UPDATE v4.6.1 SUKSES!</b>%0ALoop Fixed." -d parse_mode="HTML" >/dev/null
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
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="🔔 Pairing v4.6.1: <code>$UNIT</code>" -d parse_mode="HTML" >/dev/null
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
GITHUB_URL="$GITHUB_URL"
EOF
    update_system_files
    source ~/.bashrc
    if ! grep -q "alias menu=" ~/.bashrc; then echo "alias menu='bash $MANAGER_FILE'" >> ~/.bashrc; echo "alias nyala='bash $MANAGER_FILE start'" >> ~/.bashrc; fi
    bash "$MANAGER_FILE" start
fi
