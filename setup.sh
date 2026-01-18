#!/bin/bash
# ==========================================================
# 🛡️ KASIRLITE REMOTE v4.9 - DIAMOND (FIX BUTTON)
# Fitur: Tombol Broadcast Diperbaiki & Posisi Lebih Atas
# ==========================================================

# --- [KONFIGURASI PUSAT] ---
CHAT_ID="7236113204"
GITHUB_URL="https://raw.githubusercontent.com/tanilink/toko/main/setup.sh"
# ---------------------------

DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
MANAGER_FILE="$DIR_UTAMA/manager.sh"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"
FLAG_TUTUP="$DIR_UTAMA/.toko_tutup"

pasang_cronjob() {
    if ! pkg list-installed 2>/dev/null | grep -q "cronie"; then
        pkg install cronie termux-services -y >/dev/null 2>&1
        sv-enable crond >/dev/null 2>&1
    fi
    crontab -r 2>/dev/null
    echo "0 9 * * * bash $HOME/.kasirlite/manager.sh start" | crontab -
}

update_system_files() {
    echo "🛡️ Menerapkan Layout Diamond..."
    pasang_cronjob

    # ==========================================
    # 1. SERVICE BOT (LAYOUT BARU)
    # ==========================================
    cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
CONFIG_FILE="$HOME/.kasirlite/config.conf"
source "$CONFIG_FILE"

DB_PATH="/storage/emulated/0/KasirToko/database"
FLAG_TUTUP="$HOME/.kasirlite/.toko_tutup"
LOG_RESTART="$HOME/.kasirlite/.last_restart"
OFFSET=0

# --- FUNGSI KIRIM PESAN ---
kirim_pesan() {
    local TARGET_ID=$1
    local TEXT=$2
    local MODE_KEYBOARD=$3 
    
    # [1] KEYBOARD OWNER (Layout Diperbaiki)
    if [ "$MODE_KEYBOARD" == "MAIN_OWNER" ]; then
        KEYBOARD='{"keyboard":[
        [{"text":"📊 Cek Status"},{"text":"📦 Backup DB"}],
        [{"text":"🟢 Buka Toko"},{"text":"🔴 Tutup Toko"}],
        [{"text":"📢 Broadcast Pesan"},{"text":"➕ Manajemen Staff"}],
        [{"text":"🔄 Restart Service"},{"text":"⬇️ Update Sistem"}],
        [{"text":"🔐 Ganti Password"}]
        ],"resize_keyboard":true,"is_persistent":true}'
    
    # [2] KEYBOARD STAFF
    elif [ "$MODE_KEYBOARD" == "MAIN_STAFF" ]; then
        KEYBOARD='{"keyboard":[
        [{"text":"📊 Cek Status"},{"text":"📦 Backup DB"}],
        [{"text":"🔄 Restart Service"}]
        ],"resize_keyboard":true,"is_persistent":true}'
    
    # [3] SUB-MENU STAFF
    elif [ "$MODE_KEYBOARD" == "SUB_STAFF" ]; then
        KEYBOARD='{"keyboard":[
        [{"text":"✏️ Ganti Staff"},{"text":"🗑️ Hapus Staff"}],
        [{"text":"🔙 Kembali ke Menu Utama"}]
        ],"resize_keyboard":true,"is_persistent":true}'
        
    else
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d chat_id="$TARGET_ID" -d text="$TEXT" -d parse_mode="HTML" >/dev/null
        return
    fi

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$TARGET_ID" -d text="$TEXT" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" >/dev/null
}

kirim_backup_zip() {
    local TARGET=$1
    local TYPE=$2
    local TIMESTAMP=$(date +%Y%m%d-%H%M)
    local ZIP_NAME="Backup_${NAMA_TOKO}_${TIMESTAMP}.zip"
    if [ -d "$DB_PATH" ]; then
        cd "$DB_PATH" && zip -r -q "$HOME/$ZIP_NAME" . 
        if [ -f "$HOME/$ZIP_NAME" ]; then
            curl -s -F chat_id="$TARGET" -F document=@"$HOME/$ZIP_NAME" \
            -F caption="📦 $TYPE: $NAMA_TOKO" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
            rm -f "$HOME/$ZIP_NAME"
        fi
    fi
}

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/deleteMyCommands" >/dev/null
kirim_pesan "$ADMIN_ID" "✅ <b>$NAMA_TOKO ONLINE</b>%0ALayout Menu Diperbarui." "MAIN_OWNER"

