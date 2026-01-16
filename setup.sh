#!/bin/bash
# ==========================================================
# 🛡️ KASIRLITE REMOTE v4.9 - PLATINUM (STABLE FINAL)
# Fitur: Force Update, Auto-Fix Config, Dynamic Password
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

# --- FUNGSI AUTO-RESTART ---
pasang_cronjob() {
    # Cek & Install Cronie jika belum ada
    if ! pkg list-installed 2>/dev/null | grep -q "cronie"; then
        pkg install cronie termux-services -y >/dev/null 2>&1
        sv-enable crond >/dev/null 2>&1
    fi
    # Reset crontab biar tidak duplikat
    crontab -r 2>/dev/null
    # Set jadwal jam 09:00 Pagi
    echo "0 9 * * * bash $HOME/.kasirlite/manager.sh start" | crontab -
}

update_system_files() {
    echo "🛡️ Menerapkan Sistem v4.9 Platinum..."
    pasang_cronjob

    # ==========================================
    # 1. SERVICE BOT (DENGAN ANTI-CRASH JSON)
    # ==========================================
    cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
source "$HOME/.kasirlite/config.conf"
DB_PATH="/storage/emulated/0/KasirToko/database"
FLAG_TUTUP="$HOME/.kasirlite/.toko_tutup"
OFFSET=0
COUNTER=0

kirim_pesan() {
    KEYBOARD='{"keyboard":[
    [{"text":"📊 Cek Status"},{"text":"📦 Backup DB"}],
    [{"text":"🟢 Buka Toko"},{"text":"🔴 Tutup Toko"}],
    [{"text":"🔐 Ganti Pass Menu"},{"text":"🔄 Ganti Domain"}],
    [{"text":"⬇️ Update Sistem"}]
    ],"resize_keyboard":true,"is_persistent":true}'

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$1" \
        -d parse_mode="HTML" \
        -d reply_markup="$KEYBOARD" >/dev/null
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
kirim_pesan "✅ <b>$NAMA_TOKO ONLINE (v4.9 Platinum)</b>%0ASistem Stabil & Aman."

