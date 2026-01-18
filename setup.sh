#!/bin/bash
# ==========================================================
# 🛡️ KASIRLITE REMOTE v4.9 - TITANIUM (MULTI-USER)
# Fitur: Owner vs Staff, Cooldown Restart, Force Update
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
TIME_FILE="$DIR_UTAMA/.last_restart"

# --- FUNGSI AUTO-RESTART ---
pasang_cronjob() {
    if ! pkg list-installed 2>/dev/null | grep -q "cronie"; then
        pkg install cronie termux-services -y >/dev/null 2>&1
        sv-enable crond >/dev/null 2>&1
    fi
    crontab -r 2>/dev/null
    echo "0 9 * * * bash $HOME/.kasirlite/manager.sh start" | crontab -
}

update_system_files() {
    echo "🛡️ Menerapkan Sistem v4.9 Titanium..."
    pasang_cronjob

    # ==========================================
    # 1. SERVICE BOT (LOGIKA OWNER VS STAFF)
    # ==========================================
    cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
CONFIG_FILE="$HOME/.kasirlite/config.conf"
source "$CONFIG_FILE"

DB_PATH="/storage/emulated/0/KasirToko/database"
FLAG_TUTUP="$HOME/.kasirlite/.toko_tutup"
TIME_FILE="$HOME/.kasirlite/.last_restart"
OFFSET=0
COUNTER=0

kirim_pesan() {
    local TARGET_ID=$2
    [ -z "$TARGET_ID" ] && TARGET_ID="$CHAT_ID"
    
    # LOGIKA KEYBOARD BEDA KASTA
    if [ "$TARGET_ID" == "$ADMIN_ID" ]; then
        # KEYBOARD OWNER (FULL AKSES)
        KEYBOARD='{"keyboard":[
        [{"text":"📊 Cek Status"},{"text":"📦 Backup DB"}],
        [{"text":"🟢 Buka Toko"},{"text":"🔴 Tutup Toko"}],
        [{"text":"🔐 Ganti Pass Menu"},{"text":"🔄 Refresh Service"}],
        [{"text":"⬇️ Update Sistem"}]
        ],"resize_keyboard":true,"is_persistent":true}'
    else
        # KEYBOARD STAFF (TERBATAS)
        KEYBOARD='{"keyboard":[
        [{"text":"📊 Cek Status"},{"text":"📦 Backup DB"}],
        [{"text":"🔄 Refresh Service"}]
        ],"resize_keyboard":true,"is_persistent":true}'
    fi

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$TARGET_ID" \
        -d text="$1" \
        -d parse_mode="HTML" \
        -d reply_markup="$KEYBOARD" >/dev/null
}

kirim_backup_zip() {
    local TYPE=$1
    local TARGET_ID=$2
    local TIMESTAMP=$(date +%Y%m%d-%H%M)
    local ZIP_NAME="Backup_${NAMA_TOKO}_${TIMESTAMP}.zip"
    if [ -d "$DB_PATH" ]; then
        cd "$DB_PATH" && zip -r -q "$HOME/$ZIP_NAME" . 
        if [ -f "$HOME/$ZIP_NAME" ]; then
            curl -s -F chat_id="$TARGET_ID" -F document=@"$HOME/$ZIP_NAME" \
            -F caption="📦 $TYPE: $NAMA_TOKO" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
            rm -f "$HOME/$ZIP_NAME"
        fi
    fi
}

# Notifikasi Start ke Owner & Staff
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/deleteMyCommands" >/dev/null
kirim_pesan "✅ <b>$NAMA_TOKO ONLINE</b>%0AMode Multi-User Aktif." "$ADMIN_ID"
if [ -n "$STAFF_ID" ]; then kirim_pesan "✅ <b>SISTEM SIAP</b>%0ASilakan bertugas." "$STAFF_ID"; fi

