#!/bin/bash
# ==========================================================
# 🚀 KASIRLITE REMOTE v4.0 - ULTIMATE EDITION
# Fitur: OTA, ZIP Backup, Telegram Menu Button, Auto-Update
# ==========================================================

# --- [BAGIAN ADMIN: ISI INI DULU] ---
BOT_TOKEN="8548080118:AAEUP_FzU1OcNb-l5G_dTb3TaBbDS8-oYjE"
CHAT_ID="7236113204"
# Ganti dengan Link RAW GitHub Anda yang asli:
GITHUB_URL="https://raw.githubusercontent.com/tanilink/toko/main/setup.sh"
# ------------------------------------

DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
MANAGER_FILE="$DIR_UTAMA/manager.sh"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"

# ==========================================================
# FUNGSI UTAMA: MENULIS ULANG FILE SISTEM
# (Dipakai saat Instalasi Awal & Saat Update)
# ==========================================================
update_system_files() {
    echo "💾 Menulis File Sistem..."

    # 1. TULIS SERVICE BOT (OTAK SISTEM)
    cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
source "$HOME/.kasirlite/config.conf"
DB_PATH="/storage/emulated/0/KasirToko/database"
OFFSET=0
COUNTER=0

# A. Set Menu Tombol Telegram (Hanya sekali saat startup)
set_bot_menu() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/setMyCommands" \
    -d "commands=[
        {\"command\":\"status\", \"description\":\"📊 Cek Koneksi & Baterai\"},
        {\"command\":\"backup\", \"description\":\"📦 Ambil Database (ZIP)\"},
        {\"command\":\"msg\", \"description\":\"💬 Kirim Pesan ke Layar\"},
        {\"command\":\"restart\", \"description\":\"🔄 Restart Service Remote\"},
        {\"command\":\"update\", \"description\":\"⬇️ Tarik Update dari GitHub\"}
    ]" >/dev/null
}
set_bot_menu

# B. Fungsi Kirim Backup ZIP
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
    else
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="❌ Gagal: Folder Database Kosong" >/dev/null
    fi
}

# C. Lapor Online
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" -d text="✅ <b>$NAMA_TOKO ONLINE (v4.0)</b>%0A🚀 Menu Bot Sudah Diperbarui." -d parse_mode="HTML" >/dev/null

# D. Loop Listener
while true; do
    UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")
    NEW_OFFSET=$(echo "$UPDATES" | jq -r '.result[-1].update_id // empty')
    
    if [ ! -z "$NEW_OFFSET" ]; then 
        OFFSET=$NEW_OFFSET
        MSG=$(echo "$UPDATES" | jq -r '.result[-1].message.text // empty')
        
        # --- LOGIKA PERINTAH ---
        
        # 1. STATUS
        if [[ "$MSG" == "/status"* ]]; then
            if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
            BAT=$(termux-battery-status | jq .percentage)
            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                -d chat_id="$CHAT_ID" -d text="📊 <b>STATUS $NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A🔋 Baterai: $BAT%" -d parse_mode="HTML" >/dev/null
        fi

        # 2. BACKUP
        if [[ "$MSG" == "/backup"* ]]; then
            kirim_backup_zip "Remote Backup"
        fi

        # 3. RESTART
        if [[ "$MSG" == "/restart"* ]]; then
             curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="🔄 Merestart Service..." >/dev/null
             pkill -f "cloudflared"
             exit 0 # Script service mati, nanti akan dihidupkan lagi oleh loop manager (jika ada) atau manual
             # Tapi karena kita pakai nohup, lebih baik panggil manager restart
             bash "$HOME/.kasirlite/manager.sh" restart_remote &
        fi

        # 4. KIRIM PESAN (TOAST)
        if [[ "$MSG" == "/msg"* ]]; then
            ISI_PESAN=$(echo "$MSG" | sed 's/\/msg //')
            termux-toast -b "#ff0000" -c "#ffffff" "$ISI_PESAN"
            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ Pesan ditampilkan di layar." >/dev/null
        fi

        # 5. UPDATE SCRIPT
        if [[ "$MSG" == "/update"* ]]; then
             curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="⬇️ Sedang Update Script..." >/dev/null
             # Download Script Sendiri lalu jalankan mode update
             curl -sL "$GITHUB_URL" > "$HOME/update_temp.sh"
             bash "$HOME/update_temp.sh" mode_update
        fi
    fi

    # E. Auto Backup (6 Jam)
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 4320 ]; then
        kirim_backup_zip "Auto Backup 6 Jam"
        COUNTER=0
    fi
    sleep 5
done
EOF
    chmod +x "$SERVICE_FILE"

    # 2. TULIS MANAGER SCRIPT (MENU LOKAL)
    cat << 'EOF' > "$MANAGER_FILE"
#!/bin/bash
DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"

jalankan_layanan() {
    source "$CONFIG_FILE"
    echo "🚀 Menyalakan $NAMA_TOKO..."
    termux-wake-lock
    
    # Matikan proses lama
    pkill -f "cloudflared"
    pkill -f "service_bot.sh"
    
    # Start Tunnel
    if [ -n "$TUNNEL_TOKEN" ]; then
        nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
        echo "✅ Tunnel: AKTIF"
    fi
    
    # Start Bot
    nohup bash "$SERVICE_FILE" >/dev/null 2>&1 &
    echo "✅ Bot Service: AKTIF"
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    while true; do
        clear
        echo "=== KASIRLITE v4.0: $NAMA_TOKO ==="
        echo "1. Cek Status"
        echo "2. Backup Database (ZIP)"
        echo "3. Refresh Sistem"
        echo "0. Keluar"
        echo "----------------------------------"
        read -p "Pilih: " PIL
        case $PIL in
            1) curl -I http://127.0.0.1:7575; read -p "Enter..." ;;
            2) 
               echo "📦 ZIP Backup..."
               DB_PATH="/storage/emulated/0/KasirToko/database"
               ZIP_NAME="Manual_${NAMA_TOKO}.zip"
               cd "$DB_PATH" && zip -r -q "$HOME/$ZIP_NAME" .
               curl -s -F chat_id="$CHAT_ID" -F document=@"$HOME/$ZIP_NAME" -F caption="📦 Manual Backup" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
               rm -f "$HOME/$ZIP_NAME"
               echo "✅ Terkirim!"; read -p "Enter..." ;;
            3) jalankan_layanan; sleep 2 ;;
            0) exit ;;
        esac
    done
}

