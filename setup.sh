#!/bin/bash
# ==========================================================
# 🚀 KASIRLITE REMOTE v3.2 - ZIP BACKUP EDITION
# Fitur: OTA Provisioning + Full Folder Backup (ZIP)
# ==========================================================

# --- [BAGIAN ADMIN: ISI INI DULU] ---
BOT_TOKEN="8548080118:AAEUP_FzU1OcNb-l5G_dTb3TaBbDS8-oYjE"
CHAT_ID="7236113204"
# ------------------------------------

DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
MANAGER_FILE="$DIR_UTAMA/manager.sh"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"

# ==========================================================
# 1. PERSIAPAN SISTEM
# ==========================================================
clear
echo "⚙️  MENYIAPKAN SISTEM..."

# A. Wake Lock
termux-wake-lock

# B. Install Paket (TAMBAHAN: ZIP)
pkg update -y >/dev/null 2>&1
# Tambahkan 'zip' ke dalam daftar instalasi
for pkg in cloudflared curl jq termux-api netcat-openbsd zip; do
    if ! command -v $pkg &> /dev/null; then
        pkg install -y $pkg >/dev/null 2>&1
    fi
done

# C. Validasi Izin Storage (WAJIB)
TEST_FILE="/storage/emulated/0/test_perm"
touch "$TEST_FILE" 2>/dev/null
if [ ! -f "$TEST_FILE" ]; then
    echo "⚠️  IZIN PENYIMPANAN DIPERLUKAN!"
    echo "👉 Silakan pilih 'IZINKAN' pada pop-up..."
    termux-setup-storage
    sleep 3
    touch "$TEST_FILE" 2>/dev/null
    if [ ! -f "$TEST_FILE" ]; then
        echo "❌ GAGAL: Izin ditolak."
        exit 1
    fi
fi
rm "$TEST_FILE" 2>/dev/null

mkdir -p "$DIR_UTAMA"

# ==========================================================
# 2. OTA PROVISIONING (ADMIN FULL CONTROL)
# ==========================================================
UNIT_CODE=$(tr -dc A-Z0-9 </dev/urandom | head -c 4)

echo "📡 MENGHUBUNGI ADMIN..."
PESAN="🔔 <b>PERMINTAAN AKTIVASI!</b>%0A%0A📱 Kode Unit: <code>$UNIT_CODE</code>%0A📅 $(date)%0A%0A👉 Admin, balas:%0A<code>/deploy $UNIT_CODE [TOKEN] [NAMA_TOKO]</code>"

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$PESAN" \
    -d parse_mode="HTML" >/dev/null

echo "========================================="
echo "   ⏳ MENUNGGU KONFIGURASI ADMIN..."
echo "   📱 KODE UNIT: $UNIT_CODE"
echo "========================================="
echo "   Mohon jangan tutup aplikasi..."

OFFSET=0
TOKEN_DITERIMA=""
NAMA_DITERIMA=""

