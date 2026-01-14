#!/bin/bash
# ==========================================================
# 🛡️ KASIRLITE REMOTE v5.0 - MULTI-STORE MANAGER
# Fitur: Inline Buttons, Target Control, Multi-Device Support
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
    echo "🛡️ Menerapkan Patch v5.0 (Multi-Cabang)..."

    # ==========================================
    # 1. SERVICE BOT (DENGAN INLINE BUTTON & CALLBACK)
    # ==========================================
    cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
source "$HOME/.kasirlite/config.conf"
DB_PATH="/storage/emulated/0/KasirToko/database"
FLAG_TUTUP="$HOME/.kasirlite/.toko_tutup"
OFFSET=0
COUNTER=0

# ID Unik Toko (Hapus spasi agar aman untuk Callback Data)
TOKO_ID=$(echo "$NAMA_TOKO" | tr -d ' ')

kirim_pesan_inline() {
    local PESAN="$1"
    local TARGET="$2" # ID Toko Target
    
    # JSON Inline Keyboard (Tombol menempel di pesan)
    # Tombol berisi Callback Data: PERINTAH_IDTOKO
    KEYBOARD="{\"inline_keyboard\":[[{\"text\":\"🟢 BUKA\",\"callback_data\":\"open_$TARGET\"},{\"text\":\"🔴 TUTUP\",\"callback_data\":\"close_$TARGET\"}],[{\"text\":\"🔄 Cek Lagi\",\"callback_data\":\"status_$TARGET\"}]]}"

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$PESAN" \
        -d parse_mode="HTML" \
        -d reply_markup="$KEYBOARD" >/dev/null
}