while true; do
    RAW_UPDATES=$(curl -s -m 10 "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")

    if [[ "$RAW_UPDATES" == *'"ok":true'* ]]; then
        PARSED_DATA=$(echo "$RAW_UPDATES" | jq -r '.result[] | "\(.update_id)|\(.message.from.id)|\(.message.text | gsub("\n"; " ") | gsub("\""; ""))"')
        
        if [ ! -z "$PARSED_DATA" ]; then
            while IFS='|' read -r UPDATE_ID SENDER_ID MSG_TEXT; do
                
                # IDENTIFIKASI USER
                IS_OWNER=false; IS_STAFF=false
                if [ "$SENDER_ID" == "$ADMIN_ID" ]; then IS_OWNER=true;
                elif [ "$SENDER_ID" == "$STAFF_ID" ]; then IS_STAFF=true;
                else OFFSET=$UPDATE_ID; continue; fi

                # LOGIKA PERINTAH UMUM
                if [[ "$MSG_TEXT" == "📊 Cek Status"* ]] || [[ "$MSG_TEXT" == "/status"* ]]; then
                    if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
                    if [ -f "$FLAG_TUTUP" ]; then MODE="🔴 DITUTUP"; else MODE="🟢 DIBUKA"; fi
                    WEB_STAT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7575)
                    if [ "$WEB_STAT" == "200" ]; then WEB="✅ READY"; else WEB="⚠️ MATI"; fi
                    INFO="📊 <b>STATUS $NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A📱 App: $WEB%0A🔐 Mode: $MODE"
                    
                    if [ "$IS_OWNER" == "true" ]; then K_TYPE="MAIN_OWNER"; else K_TYPE="MAIN_STAFF"; fi
                    kirim_pesan "$SENDER_ID" "$INFO" "$K_TYPE"
                fi

                if [[ "$MSG_TEXT" == "📦 Backup DB"* ]] || [[ "$MSG_TEXT" == "/backup"* ]]; then 
                    kirim_backup_zip "$SENDER_ID" "Remote Backup"
                fi
                
                if [[ "$MSG_TEXT" == "🔄 Restart Service"* ]]; then
                    BOLEH=true
                    if [ "$IS_OWNER" == "false" ]; then
                        NOW=$(date +%s)
                        [ -f "$LOG_RESTART" ] && LAST=$(cat "$LOG_RESTART") || LAST=0
                        DIFF=$((NOW - LAST))
                        if [ $DIFF -lt 3600 ]; then
                            SISA=$(((3600 - DIFF) / 60))
                            kirim_pesan "$SENDER_ID" "⚠️ Tunggu $SISA menit lagi." "MAIN_STAFF"
                            BOLEH=false
                        else echo "$NOW" > "$LOG_RESTART"; fi
                    fi
                    
                    if [ "$BOLEH" == "true" ]; then
                         if [ "$IS_OWNER" == "true" ]; then K_TYPE="MAIN_OWNER"; else K_TYPE="MAIN_STAFF"; fi
                         kirim_pesan "$SENDER_ID" "🔄 <b>RESTARTING...</b>" "$K_TYPE"
                         curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((UPDATE_ID+1))" >/dev/null
                         nohup bash "$HOME/.kasirlite/manager.sh" start >/dev/null 2>&1 &
                    fi
                fi

                # LOGIKA OWNER
                if [ "$IS_OWNER" == "true" ]; then
                    if [[ "$MSG_TEXT" == "🔴 Tutup Toko"* ]]; then
                        touch "$FLAG_TUTUP"; pkill -f cloudflared
                        kirim_pesan "$SENDER_ID" "🔴 <b>TOKO DITUTUP!</b>" "MAIN_OWNER"
                    fi
                    if [[ "$MSG_TEXT" == "🟢 Buka Toko"* ]]; then
                        [ -f "$FLAG_TUTUP" ] && rm "$FLAG_TUTUP"
                        if ! pgrep -f cloudflared >/dev/null; then
                            nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
                            kirim_pesan "$SENDER_ID" "✅ <b>TUNNEL ONLINE!</b>" "MAIN_OWNER"
                        else
                            kirim_pesan "$SENDER_ID" "🟢 <b>SUDAH BUKA!</b>" "MAIN_OWNER"
                        fi
                    fi
                    if [[ "$MSG_TEXT" == "⬇️ Update Sistem"* ]]; then
                         kirim_pesan "$SENDER_ID" "⬇️ <b>FORCE UPDATE...</b>" "MAIN_OWNER"
                         curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((UPDATE_ID+1))" >/dev/null
                         curl -sL "$GITHUB_URL" > "$HOME/update_temp.sh"
                         bash "$HOME/update_temp.sh" mode_update
                    fi
                    if [[ "$MSG_TEXT" == "🔐 Ganti Password"* ]]; then kirim_pesan "$SENDER_ID" "ℹ️ Balas: <code>/set_password 123456</code>" "MAIN_OWNER"; fi
                    if [[ "$MSG_TEXT" == "/set_password"* ]]; then
                        NEW_P=$(echo "$MSG_TEXT" | awk '{print $2}')
                        sed -i "s|^MENU_PASSWORD=.*|MENU_PASSWORD=\"$NEW_P\"|" "$CONFIG_FILE"
                        kirim_pesan "$SENDER_ID" "✅ Pass diganti: $NEW_P" "MAIN_OWNER"
                    fi

                    # --- SUB MENU STAFF ---
                    if [[ "$MSG_TEXT" == "➕ Manajemen Staff"* ]]; then
                        CURR_STAFF=$(grep "STAFF_ID=" "$CONFIG_FILE" | cut -d'"' -f2)
                        if [ -z "$CURR_STAFF" ]; then INFO_S="❌ <b>KOSONG</b>"; else INFO_S="👤 ID: <code>$CURR_STAFF</code>"; fi
                        kirim_pesan "$SENDER_ID" "👥 <b>MANAJEMEN STAFF</b>%0A%0A$INFO_S" "SUB_STAFF"
                    fi
                    if [[ "$MSG_TEXT" == "🔙 Kembali ke Menu Utama"* ]]; then
                        kirim_pesan "$SENDER_ID" "🔙 Kembali." "MAIN_OWNER"
                    fi
                    if [[ "$MSG_TEXT" == "🗑️ Hapus Staff"* ]]; then
                        sed -i "s|^STAFF_ID=.*|STAFF_ID=\"\"|" "$CONFIG_FILE"
                        kirim_pesan "$SENDER_ID" "🗑️ <b>STAFF DIHAPUS!</b>" "SUB_STAFF"
                    fi
                    if [[ "$MSG_TEXT" == "✏️ Ganti Staff"* ]]; then
                        kirim_pesan "$SENDER_ID" "ℹ️ Balas: <code>/add_staff ID_BARU</code>" "SUB_STAFF"
                    fi
                    if [[ "$MSG_TEXT" == "/add_staff"* ]]; then
                        NEW_STAFF=$(echo "$MSG_TEXT" | awk '{print $2}')
                        [ -z "$NEW_STAFF" ] && kirim_pesan "$SENDER_ID" "❌ Error." "SUB_STAFF" || { sed -i "s|^STAFF_ID=.*|STAFF_ID=\"$NEW_STAFF\"|" "$CONFIG_FILE"; kirim_pesan "$SENDER_ID" "✅ <b>STAFF DISIMPAN!</b>%0AID: <code>$NEW_STAFF</code>" "SUB_STAFF"; }
                    fi

                    # --- BROADCAST ---
                    if [[ "$MSG_TEXT" == "📢 Broadcast Pesan"* ]]; then
                        kirim_pesan "$SENDER_ID" "ℹ️ Balas: <code>/say Pesan Anda...</code>" "MAIN_OWNER"
                    fi
                    if [[ "$MSG_TEXT" == "/say"* ]]; then
                        PESAN_ISI=$(echo "$MSG_TEXT" | cut -d' ' -f2-)
                        TARGET_STAFF=$(grep "STAFF_ID=" "$CONFIG_FILE" | cut -d'"' -f2)
                        if [ -z "$TARGET_STAFF" ]; then
                            kirim_pesan "$SENDER_ID" "❌ Belum ada staff." "MAIN_OWNER"
                        else
                            kirim_pesan "$TARGET_STAFF" "🔔 <b>PESAN DARI OWNER:</b>%0A%0A$PESAN_ISI" "MAIN_STAFF"
                            kirim_pesan "$SENDER_ID" "✅ Terkirim." "MAIN_OWNER"
                        fi
                    fi
                fi

                OFFSET=$UPDATE_ID
            done <<< "$PARSED_DATA"
        fi
    fi
    sleep 3
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
    echo "🚀 Menyalakan $NAMA_TOKO..."
    termux-wake-lock
    pkill -f "cloudflared"
    pkill -f "service_bot.sh"
    if [ -f "$FLAG_TUTUP" ]; then echo "🔒 TOKO DITUTUP."; else 
        [ -n "$TUNNEL_TOKEN" ] && nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
    fi
    nohup bash "$SERVICE_FILE" >/dev/null 2>&1 &
    echo "✅ Bot Started."
}