while true; do
    RAW_UPDATES=$(curl -s -m 10 "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")

    if [[ "$RAW_UPDATES" == *'"ok":true'* ]]; then
        # JQ FILTER: Membersihkan Newline dan Double Quote agar JSON tidak error
        PARSED_DATA=$(echo "$RAW_UPDATES" | jq -r '.result[] | "\(.update_id)|\(.message.from.id)|\(.message.text | gsub("\n"; " ") | gsub("\""; ""))"')
        
        if [ ! -z "$PARSED_DATA" ]; then
            while IFS='|' read -r UPDATE_ID SENDER_ID MSG_TEXT; do
                
                # --- A. STATUS ---
                if [[ "$MSG_TEXT" == "📊 Cek Status"* ]] || [[ "$MSG_TEXT" == "/status"* ]]; then
                    if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
                    if [ -f "$FLAG_TUTUP" ]; then MODE="🔴 DITUTUP"; else MODE="🟢 DIBUKA"; fi
                    WEB_STAT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7575)
                    if [ "$WEB_STAT" == "200" ]; then WEB="✅ READY"; else WEB="⚠️ MATI"; fi
                    CURr_PASS=$(grep "MENU_PASSWORD=" "$CONFIG_FILE" | cut -d'"' -f2)
                    kirim_pesan "📊 <b>STATUS $NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A📱 App: $WEB%0A🔐 Mode: $MODE%0A🔑 Pass Menu: <code>$CURr_PASS</code>"
                fi

                # --- B. BACKUP ---
                if [[ "$MSG_TEXT" == "📦 Backup DB"* ]] || [[ "$MSG_TEXT" == "/backup"* ]]; then 
                    kirim_backup_zip "Remote Backup"
                fi

                # --- C. ADMIN CONTROL ---
                if [[ "$MSG_TEXT" == "🔴 Tutup Toko"* ]] || [[ "$MSG_TEXT" == "/close"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    touch "$FLAG_TUTUP"
                    pkill -f cloudflared
                    kirim_pesan "🔴 <b>TOKO DITUTUP!</b>"
                fi

                if [[ "$MSG_TEXT" == "🟢 Buka Toko"* ]] || [[ "$MSG_TEXT" == "/open"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    if [ -f "$FLAG_TUTUP" ]; then rm "$FLAG_TUTUP"; fi 
                    if ! pgrep -f cloudflared >/dev/null; then
                        nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
                        kirim_pesan "⏳ <b>MENYALAKAN TUNNEL...</b>"
                        sleep 5
                        kirim_pesan "✅ <b>TUNNEL ONLINE!</b>"
                    else
                        kirim_pesan "🟢 <b>SUDAH BUKA!</b>"
                    fi
                fi

                # --- D. MANAJEMEN PASSWORD ---
                if [[ "$MSG_TEXT" == "🔐 Ganti Pass Menu"* ]]; then
                     kirim_pesan "ℹ️ Balas dengan format:%0A<code>/set_password ANGKA_BARU</code>"
                fi
                if [[ "$MSG_TEXT" == "/set_password"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    PASS_BARU=$(echo "$MSG_TEXT" | awk '{print $2}')
                    if [ -z "$PASS_BARU" ]; then kirim_pesan "❌ Password tidak boleh kosong."; continue; fi
                    sed -i "s|^MENU_PASSWORD=.*|MENU_PASSWORD=\"$PASS_BARU\"|" "$CONFIG_FILE"
                    kirim_pesan "✅ <b>PASSWORD MENU DIGANTI!</b>%0APassword Baru: <code>$PASS_BARU</code>"
                fi

                # --- E. GANTI DOMAIN ---
                if [[ "$MSG_TEXT" == "🔄 Ganti Domain"* ]]; then
                     kirim_pesan "ℹ️ Balas dengan format:%0A<code>/set_tunnel TOKEN_CLOUDFLARE_BARU</code>"
                fi
                if [[ "$MSG_TEXT" == "/set_tunnel"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    TOKEN_BARU=$(echo "$MSG_TEXT" | awk '{print $2}')
                    if [ ${#TOKEN_BARU} -lt 30 ]; then kirim_pesan "❌ Token Invalid!"; continue; fi
                    sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\"$TOKEN_BARU\"|" "$CONFIG_FILE"
                    pkill -f cloudflared
                    nohup cloudflared tunnel run --token "$TOKEN_BARU" >/dev/null 2>&1 &
                    kirim_pesan "✅ <b>SUKSES GANTI DOMAIN!</b>"
                fi

                # --- F. FORCE UPDATE ---
                if [[ "$MSG_TEXT" == "⬇️ Update Sistem"* ]] || [[ "$MSG_TEXT" == "/update"* ]]; then
                     if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                     kirim_pesan "⬇️ <b>MEMULAI FORCE UPDATE...</b>%0AMenginstal ulang paket & menyegarkan sistem."
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
    # 2. MANAGER SCRIPT (BACA PASSWORD DARI CONFIG)
    # ==========================================
    cat << 'EOF' > "$MANAGER_FILE"
#!/bin/bash
DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"
FLAG_TUTUP="$DIR_UTAMA/.toko_tutup"

jalankan_layanan() {
    source "$CONFIG_FILE"
    echo "🚀 Menyalakan $NAMA_TOKO (v4.9 Platinum)..."
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

ganti_token_darurat() {
    PASS_SAAT_INI=$(grep "MENU_PASSWORD=" "$CONFIG_FILE" | cut -d'"' -f2)
    
    echo ""
    echo "🔒 FITUR TERKUNCI (SECURITY)"
    read -p "🔑 Masukkan Password Admin: " INPUT_PASS
    
    if [ "$INPUT_PASS" != "$PASS_SAAT_INI" ]; then
        echo "❌ PASSWORD SALAH! Akses Ditolak."
        sleep 2
        return
    fi
    
    echo ""
    echo "✅ Akses Diterima."
    echo "⚠️  MODE DARURAT: GANTI BOT ⚠️"
    read -p "👉 Tempel (Paste) Token Bot BARU: " NEW_TOKEN
    
    if [ -z "$NEW_TOKEN" ]; then echo "❌ Batal."; sleep 1; return; fi
    if [[ "$NEW_TOKEN" != *":"* ]]; then echo "❌ Format Token salah!"; return; fi

    sed -i "s|BOT_TOKEN=.*|BOT_TOKEN=\"$NEW_TOKEN\"|" "$CONFIG_FILE"
    echo "✅ Token Berhasil Disimpan!"
    echo "🔄 Merestart Layanan..."
    jalankan_layanan
    echo "✅ Selesai."
    read -p "Tekan Enter..."
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    while true; do
        clear
        echo "=== KASIRLITE v4.9: $NAMA_TOKO ==="
        echo "   [ PLATINUM EDITION ]"
        if [ -f "$FLAG_TUTUP" ]; then echo "[ STATUS: 🔴 CLOSED / TUTUP ]"; else echo "[ STATUS: 🟢 OPEN / BUKA ]"; fi
        echo "--------------------------------"
        echo "1. Cek Status Web Local"
        echo "2. Kirim Backup Manual (Darurat)"
        echo "3. Refresh Service (Restart)"
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
# 3. INSTALLER & UPDATER LOGIC
# ==========================================

# --- MODE FORCE UPDATE (Penyembuhan Total) ---
if [ "$1" == "mode_update" ]; then
    source "$CONFIG_FILE"
    
    echo "🔄 Memulai Force Update..."
    termux-wake-lock # Biar gak tidur pas update
    
    # [A] SELF-HEALING CONFIG
    # Tambahkan variabel baru jika config lama belum punya
    if ! grep -q "MENU_PASSWORD" "$CONFIG_FILE"; then echo 'MENU_PASSWORD="123456"' >> "$CONFIG_FILE"; fi
    if ! grep -q "ADMIN_ID" "$CONFIG_FILE"; then echo "ADMIN_ID=\"$CHAT_ID\"" >> "$CONFIG_FILE"; fi

    # [B] RE-INSTALL DEPENDENCIES (Anti-Drama)
    echo "📦 Mengecek Paket Sistem..."
    pkg update -y >/dev/null 2>&1
    pkg install -y cloudflared curl jq zip cronie termux-services >/dev/null 2>&1
    
    # [C] PERBAIKI SHORTCUT
    if [ ! -f ~/.bashrc ]; then echo "# .bashrc" > ~/.bashrc; fi
    if ! grep -q "alias menu=" ~/.bashrc; then 
        echo "alias menu='bash $HOME/.kasirlite/manager.sh'" >> ~/.bashrc
        echo "alias nyala='bash $HOME/.kasirlite/manager.sh start'" >> ~/.bashrc
    fi
    source ~/.bashrc 2>/dev/null || true

    update_system_files
    
    # [D] RESTART
    bash "$MANAGER_FILE" start
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ <b>UPDATE SUKSES!</b>%0ASistem telah disegarkan total (Force Update)." -d parse_mode="HTML" >/dev/null
    rm "$HOME/update_temp.sh" 2>/dev/null
    exit 0

else
    # --- MODE INSTALL BARU ---
    clear
    echo "   🛡️ KASIRLITE v4.9 PLATINUM INSTALLER   "
    
    # [A] INPUT TOKEN
    read -p "👉 Tempel (Paste) TOKEN BOT: " INPUT_BOT_TOKEN
    if [ -z "$INPUT_BOT_TOKEN" ]; then echo "❌ Token kosong!"; exit 1; fi
    
    echo "⏳ Menyiapkan Sistem..."
    termux-wake-lock # PENTING: Anti-Sleep di awal
    
    # [B] INSTALL PAKET
    pkg update -y >/dev/null 2>&1
    pkg install -y cloudflared curl jq zip cronie termux-services >/dev/null 2>&1
    termux-setup-storage
    mkdir -p "$DIR_UTAMA"
    
    # [C] PAIRING
    UNIT=$(tr -dc A-Z0-9 </dev/urandom | head -c 4)
    MSG="🔔 <b>PAIRING BARU</b>%0AKode: <code>$UNIT</code>%0A%0AReply: <code>/deploy $UNIT [TOKEN_CF] [NAMA]</code>"
    
    # Cek Koneksi dulu
    CEK=$(curl -s -X POST "https://api.telegram.org/bot$INPUT_BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$MSG" -d parse_mode="HTML")
    if [[ "$CEK" != *'"ok":true'* ]]; then echo "❌ Token Bot Salah / Koneksi Gagal!"; exit 1; fi
    
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
    
    # [D] BUAT CONFIG
    cat <<EOF > "$CONFIG_FILE"
NAMA_TOKO="$NAMA"
TUNNEL_TOKEN="$TOKEN"
BOT_TOKEN="$INPUT_BOT_TOKEN"
CHAT_ID="$CHAT_ID"
ADMIN_ID="$SENDER_ID"
MENU_PASSWORD="123456"
GITHUB_URL="$GITHUB_URL"
EOF
    
    update_system_files
    
    # [E] SHORTCUT FIX
    if [ ! -f ~/.bashrc ]; then echo "# .bashrc" > ~/.bashrc; fi
    if ! grep -q "alias menu=" ~/.bashrc; then 
        echo "alias menu='bash $HOME/.kasirlite/manager.sh'" >> ~/.bashrc
        echo "alias nyala='bash $HOME/.kasirlite/manager.sh start'" >> ~/.bashrc
    fi
    source ~/.bashrc 2>/dev/null || true
    
    bash "$MANAGER_FILE" start
fi