while true; do
    RAW_UPDATES=$(curl -s -m 10 "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")

    if [[ "$RAW_UPDATES" == *'"ok":true'* ]]; then
        PARSED_DATA=$(echo "$RAW_UPDATES" | jq -r '.result[] | "\(.update_id)|\(.message.from.id)|\(.message.text | gsub("\n"; " ") | gsub("\""; ""))"')
        
        if [ ! -z "$PARSED_DATA" ]; then
            while IFS='|' read -r UPDATE_ID SENDER_ID MSG_TEXT; do
                
                # --- IDENTIFIKASI PERAN (ROLE) ---
                ROLE="ALIEN"
                if [ "$SENDER_ID" == "$ADMIN_ID" ]; then ROLE="OWNER"; fi
                if [ "$SENDER_ID" == "$STAFF_ID" ]; then ROLE="STAFF"; fi
                
                if [ "$ROLE" == "ALIEN" ]; then 
                    # Abaikan orang asing
                    OFFSET=$UPDATE_ID
                    continue 
                fi

                # --- A. STATUS (SEMUA BOLEH) ---
                if [[ "$MSG_TEXT" == "📊 Cek Status"* ]] || [[ "$MSG_TEXT" == "/status"* ]]; then
                    if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
                    if [ -f "$FLAG_TUTUP" ]; then MODE="🔴 DITUTUP"; else MODE="🟢 DIBUKA"; fi
                    WEB_STAT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7575)
                    if [ "$WEB_STAT" == "200" ]; then WEB="✅ READY"; else WEB="⚠️ MATI"; fi
                    kirim_pesan "📊 <b>STATUS $NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A📱 App: $WEB%0A👤 User: $ROLE" "$SENDER_ID"
                fi

                # --- B. BACKUP (SEMUA BOLEH) ---
                if [[ "$MSG_TEXT" == "📦 Backup DB"* ]] || [[ "$MSG_TEXT" == "/backup"* ]]; then 
                    kirim_backup_zip "Manual Backup ($ROLE)" "$SENDER_ID"
                fi

                # --- C. REFRESH / RESTART (DENGAN BATASAN STAFF) ---
                if [[ "$MSG_TEXT" == "🔄 Refresh Service"* ]]; then
                    BOLEH_RESTART="YA"
                    
                    # Jika Staff, Cek Cooldown 1 Jam (3600 detik)
                    if [ "$ROLE" == "STAFF" ]; then
                        SAAT_INI=$(date +%s)
                        TERAKHIR=$(cat "$TIME_FILE" 2>/dev/null || echo 0)
                        SELISIH=$((SAAT_INI - TERAKHIR))
                        
                        if [ "$SELISIH" -lt 3600 ]; then
                            BOLEH_RESTART="TIDAK"
                            SISA_MENIT=$(( (3600 - SELISIH) / 60 ))
                            kirim_pesan "⏳ <b>EITS, TUNGGU DULU!</b>%0A%0APermintaan Refresh kamu barusan sudah kami proses.%0AAgar sistem tidak bingung, fitur ini hanya bisa dipakai <b>1 jam sekali</b>.%0A%0ASilakan coba lagi $SISA_MENIT menit kedepan ya! 😊" "$SENDER_ID"
                        else
                            echo "$SAAT_INI" > "$TIME_FILE"
                        fi
                    fi
                    
                    if [ "$BOLEH_RESTART" == "YA" ]; then
                         kirim_pesan "🔄 <b>SIAP! MERESTART SISTEM...</b>%0AMohon tunggu sebentar." "$SENDER_ID"
                         # Restart via Manager (Manager akan kill proses ini)
                         bash "$HOME/.kasirlite/manager.sh" start &
                         exit 0
                    fi
                fi

                # =========================================
                #  FITUR EKSKLUSIF OWNER (STAFF DITOLAK)
                # =========================================

                if [[ "$MSG_TEXT" == "🔴 Tutup Toko"* ]] || [[ "$MSG_TEXT" == "🟢 Buka Toko"* ]] || \
                   [[ "$MSG_TEXT" == "🔐 Ganti Pass Menu"* ]] || [[ "$MSG_TEXT" == "⬇️ Update Sistem"* ]] || \
                   [[ "$MSG_TEXT" == "/add_staff"* ]]; then
                    
                    if [ "$ROLE" == "STAFF" ]; then
                        kirim_pesan "⛔ <b>AKSES DITOLAK</b>%0AFitur ini hanya untuk Owner." "$SENDER_ID"
                    else
                        # 1. BUKA / TUTUP
                        if [[ "$MSG_TEXT" == "🔴 Tutup Toko"* ]]; then
                            touch "$FLAG_TUTUP"; pkill -f cloudflared
                            kirim_pesan "🔴 <b>TOKO DITUTUP!</b>" "$SENDER_ID"
                        fi
                        if [[ "$MSG_TEXT" == "🟢 Buka Toko"* ]]; then
                            rm "$FLAG_TUTUP" 2>/dev/null
                            if ! pgrep -f cloudflared >/dev/null; then
                                nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
                                kirim_pesan "✅ <b>TUNNEL ONLINE!</b>" "$SENDER_ID"
                            else
                                kirim_pesan "🟢 <b>SUDAH BUKA!</b>" "$SENDER_ID"
                            fi
                        fi

                        # 2. GANTI PASSWORD
                        if [[ "$MSG_TEXT" == "🔐 Ganti Pass Menu"* ]]; then
                             kirim_pesan "ℹ️ Balas: <code>/set_password ANGKA_BARU</code>" "$SENDER_ID"
                        fi

                        # 3. UPDATE SISTEM
                        if [[ "$MSG_TEXT" == "⬇️ Update Sistem"* ]]; then
                             kirim_pesan "⬇️ <b>MEMULAI UPDATE...</b>" "$SENDER_ID"
                             curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((UPDATE_ID+1))" >/dev/null
                             curl -sL "$GITHUB_URL" > "$HOME/update_temp.sh"
                             bash "$HOME/update_temp.sh" mode_update
                        fi
                        
                        # 4. TAMBAH STAFF
                        if [[ "$MSG_TEXT" == "/add_staff"* ]]; then
                            NEW_STAFF=$(echo "$MSG_TEXT" | awk '{print $2}')
                            if [ -z "$NEW_STAFF" ]; then
                                kirim_pesan "❌ Format salah. Contoh:%0A<code>/add_staff 123456789</code>" "$SENDER_ID"
                            else
                                sed -i "s|^STAFF_ID=.*|STAFF_ID=\"$NEW_STAFF\"|" "$CONFIG_FILE"
                                kirim_pesan "✅ <b>STAFF DITAMBAHKAN!</b>%0AID: <code>$NEW_STAFF</code>%0A%0ASuruh Staff klik /start di bot ini." "$SENDER_ID"
                            fi
                        fi
                    fi
                fi

                # Sub-command Owner (Set Pass/Tunnel)
                if [ "$ROLE" == "OWNER" ]; then
                    if [[ "$MSG_TEXT" == "/set_password"* ]]; then
                        PASS_BARU=$(echo "$MSG_TEXT" | awk '{print $2}')
                        [ -n "$PASS_BARU" ] && sed -i "s|^MENU_PASSWORD=.*|MENU_PASSWORD=\"$PASS_BARU\"|" "$CONFIG_FILE" && kirim_pesan "✅ Password Menu: $PASS_BARU" "$SENDER_ID"
                    fi
                    if [[ "$MSG_TEXT" == "/set_tunnel"* ]]; then
                        TOKEN_CF=$(echo "$MSG_TEXT" | awk '{print $2}')
                        [ -n "$TOKEN_CF" ] && sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\"$TOKEN_CF\"|" "$CONFIG_FILE" && kirim_pesan "✅ Domain Diganti!" "$SENDER_ID"
                    fi
                fi

                OFFSET=$UPDATE_ID
            done <<< "$PARSED_DATA"
        fi
    fi
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 4320 ]; then kirim_backup_zip "Auto Backup" "$ADMIN_ID"; COUNTER=0; fi
    sleep 5
