#!/bin/bash
# ==========================================================
# 🚀 KASIRLITE REMOTE v3.0 - FINAL PRODUCTION
# Fitur: OTA Provisioning, WakeLock, Remote Bot, Auto-Backup
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
# 1. PERSIAPAN SISTEM & DEPENDENSI
# ==========================================================
clear
echo "⚙️  MEMULAI INSTALASI SISTEM..."

# A. Wake Lock (Anti Tidur)
termux-wake-lock
echo "✅ Wake Lock Aktif"

# B. Install Paket
echo "📦 Cek Dependensi..."
pkg update -y >/dev/null 2>&1
for pkg in cloudflared curl jq termux-api netcat-openbsd; do
    if ! command -v $pkg &> /dev/null; then
        echo "   - Menginstall $pkg..."
        pkg install -y $pkg >/dev/null 2>&1
    fi
done

# C. Validasi Izin Storage (PENTING!)
echo "📂 Cek Izin Penyimpanan..."
TEST_FILE="/storage/emulated/0/test_perm"
touch "$TEST_FILE" 2>/dev/null
if [ ! -f "$TEST_FILE" ]; then
    echo "⚠️  IZIN PENYIMPANAN DIPERLUKAN!"
    echo "👉 Silakan pilih 'IZINKAN' / 'ALLOW' pada pop-up..."
    termux-setup-storage
    sleep 3
    # Cek ulang
    touch "$TEST_FILE" 2>/dev/null
    if [ ! -f "$TEST_FILE" ]; then
        echo "❌ GAGAL: Izin ditolak. Instalasi dibatalkan."
        exit 1
    fi
fi
rm "$TEST_FILE" 2>/dev/null
echo "✅ Izin Penyimpanan OK"

mkdir -p "$DIR_UTAMA"

# ==========================================================
# 2. OTA PROVISIONING (MINTA TOKEN KE ADMIN)
# ==========================================================
UNIT_CODE=$(tr -dc A-Z0-9 </dev/urandom | head -c 4)

echo "📡 MENGHUBUNGI SERVER PUSAT..."
PESAN="🔔 <b>PERMINTAAN AKTIVASI BARU!</b>%0A%0A📱 Kode Unit: <code>$UNIT_CODE</code>%0A📅 Waktu: $(date)%0A%0A👉 Admin, balas dengan:%0A<code>/deploy $UNIT_CODE [TOKEN_CLOUDFLARE]</code>"

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$PESAN" \
    -d parse_mode="HTML" >/dev/null

echo "========================================="
echo "   ⏳ MENUNGGU AKTIVASI ADMIN..."
echo "   📱 KODE UNIT: $UNIT_CODE"
echo "========================================="

OFFSET=0
TOKEN_DITERIMA=""