ganti_token_darurat() {
    PASS_SAAT_INI=$(grep "MENU_PASSWORD=" "$CONFIG_FILE" | cut -d'"' -f2)
    echo ""; echo "🔒 FITUR TERKUNCI"; read -p "🔑 Masukkan Password Admin: " INPUT_PASS
    if [ "$INPUT_PASS" != "$PASS_SAAT_INI" ]; then echo "❌ PASSWORD SALAH!"; sleep 2; return; fi
    
    echo ""; echo "⚠️  MODE DARURAT ⚠️"
    read -p "👉 Tempel Token BARU: " NEW_TOKEN
    if [[ "$NEW_TOKEN" != *":"* ]]; then echo "❌ Token Salah!"; return; fi

    sed -i "s|BOT_TOKEN=.*|BOT_TOKEN=\"$NEW_TOKEN\"|" "$CONFIG_FILE"
    echo "✅ Disimpan!"; jalankan_layanan; echo "✅ Selesai."; read -p "Enter..."
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    while true; do
        clear
        echo "=== KASIRLITE v4.9: $NAMA_TOKO ==="
        echo "   [ DIAMOND EDITION ]"
        if [ -f "$FLAG_TUTUP" ]; then echo "[ STATUS: 🔴 CLOSED ]"; else echo "[ STATUS: 🟢 OPEN ]"; fi
        echo "--------------------------------"
        echo "1. Cek Status Web Local"
        echo "2. Kirim Backup Manual"
        echo "3. Refresh Service"
        echo "4. ⚠️ GANTI TOKEN BOT (Password)"
        echo "0. Keluar"
        echo "--------------------------------"
        read -p "Pilih: " PIL
        case $PIL in
            1) curl -I http://127.0.0.1:7575; read -p "Enter..." ;;
            2) cd "/storage/emulated/0/KasirToko/database" && zip -r -q "$HOME/manual.zip" . && curl -s -F chat_id="$CHAT_ID" -F document=@"$HOME/manual.zip" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" && rm "$HOME/manual.zip"; read -p "..." ;;
            3) jalankan_layanan; sleep 2 ;;
            4) ganti_token_darurat ;;
            0) exit ;;
        esac
    done
}
if [ "$1" == "start" ]; then jalankan_layanan; else tampilkan_menu; fi
EOF
    chmod +x "$MANAGER_FILE"
}

