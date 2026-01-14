#!/bin/bash
# ==========================================================
# 🛡️ KASIRLITE REMOTE v5.2 - GROUP DASHBOARD
# Fitur: Support Multi-Bot dalam 1 Grup Telegram
# Command Baru: /set_group (Pindah laporan ke Grup)
# ==========================================================

# --- [BAGIAN ADMIN] ---
BOT_TOKEN="8548080118:AAEUP_FzU1OcNb-l5G_dTb3TaBbDS8-oYjE"
CHAT_ID="7236113204" # Awalnya Private, nanti berubah jadi Group ID
GITHUB_URL="https://raw.githubusercontent.com/tanilink/toko/main/setup.sh"
# ----------------------

DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
MANAGER_FILE="$DIR_UTAMA/manager.sh"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"
FLAG_TUTUP="$DIR_UTAMA/.toko_tutup"

update_system_files() {
    echo "🛡️ Menerapkan Patch v5.2 (Group Support)..."

    # ==========================================
    # 1. SERVICE BOT (GROUP AWARE)
    # ==========================================
    cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
source "$HOME/.kasirlite/config.conf"
DB_PATH="/storage/emulated/0/KasirToko/database"
FLAG_TUTUP="$HOME/.kasirlite/.toko_tutup"
OFFSET=0
COUNTER=0

kirim_pesan() {
    # Di Grup, kita tidak pakai tombol keyboard bawah (mengganggu)
    # Kita pakai Inline Button (menempel di pesan) khusus untuk Grup
    
    # Cek jika CHAT_ID adalah Grup (diawali tanda -)
    if [[ "$CHAT_ID" == "-"* ]]; then
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d chat_id="$CHAT_ID" -d text="$1" -d parse_mode="HTML" >/dev/null
    else
        # Jika Private Chat, pakai Keyboard Button
        KEYBOARD='{"keyboard":[[{"text":"📊 Cek Status"},{"text":"📦 Backup DB"}],[{"text":"🟢 Buka Toko"},{"text":"🔴 Tutup Toko"}],[{"text":"🔄 Ganti Domain"}]],"resize_keyboard":true,"is_persistent":true}'
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d chat_id="$CHAT_ID" -d text="$1" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" >/dev/null
    fi
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

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/deleteMyCommands" >/dev/null
kirim_pesan "✅ <b>$NAMA_TOKO ONLINE (v5.2)</b>%0AGroup Support Ready."

while true; do
    RAW_UPDATES=$(curl -s -m 10 "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")

    if [[ "$RAW_UPDATES" == *'"ok":true'* ]]; then
        # PARSING: Ambil Chat ID asal pesan (Bisa Group, Bisa Private)
        PARSED_DATA=$(echo "$RAW_UPDATES" | jq -r '.result[] | "\(.update_id)|\(.message.from.id)|\(.message.chat.id)|\(.message.text | gsub("\n"; " "))"')
        
        if [ ! -z "$PARSED_DATA" ]; then
            while IFS='|' read -r UPDATE_ID SENDER_ID CHAT_ORIGIN MSG_TEXT; do
                
                # --- A. FITUR PINDAH KE GRUP (SET GROUP) ---
                if [[ "$MSG_TEXT" == "/set_group"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    
                    # Ubah CHAT_ID di Config menjadi ID Grup ini
                    sed -i "s|^CHAT_ID=.*|CHAT_ID=\"$CHAT_ORIGIN\"|" "$CONFIG_FILE"
                    
                    # Refresh variable memori saat ini
                    CHAT_ID="$CHAT_ORIGIN"
                    
                    kirim_pesan "🏢 <b>DASHBOARD AKTIF!</b>%0A$NAMA_TOKO sekarang melapor ke Grup ini."
                fi

                # --- B. STATUS ---
                if [[ "$MSG_TEXT" == "📊 Cek Status"* ]] || [[ "$MSG_TEXT" == "/status"* ]]; then
                    if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
                    if [ -f "$FLAG_TUTUP" ]; then MODE="🔴 TUTUP"; else MODE="🟢 BUKA"; fi
                    WEB_STAT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7575)
                    if [ "$WEB_STAT" == "200" ]; then WEB="✅ READY"; else WEB="⚠️ MATI"; fi
                    
                    # Jika di Grup, tampilkan nama toko tebal agar mudah dibaca
                    kirim_pesan "📍 <b>$NAMA_TOKO</b>%0A☁️ $CF | 📱 $WEB | 🔐 $MODE"
                fi

                # --- C. CONTROL (Hanya Admin) ---
                if [[ "$MSG_TEXT" == "🔴 Tutup Toko"* ]] || [[ "$MSG_TEXT" == "/close"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    touch "$FLAG_TUTUP"
                    pkill -f cloudflared
                    kirim_pesan "🔴 <b>$NAMA_TOKO DITUTUP!</b>"
                fi

                if [[ "$MSG_TEXT" == "🟢 Buka Toko"* ]] || [[ "$MSG_TEXT" == "/open"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    if [ -f "$FLAG_TUTUP" ]; then rm "$FLAG_TUTUP"; fi 
                    if ! pgrep -f cloudflared >/dev/null; then
                        nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
                        kirim_pesan "⏳ <b>$NAMA_TOKO MENYALA...</b>%0ABuka App Kasir Manual!"
                    else
                        kirim_pesan "🟢 <b>$NAMA_TOKO SUDAH BUKA!</b>"
                    fi
                fi

                # --- D. SETUP LAINNYA ---
                if [[ "$MSG_TEXT" == "/backup"* ]]; then kirim_backup_zip "Manual"; fi
                
                if [[ "$MSG_TEXT" == "/set_tunnel"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    TOKEN_BARU=$(echo "$MSG_TEXT" | awk '{print $2}')
                    sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\"$TOKEN_BARU\"|" "$CONFIG_FILE"
                    pkill -f cloudflared
                    nohup cloudflared tunnel run --token "$TOKEN_BARU" >/dev/null 2>&1 &
                    kirim_pesan "✅ $NAMA_TOKO Ganti Domain."
                fi

                if [[ "$MSG_TEXT" == "/ganti_bot"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    BOT_BARU=$(echo "$MSG_TEXT" | awk '{print $2}')
                    kirim_pesan "🔄 $NAMA_TOKO Pindah Bot..."
                    sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN=\"$BOT_BARU\"|" "$CONFIG_FILE"
                    # Reset CHAT_ID ke Admin dulu agar tidak error di bot baru
                    sed -i "s|^CHAT_ID=.*|CHAT_ID=\"$ADMIN_ID\"|" "$CONFIG_FILE"
                    nohup bash "$HOME/.kasirlite/manager.sh" restart_remote >/dev/null 2>&1 &
                    exit 0
                fi
                
                if [[ "$MSG_TEXT" == "/update"* ]]; then
                     if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                     kirim_pesan "⬇️ $NAMA_TOKO Updating..."
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
    # 2. MANAGER SCRIPT
    # ==========================================
    cat << 'EOF' > "$MANAGER_FILE"
#!/bin/bash
DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"
FLAG_TUTUP="$DIR_UTAMA/.toko_tutup"

jalankan_layanan() {
    source "$CONFIG_FILE"
    echo "🚀 Menyalakan $NAMA_TOKO (v5.2)..."
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
    echo "👉 INFO: Silakan BUKA APLIKASI KASIR secara manual."
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    while true; do
        clear
        echo "=== KASIRLITE v5.2: $NAMA_TOKO ==="
        echo "   [ GROUP SUPPORT READY ]"
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

# --- LOGIKA INSTALLER ---
if [ "$1" == "mode_update" ]; then
    source "$CONFIG_FILE"
    if [ ! -f ~/.bashrc ]; then touch ~/.bashrc; fi
    if ! grep -q "ADMIN_ID" "$CONFIG_FILE"; then echo "ADMIN_ID=\"$CHAT_ID\"" >> "$CONFIG_FILE"; fi
    update_system_files
    bash "$MANAGER_FILE" start
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ <b>UPDATE v5.2 SUKSES!</b>%0ASiap Masuk Grup." -d parse_mode="HTML" >/dev/null
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
    
    MSG="🔔 <b>PAIRING PERANGKAT BARU</b>%0AKode Unit: <code>$UNIT</code>%0A%0ASilakan Reply format:%0A<code>/deploy $UNIT [TOKEN] [NAMA_CABANG]</code>"
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$MSG" -d parse_mode="HTML" >/dev/null
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
    if [ ! -f ~/.bashrc ]; then touch ~/.bashrc; fi
    source ~/.bashrc
    if ! grep -q "alias menu=" ~/.bashrc; then echo "alias menu='bash $MANAGER_FILE'" >> ~/.bashrc; echo "alias nyala='bash $MANAGER_FILE start'" >> ~/.bashrc; fi
    bash "$MANAGER_FILE" start
fi