done
EOF
    chmod +x "$SERVICE_FILE"

    # ==========================================
    # 2. MANAGER SCRIPT
    # ==========================================
    cat << 'EOF' > "$MANAGER_FILE"
#!/bin/bash
CONFIG_FILE="$HOME/.kasirlite/config.conf"
source "$CONFIG_FILE"
SERVICE_FILE="$HOME/.kasirlite/service_bot.sh"
FLAG_TUTUP="$HOME/.kasirlite/.toko_tutup"

jalankan_layanan() {
    echo "🚀 Menyalakan $NAMA_TOKO (v4.9 Titanium)..."
    termux-wake-lock
    
    # KILL SEMUA PROSES LAMA (ANTI-DOUBLE SESSION)
    pkill -f "cloudflared"
    pkill -f "service_bot.sh"
    
    # Tunggu sebentar biar bersih
    sleep 2
    
    if [ -f "$FLAG_TUTUP" ]; then
        echo "🔒 STATUS: TOKO DITUTUP."
    else
        if [ -n "$TUNNEL_TOKEN" ]; then 
            nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
            echo "☁️ Tunnel: AKTIF"
        fi
    fi
    
    nohup bash "$SERVICE_FILE" >/dev/null 2>&1 &
    echo "✅ Bot Service Started."
}