# ==========================================
# 3. INSTALLER & UPDATER
# ==========================================
if [ "$1" == "mode_update" ]; then
    source "$CONFIG_FILE"
    termux-wake-lock
    if ! grep -q "MENU_PASSWORD" "$CONFIG_FILE"; then echo 'MENU_PASSWORD="123456"' >> "$CONFIG_FILE"; fi
    if ! grep -q "ADMIN_ID" "$CONFIG_FILE"; then echo "ADMIN_ID=\"$CHAT_ID\"" >> "$CONFIG_FILE"; fi
    if ! grep -q "STAFF_ID" "$CONFIG_FILE"; then echo 'STAFF_ID=""' >> "$CONFIG_FILE"; fi

    pkg update -y >/dev/null 2>&1
    pkg install -y cloudflared curl jq zip cronie termux-services >/dev/null 2>&1
    
    source ~/.bashrc 2>/dev/null || true
    update_system_files
    bash "$MANAGER_FILE" start
    
    # [FIX] MEMAKSA PENGIRIMAN KEYBOARD BARU SETELAH UPDATE
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
         -d chat_id="$CHAT_ID" \
         -d text="✅ <b>UPDATE SUKSES!</b>%0ALayout baru diterapkan." \
         -d parse_mode="HTML" \
         -d reply_markup='{"keyboard":[[{"text":"📊 Cek Status"},{"text":"📦 Backup DB"}],[{"text":"🟢 Buka Toko"},{"text":"🔴 Tutup Toko"}],[{"text":"📢 Broadcast Pesan"},{"text":"➕ Manajemen Staff"}],[{"text":"🔄 Restart Service"},{"text":"⬇️ Update Sistem"}],[{"text":"🔐 Ganti Password"}]],"resize_keyboard":true,"is_persistent":true}' >/dev/null
         
    rm "$HOME/update_temp.sh" 2>/dev/null
    exit 0