while true; do
    RESPONSE=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))&timeout=10")
    NEW_OFFSET=$(echo "$RESPONSE" | jq -r '.result[-1].update_id // empty')
    if [ ! -z "$NEW_OFFSET" ]; then OFFSET=$NEW_OFFSET; fi

    LAST_TEXT=$(echo "$RESPONSE" | jq -r '.result[-1].message.text // empty')

    if [[ "$LAST_TEXT" == "/deploy $UNIT_CODE"* ]]; then
        echo -e "\n✅ DATA DITERIMA DARI ADMIN!"
        TOKEN_DITERIMA=$(echo "$LAST_TEXT" | awk '{print $3}')
        NAMA_DITERIMA=$(echo "$LAST_TEXT" | awk '{print $4}')
        
        if [ ${#TOKEN_DITERIMA} -gt 20 ]; then
            if [ -z "$NAMA_DITERIMA" ]; then NAMA_DITERIMA="Cabang-$UNIT_CODE"; fi
            break
        else
            echo "❌ Token Admin salah, menunggu revisi..."
        fi
    fi
    sleep 2
done

echo "💾 Mengkonfigurasi $NAMA_DITERIMA..."

cat <<EOF > "$CONFIG_FILE"
NAMA_TOKO="$NAMA_DITERIMA"
TUNNEL_TOKEN="$TOKEN_DITERIMA"
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOF

# ==========================================================
# 3. BUAT SERVICE BOT (ZIP BACKUP LOGIC)
# ==========================================================
cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
source "$HOME/.kasirlite/config.conf"
DB_PATH="/storage/emulated/0/KasirToko/database"
OFFSET=0
COUNTER=0

# Fungsi Backup ZIP Reusable
kirim_backup_zip() {
    local TYPE=$1
    local TIMESTAMP=$(date +%Y%m%d-%H%M)
    local ZIP_NAME="Backup_${NAMA_TOKO}_${TIMESTAMP}.zip"
    local ZIP_FULL_PATH="$HOME/$ZIP_NAME"

    if [ -d "$DB_PATH" ]; then
        # Masuk folder dulu agar zip tidak membawa path panjang
        cd "$DB_PATH" && zip -r "$ZIP_FULL_PATH" . >/dev/null 2>&1
        
        if [ -f "$ZIP_FULL_PATH" ]; then
            curl -s -F chat_id="$CHAT_ID" -F document=@"$ZIP_FULL_PATH" \
            -F caption="📦 $TYPE: $NAMA_TOKO" \
            "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
            
            # Hapus file zip setelah kirim (hemat storage)
            rm -f "$ZIP_FULL_PATH"
        fi
    fi
}

# Notif Startup
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="✅ <b>$NAMA_TOKO ONLINE!</b>%0A🚀 Sistem Siap Pakai." \
    -d parse_mode="HTML" >/dev/null

while true; do
    # A. Cek Remote Command
    UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")
    NEW_OFFSET=$(echo "$UPDATES" | jq -r '.result[-1].update_id // empty')
    
    if [ ! -z "$NEW_OFFSET" ]; then 
        OFFSET=$NEW_OFFSET
        MSG=$(echo "$UPDATES" | jq -r '.result[-1].message.text // empty')
        
        if [[ "$MSG" == "/status"* ]]; then
            if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                -d chat_id="$CHAT_ID" -d text="📊 Status $NAMA_TOKO: Tunnel $CF | Bat $(termux-battery-status | jq .percentage)%" >/dev/null
        fi

        if [[ "$MSG" == "/backup"* ]]; then
            kirim_backup_zip "Remote Backup (ZIP)"
        fi
    fi

    # B. Auto Backup (6 Jam)
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 4320 ]; then
        kirim_backup_zip "Auto Backup 6 Jam (ZIP)"
        COUNTER=0
    fi
    sleep 5
done
EOF
chmod +x "$SERVICE_FILE"

# ==========================================================
# 4. BUAT MANAGER SCRIPT (MENU LOKAL JUGA PAKAI ZIP)
# ==========================================================
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
    
    if [ -n "$TUNNEL_TOKEN" ]; then
        nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
        echo "✅ Cloudflare Tunnel: AKTIF"
    fi
    nohup bash "$SERVICE_FILE" >/dev/null 2>&1 &
    echo "✅ Bot Service: AKTIF"
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    clear
    echo "=== KASIRLITE: $NAMA_TOKO ==="
    echo "1. Cek Status"
    echo "2. Backup Database (ZIP)"
    echo "3. Refresh Sistem"
    echo "0. Keluar"
    read -p "Pilih: " PIL
    case $PIL in
        1) curl -I http://127.0.0.1:7575; read -p "Enter..." ;;
        2) 
           echo "📦 Mengompres & Mengirim ZIP..."
           # Logika ZIP Manual
           DB_PATH="/storage/emulated/0/KasirToko/database"
           ZIP_NAME="ManualBackup_${NAMA_TOKO}.zip"
           if [ -d "$DB_PATH" ]; then
               cd "$DB_PATH" && zip -r "$HOME/$ZIP_NAME" . >/dev/null 2>&1
               curl -s -F chat_id="$CHAT_ID" -F document=@"$HOME/$ZIP_NAME" \
               -F caption="📦 Manual Backup (Menu): $NAMA_TOKO" \
               "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
               rm -f "$HOME/$ZIP_NAME"
               echo "✅ Terkirim!"
           else
               echo "❌ Folder database tidak ditemukan!"
           fi
           read -p "Enter..." ;;
        3) jalankan_layanan; sleep 2 ;;
        0) exit ;;
    esac
}

if [ "$1" == "start" ]; then jalankan_layanan; else tampilkan_menu; fi
EOF
chmod +x "$MANAGER_FILE"

# ==========================================================
# 5. FINISHING
# ==========================================================
sed -i '/alias nyala=/d' ~/.bashrc
sed -i '/alias menu=/d' ~/.bashrc
echo "alias menu='bash $DIR_UTAMA/manager.sh'" >> ~/.bashrc
echo "alias nyala='bash $DIR_UTAMA/manager.sh start'" >> ~/.bashrc

echo "✅ INSTALASI SELESAI!"
bash "$MANAGER_FILE" start