ganti_token_darurat() {
    PASS_SAAT_INI=$(grep "MENU_PASSWORD=" "$CONFIG_FILE" | cut -d'"' -f2)
    echo ""; echo "🔒 FITUR TERKUNCI"; read -p "🔑 Masukkan Password Admin: " INPUT_PASS
    if [ "$INPUT_PASS" != "$PASS_SAAT_INI" ]; then echo "❌ PASSWORD SALAH!"; sleep 2; return; fi
    
    echo ""; echo "⚠️  MODE DARURAT ⚠️"; read -p "👉 Paste Token Bot BARU: " NEW_TOKEN
    if [[ "$NEW_TOKEN" != *":"* ]]; then echo "❌ Token Salah!"; return; fi

    sed -i "s|BOT_TOKEN=.*|BOT_TOKEN=\"$NEW_TOKEN\"|" "$CONFIG_FILE"
    echo "✅ Disimpan! Restarting..."
    jalankan_layanan
    echo "✅ Selesai."; read -p "Enter..."
}

tampilkan_menu() {
    while true; do
        clear
        echo "=== KASIRLITE v4.9: $NAMA_TOKO ==="
        echo "   [ TITANIUM EDITION ]"
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
            2) cd "/storage/emulated/0/KasirToko/database" && zip -r -q "$HOME/manual.zip" . && curl -s -F chat_id="$ADMIN_ID" -F document=@"$HOME/manual.zip" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" && rm "$HOME/manual.zip"; read -p "..." ;;
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
# 3. INSTALLER & UPDATER (AUTO-INJECT STAFF)
# ==========================================
if [ "$1" == "mode_update" ]; then
    source "$CONFIG_FILE"
    termux-wake-lock
    
    # Auto-Add Variable Staff jika belum ada
    if ! grep -q "STAFF_ID" "$CONFIG_FILE"; then echo 'STAFF_ID=""' >> "$CONFIG_FILE"; fi
    if ! grep -q "MENU_PASSWORD" "$CONFIG_FILE"; then echo 'MENU_PASSWORD="123456"' >> "$CONFIG_FILE"; fi
    if ! grep -q "ADMIN_ID" "$CONFIG_FILE"; then echo "ADMIN_ID=\"$CHAT_ID\"" >> "$CONFIG_FILE"; fi

    pkg update -y >/dev/null 2>&1
    pkg install -y cloudflared curl jq zip cronie termux-services >/dev/null 2>&1
    
    if [ ! -f ~/.bashrc ]; then echo "# .bashrc" > ~/.bashrc; fi
    if ! grep -q "alias menu=" ~/.bashrc; then 
        echo "alias menu='bash $HOME/.kasirlite/manager.sh'" >> ~/.bashrc
        echo "alias nyala='bash $HOME/.kasirlite/manager.sh start'" >> ~/.bashrc
    fi
    source ~/.bashrc 2>/dev/null || true

    update_system_files
    bash "$MANAGER_FILE" start
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ <b>UPDATE TITANIUM SUKSES!</b>%0AFitur Staff Ready." -d parse_mode="HTML" >/dev/null
    rm "$HOME/update_temp.sh" 2>/dev/null
    exit 0

else
    # INSTALL BARU
    clear; echo "   🛡️ KASIRLITE v4.9 TITANIUM   "
    read -p "👉 Tempel TOKEN BOT: " INPUT_BOT_TOKEN
    [ -z "$INPUT_BOT_TOKEN" ] && exit 1
    
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
    
    if [ ! -f ~/.bashrc ]; then echo "# .bashrc" > ~/.bashrc; fi
    if ! grep -q "alias menu=" ~/.bashrc; then 
        echo "alias menu='bash $HOME/.kasirlite/manager.sh'" >> ~/.bashrc
        echo "alias nyala='bash $HOME/.kasirlite/manager.sh start'" >> ~/.bashrc
    fi
    source ~/.bashrc 2>/dev/null || true
    bash "$MANAGER_FILE" start
fi