else
    # INSTALL BARU
    clear; echo "   🛡️ KASIRLITE v4.9 DIAMOND   "
    read -p "👉 Tempel TOKEN BOT: " INPUT_BOT_TOKEN < /dev/tty
    
    echo ""; echo "⏳ MEMPROSES SYSTEM... (JANGAN DITUTUP!)"
    [ -z "$INPUT_BOT_TOKEN" ] && echo "❌ Token Kosong!" && exit 1
    
    termux-wake-lock
    pkg update -y >/dev/null 2>&1 && pkg install -y cloudflared curl jq zip cronie termux-services >/dev/null 2>&1
    termux-setup-storage
    mkdir -p "$DIR_UTAMA"
    
    UNIT=$(tr -dc A-Z0-9 </dev/urandom | head -c 4)
    MSG="🔔 <b>PAIRING BARU</b>%0AKode: <code>$UNIT</code>%0A%0AReply: <code>/deploy $UNIT [TOKEN_CF] [NAMA]</code>"
    
    CEK=$(curl -s -X POST "https://api.telegram.org/bot$INPUT_BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$MSG" -d parse_mode="HTML")
    if [[ "$CEK" != *'"ok":true'* ]]; then echo "❌ Token Salah!"; exit 1; fi
    
    echo "Menunggu Pairing... Kode: $UNIT"
    OFFSET=0
    while true; do
        R=$(curl -s "https://api.telegram.org/bot$INPUT_BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")
        OFFSET=$(echo "$R" | jq -r '.result[-1].update_id // empty')
        TXT=$(echo "$R" | jq -r '.result[-1].message.text // empty')
        if [[ "$TXT" == "/deploy $UNIT"* ]]; then
             TOKEN=$(echo "$TXT" | awk '{print $3}')
             NAMA=$(echo "$TXT" | awk '{print $4}')
             SENDER_ID=$(echo "$R" | jq -r '.result[-1].message.from.id // empty')
             [ -z "$NAMA" ] && NAMA="Cabang-$UNIT"
             break
        fi
        sleep 2
    done
    
    cat <<EOF > "$CONFIG_FILE"
NAMA_TOKO="$NAMA"
TUNNEL_TOKEN="$TOKEN"
BOT_TOKEN="$INPUT_BOT_TOKEN"
CHAT_ID="$CHAT_ID"
ADMIN_ID="$SENDER_ID"
STAFF_ID=""
MENU_PASSWORD="123456"
GITHUB_URL="$GITHUB_URL"
EOF
    update_system_files
    source ~/.bashrc 2>/dev/null || true
    bash "$MANAGER_FILE" start
fi