kirim_menu_utama() {
    # Menu Bawah (Persistent) hanya untuk perintah Global
    KEYBOARD='{"keyboard":[[{"text":"📊 Cek Semua Toko"}],[{"text":"📦 Backup Semua"},{"text":"⬇️ Update Semua"}]],"resize_keyboard":true,"is_persistent":true}'
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d text="$1" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" >/dev/null
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

# Hapus command lama, ganti dengan Menu Utama
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/deleteMyCommands" >/dev/null
kirim_menu_utama "✅ <b>$NAMA_TOKO ONLINE (v5.0)</b>%0AMode Multi-Cabang Aktif."

while true; do
    RAW_UPDATES=$(curl -s -m 10 "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")

    if [[ "$RAW_UPDATES" == *'"ok":true'* ]]; then
        # PARSING BARU: Menghandle Pesan Biasa (msg) DAN Tombol Klik (call)
        PARSED_DATA=$(echo "$RAW_UPDATES" | jq -r '.result[] | if .callback_query then "call|\(.update_id)|\(.callback_query.from.id)|\(.callback_query.data)" else "msg|\(.update_id)|\(.message.from.id)|\(.message.text)" end')
        
        if [ ! -z "$PARSED_DATA" ]; then
            while IFS='|' read -r TIPE UPDATE_ID SENDER_ID ISI; do
                
                # JIKA PESAN TEKS BIASA (msg)
                if [[ "$TIPE" == "msg" ]]; then
                    # Bersihkan newline
                    ISI=$(echo "$ISI" | tr '\n' ' ')

                    # 1. CEK STATUS GLOBAL
                    if [[ "$ISI" == "📊 Cek Semua Toko"* ]] || [[ "$ISI" == "/status"* ]]; then
                        if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
                        if [ -f "$FLAG_TUTUP" ]; then MODE="🔴 DITUTUP"; else MODE="🟢 DIBUKA"; fi
                        WEB_STAT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7575)
                        if [ "$WEB_STAT" == "200" ]; then WEB="✅ READY"; else WEB="⚠️ MATI"; fi
                        
                        # Kirim pesan status KHUSUS toko ini, dengan tombol kendali KHUSUS toko ini
                        kirim_pesan_inline "🏢 <b>$NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A📱 App: $WEB%0A🔐 Mode: $MODE" "$TOKO_ID"
                    fi

                    # 2. BACKUP GLOBAL
                    if [[ "$ISI" == "📦 Backup Semua"* ]] || [[ "$ISI" == "/backup"* ]]; then
                        kirim_backup_zip "Backup Rutin"
                    fi
                    
                    # 3. UPDATE GLOBAL
                    if [[ "$ISI" == "⬇️ Update Semua"* ]] || [[ "$ISI" == "/update"* ]]; then
                         if [ "$SENDER_ID" == "$ADMIN_ID" ]; then
                             curl -sL "$GITHUB_URL" > "$HOME/update_temp.sh"
                             bash "$HOME/update_temp.sh" mode_update
                         fi
                    fi
                    
                    # 4. DEPLOY (Pairing)
                    if [[ "$ISI" == "/deploy"* ]]; then
                        # Bot akan diam, biarkan script installer yang menangkap
                        : 
                    fi
                fi

                # JIKA TOMBOL DIKLIK (call)
                if [[ "$TIPE" == "call" ]]; then
                    # Format Callback Data: PERINTAH_TARGETID
                    CMD=$(echo "$ISI" | cut -d'_' -f1)
                    TARGET=$(echo "$ISI" | cut -d'_' -f2)

                    # Cek apakah perintah ini untuk SAYA?
                    if [[ "$TARGET" == "$TOKO_ID" ]]; then
                        
                        # A. TOMBOL BUKA
                        if [[ "$CMD" == "open" ]]; then
                            if [ -f "$FLAG_TUTUP" ]; then rm "$FLAG_TUTUP"; fi
                            if ! pgrep -f cloudflared >/dev/null; then
                                nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
                                kirim_pesan_inline "⏳ <b>$NAMA_TOKO MENYALA...</b>%0A(Mohon Buka App Kasir Manual)" "$TOKO_ID"
                            else
                                kirim_pesan_inline "🟢 <b>$NAMA_TOKO SUDAH BUKA!</b>" "$TOKO_ID"
                            fi
                        fi

                        # B. TOMBOL TUTUP
                        if [[ "$CMD" == "close" ]]; then
                            touch "$FLAG_TUTUP"
                            pkill -f cloudflared
                            kirim_pesan_inline "🔴 <b>$NAMA_TOKO DITUTUP!</b>" "$TOKO_ID"
                        fi

                        # C. TOMBOL REFRESH STATUS
                        if [[ "$CMD" == "status" ]]; then
                            if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
                            if [ -f "$FLAG_TUTUP" ]; then MODE="🔴 DITUTUP"; else MODE="🟢 DIBUKA"; fi
                            WEB_STAT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7575)
                            if [ "$WEB_STAT" == "200" ]; then WEB="✅ READY"; else WEB="⚠️ MATI"; fi
                            kirim_pesan_inline "🏢 <b>$NAMA_TOKO</b> (Updated)%0A☁️ Tunnel: $CF%0A📱 App: $WEB%0A🔐 Mode: $MODE" "$TOKO_ID"
                        fi
                        
                        # Jawab Callback agar loading di tombol hilang
                        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/answerCallbackQuery" -d callback_query_id="$UPDATE_ID" >/dev/null
                    fi
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
    # 2. MANAGER SCRIPT (MANUAL MODE)
    # ==========================================
    cat << 'EOF' > "$MANAGER_FILE"
#!/bin/bash
DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"
FLAG_TUTUP="$DIR_UTAMA/.toko_tutup"

jalankan_layanan() {
    source "$CONFIG_FILE"
    echo "🚀 Menyalakan $NAMA_TOKO (v5.0)..."
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
    echo "👉 INFO: Silakan BUKA APLIKASI KASIR secara manual di layar."
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    while true; do
        clear
        echo "=== KASIRLITE v5.0: $NAMA_TOKO ==="
        echo "   [ MODE MULTI-CABANG ]"
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
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ <b>UPDATE v5.0 SUKSES!</b>%0AMulti-Device Ready." -d parse_mode="HTML" >/dev/null
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
    
    MSG="🔔 <b>PAIRING PERANGKAT BARU</b>%0AKode Unit: <code>$UNIT</code>%0A%0ASilakan Reply format:%0A<code>/deploy $UNIT [TOKEN] [NAMA_CABANG_TANPA_SPASI]</code>"
    
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