if [ "$1" == "start" ]; then jalankan_layanan; 
elif [ "$1" == "restart_remote" ]; then jalankan_layanan; 
else tampilkan_menu; fi
EOF
    chmod +x "$MANAGER_FILE"
    
    # 3. FIX SHORTCUT
    touch ~/.bashrc
    sed -i '/alias nyala=/d' ~/.bashrc
    sed -i '/alias menu=/d' ~/.bashrc
    echo "alias menu='bash $DIR_UTAMA/manager.sh'" >> ~/.bashrc
    echo "alias nyala='bash $DIR_UTAMA/manager.sh start'" >> ~/.bashrc
}

# ==========================================================
# LOGIKA INSTALASI (NORMAL VS UPDATE)
# ==========================================================

if [ "$1" == "mode_update" ]; then
    # --- MODE UPDATE (Dijalankan oleh Bot) ---
    echo "🔄 MEMULAI PROSES UPDATE..."
    # Ambil Config Lama (PENTING)
    source "$CONFIG_FILE"
    
    # Tulis ulang file Manager & Bot dengan kode terbaru di atas
    update_system_files
    
    # Restart Layanan
    bash "$MANAGER_FILE" start
    
    # Lapor Admin
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" -d text="✅ <b>UPDATE SUKSES!</b>%0A$NAMA_TOKO sudah menggunakan versi terbaru." -d parse_mode="HTML" >/dev/null
    
    # Hapus file temp
    rm "$HOME/update_temp.sh" 2>/dev/null
    exit 0

else
    # --- MODE INSTALASI BARU (Operator) ---
    clear
    echo "⚙️  MENYIAPKAN SISTEM..."
    termux-wake-lock
    
    # Install Paket
    pkg update -y >/dev/null 2>&1
    for pkg in cloudflared curl jq termux-api netcat-openbsd zip; do
        if ! command -v $pkg &> /dev/null; then pkg install -y $pkg >/dev/null 2>&1; fi
    done

    # Izin Storage
    TEST_FILE="/storage/emulated/0/test_perm"
    touch "$TEST_FILE" 2>/dev/null
    if [ ! -f "$TEST_FILE" ]; then
        echo "⚠️  MINTA IZIN STORAGE..."
        termux-setup-storage
        sleep 3
    fi
    rm "$TEST_FILE" 2>/dev/null

    mkdir -p "$DIR_UTAMA"
    
    # OTA Provisioning
    UNIT_CODE=$(tr -dc A-Z0-9 </dev/urandom | head -c 4)
    PESAN="🔔 <b>PERMINTAAN AKTIVASI!</b>%0A%0A📱 Kode: <code>$UNIT_CODE</code>%0A👉 Balas:%0A<code>/deploy $UNIT_CODE [TOKEN] [NAMA]</code>"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$PESAN" -d parse_mode="HTML" >/dev/null

    echo "==================================="
    echo "   ⏳ MENUNGGU ADMIN..."
    echo "   📱 KODE: $UNIT_CODE"
    echo "==================================="

    OFFSET=0
    while true; do
        RESPONSE=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))&timeout=10")
        NEW_OFFSET=$(echo "$RESPONSE" | jq -r '.result[-1].update_id // empty')
        if [ ! -z "$NEW_OFFSET" ]; then OFFSET=$NEW_OFFSET; fi
        LAST_TEXT=$(echo "$RESPONSE" | jq -r '.result[-1].message.text // empty')

        if [[ "$LAST_TEXT" == "/deploy $UNIT_CODE"* ]]; then
            TOKEN=$(echo "$LAST_TEXT" | awk '{print $3}')
            NAMA=$(echo "$LAST_TEXT" | awk '{print $4}')
            if [ ${#TOKEN} -gt 20 ]; then
                 if [ -z "$NAMA" ]; then NAMA="Cabang-$UNIT_CODE"; fi
                 break
            fi
        fi
        sleep 2
    done

    echo "💾 Config: $NAMA"
    cat <<EOF > "$CONFIG_FILE"
NAMA_TOKO="$NAMA"
TUNNEL_TOKEN="$TOKEN"
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
GITHUB_URL="$GITHUB_URL"
EOF

    # Jalankan Fungsi Penulisan File
    update_system_files
    
    echo "✅ INSTALASI SELESAI!"
    source ~/.bashrc
    bash "$MANAGER_FILE" start
fi