while true; do
    RESPONSE=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))&timeout=10")
    NEW_OFFSET=$(echo "$RESPONSE" | jq -r '.result[-1].update_id // empty')
    if [ ! -z "$NEW_OFFSET" ]; then OFFSET=$NEW_OFFSET; fi

    LAST_TEXT=$(echo "$RESPONSE" | jq -r '.result[-1].message.text // empty')

    if [[ "$LAST_TEXT" == "/deploy $UNIT_CODE"* ]]; then
        echo -e "\n✅ TOKEN DITERIMA!"
        TOKEN_DITERIMA=$(echo "$LAST_TEXT" | awk '{print $3}')
        if [ ${#TOKEN_DITERIMA} -gt 20 ]; then break; fi
    fi
    sleep 2
done

echo "💾 Menyimpan Konfigurasi..."
read -p "Masukkan Nama Cabang ini (ex: Roxy): " NAMA_CABANG

cat <<EOF > "$CONFIG_FILE"
NAMA_TOKO="$NAMA_CABANG"
TUNNEL_TOKEN="$TOKEN_DITERIMA"
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOF

# ==========================================================
# 3. BUAT SERVICE BOT (LISTENER & AUTO BACKUP)
# ==========================================================
cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
source "$HOME/.kasirlite/config.conf"
DB_PATH="/storage/emulated/0/KasirToko/database"
OFFSET=0
COUNTER=0

# Kirim Notif Online Saat Startup
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="✅ <b>$NAMA_TOKO ONLINE!</b>%0A🚀 Sistem Siap.%0ACoba ketik: /status atau /backup" \
    -d parse_mode="HTML" >/dev/null

while true; do
    # A. Cek Telegram Command (Setiap 5 detik)
    UPDATES=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")
    NEW_OFFSET=$(echo "$UPDATES" | jq -r '.result[-1].update_id // empty')
    
    if [ ! -z "$NEW_OFFSET" ]; then 
        OFFSET=$NEW_OFFSET
        MSG=$(echo "$UPDATES" | jq -r '.result[-1].message.text // empty')
        
        # 1. Perintah /status
        if [[ "$MSG" == "/status"* ]]; then
            if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                -d chat_id="$CHAT_ID" -d text="📊 <b>STATUS $NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A🔋 Battery: $(termux-battery-status | jq .percentage)%%" -d parse_mode="HTML" >/dev/null
        fi

        # 2. Perintah /backup
        if [[ "$MSG" == "/backup"* ]]; then
            LATEST=$(ls -t "$DB_PATH"/*.db 2>/dev/null | head -n 1)
            if [ -f "$LATEST" ]; then
                curl -s -F chat_id="$CHAT_ID" -F document=@"$LATEST" -F caption="📦 Backup Manual: $NAMA_TOKO" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
            else
                curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="❌ Database tidak ditemukan." >/dev/null
            fi
        fi
    fi

    # B. Auto Backup (Setiap 6 Jam = 4320 x 5 detik)
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 4320 ]; then
        LATEST=$(ls -t "$DB_PATH"/*.db 2>/dev/null | head -n 1)
        if [ -f "$LATEST" ]; then
            curl -s -F chat_id="$CHAT_ID" -F document=@"$LATEST" -F caption="📦 Auto Backup (6 Jam): $NAMA_TOKO" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
        fi
        COUNTER=0
    fi

    sleep 5
done
EOF
chmod +x "$SERVICE_FILE"

# ==========================================================
# 4. BUAT MANAGER SCRIPT (MENU LOKAL)
# ==========================================================
cat << 'EOF' > "$MANAGER_FILE"
#!/bin/bash
DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"

jalankan_layanan() {
    source "$CONFIG_FILE"
    echo "🚀 Menyalakan Service $NAMA_TOKO..."
    termux-wake-lock
    
    # Anti-Double Session (Kill All)
    pkill -f "cloudflared"
    pkill -f "service_bot.sh"
    
    # Start Tunnel
    if [ -n "$TUNNEL_TOKEN" ]; then
        nohup cloudflared tunnel run --token "$TUNNEL_TOKEN" >/dev/null 2>&1 &
        echo "✅ Cloudflare Tunnel: AKTIF"
    fi
    
    # Start Bot Listener
    nohup bash "$SERVICE_FILE" >/dev/null 2>&1 &
    echo "✅ Bot Listener: AKTIF"
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    clear
    echo "=== KASIRLITE PRO: $NAMA_TOKO ==="
    echo "1. Cek Status (Tunnel & Port)"
    echo "2. Backup Database Manual"
    echo "3. Restart / Refresh Service"
    echo "4. Ganti Token Tunnel"
    echo "0. Keluar"
    read -p "Pilih: " PIL
    case $PIL in
        1) 
           echo "--- CLOUDFLARE ---"
           if pgrep -f cloudflared >/dev/null; then echo "✅ BERJALAN"; else echo "❌ MATI"; fi
           echo "--- WEB KASIR ---"
           curl -I http://127.0.0.1:7575
           read -p "Enter..." ;;
        2) 
           echo "📦 Mengirim Backup..."
           LATEST=$(ls -t "/storage/emulated/0/KasirToko/database"/*.db 2>/dev/null | head -n 1)
           curl -s -F chat_id="$CHAT_ID" -F document=@"$LATEST" -F caption="📦 Manual Backup (Menu): $NAMA_TOKO" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
           echo "✅ Terkirim!"; read -p "Enter..." ;;
        3) jalankan_layanan; sleep 2 ;;
        4) nano "$CONFIG_FILE"; echo "Restart layanan (Menu 3) setelah edit."; read -p "Enter..." ;;
        0) exit ;;
    esac
}

if [ "$1" == "start" ]; then jalankan_layanan; else tampilkan_menu; fi
EOF
chmod +x "$MANAGER_FILE"

# ==========================================================
# 5. PASANG SHORTCUT & FINISHING
# ==========================================================
sed -i '/alias nyala=/d' ~/.bashrc
sed -i '/alias menu=/d' ~/.bashrc
sed -i '/alias cek=/d' ~/.bashrc
echo "alias menu='bash $DIR_UTAMA/manager.sh'" >> ~/.bashrc
echo "alias nyala='bash $DIR_UTAMA/manager.sh start'" >> ~/.bashrc
echo "alias cek='pgrep -a cloudflared'" >> ~/.bashrc

echo "✅ INSTALASI SELESAI!"
# Jalankan service pertama kali secara otomatis
bash "$MANAGER_FILE" start
