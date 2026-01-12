#!/bin/bash
# ==========================================================
# 🛡️ KASIRLITE REMOTE v4.5 - FINAL STABLE
# Fitur: Queue Polling, Admin ACL, Safe Exec, Tunnel Rollback
# ==========================================================

# --- [BAGIAN ADMIN: ISI DATA ANDA] ---
BOT_TOKEN="8548080118:AAEUP_FzU1OcNb-l5G_dTb3TaBbDS8-oYjE"
CHAT_ID="7236113204"  # Default Group Chat ID
GITHUB_URL="https://raw.githubusercontent.com/tanilink/toko/main/setup.sh"
# -------------------------------------

DIR_UTAMA="$HOME/.kasirlite"
CONFIG_FILE="$DIR_UTAMA/config.conf"
MANAGER_FILE="$DIR_UTAMA/manager.sh"
SERVICE_FILE="$DIR_UTAMA/service_bot.sh"

# Fungsi pembantu untuk update file sistem
update_system_files() {
    echo "🛡️ Menerapkan Sistem v4.5 (Secure Logic)..."

    # ======================================================
    # 1. MENULIS SERVICE BOT (THE BRAIN)
    # ======================================================
    cat << 'EOF' > "$SERVICE_FILE"
#!/bin/bash
source "$HOME/.kasirlite/config.conf"
DB_PATH="/storage/emulated/0/KasirToko/database"
OFFSET=0
COUNTER=0

# --- FUNGSI BANTUAN ---
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

# --- INISIALISASI ---
# Set Menu Tombol (Update Command List)
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/setMyCommands" \
    -d "commands=[{\"command\":\"status\", \"description\":\"📊 Cek Status\"},{\"command\":\"backup\", \"description\":\"📦 Backup DB\"},{\"command\":\"msg\", \"description\":\"💬 Kirim Info\"},{\"command\":\"cek\", \"description\":\"🔍 Safe Check\"},{\"command\":\"update\", \"description\":\"⬇️ Update\"}]" >/dev/null

kirim_pesan "✅ <b>$NAMA_TOKO ONLINE (v4.5)</b>%0A🛡️ Security & Queue Logic Active."

# --- MAIN LOOP (POLLING) ---
while true; do
    # 1. Ambil Data (Timeout 10s agar tidak hang)
    RAW_UPDATES=$(curl -s -m 10 "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")

    # 2. Validasi JSON (Harus ada "ok":true)
    if [[ "$RAW_UPDATES" == *'"ok":true'* ]]; then
        
        # 3. Parsing Stream (Cegah Race Condition)
        # Format: UPDATE_ID | SENDER_ID | PESAN (Newline diganti spasi)
        PARSED_DATA=$(echo "$RAW_UPDATES" | jq -r '.result[] | "\(.update_id)|\(.message.from.id)|\(.message.text | gsub("\n"; " "))"')
        
        if [ ! -z "$PARSED_DATA" ]; then
            # Loop setiap pesan dalam antrian
            while IFS='|' read -r UPDATE_ID SENDER_ID MSG_TEXT; do
                
                # --- LOGIKA PERINTAH ---

                # A. STATUS (Umum)
                if [[ "$MSG_TEXT" == "/status"* ]]; then
                    if pgrep -f cloudflared >/dev/null; then CF="✅ ON"; else CF="❌ OFF"; fi
                    kirim_pesan "📊 <b>STATUS $NAMA_TOKO</b>%0A☁️ Tunnel: $CF%0A🛡️ System: v4.5 Stable"
                fi

                # B. BACKUP (Umum)
                if [[ "$MSG_TEXT" == "/backup"* ]]; then kirim_backup_zip "Remote Backup"; fi

                # C. PESAN / NOTIFIKASI (Umum)
                if [[ "$MSG_TEXT" == "/msg"* ]]; then
                    ISI=$(echo "$MSG_TEXT" | sed 's/\/msg //')
                    termux-notification --title "INFO PUSAT" --content "$ISI" --priority high >/dev/null 2>&1
                    kirim_pesan "✅ Notifikasi Terkirim ke Layar."
                fi

                # --- ZONA ADMIN (PROTECTED) ---
                # Semua perintah di bawah ini butuh SENDER_ID == ADMIN_ID
                
                # D. SAFE CEK (Ganti /exec)
                if [[ "$MSG_TEXT" == "/cek"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then kirim_pesan "⛔ <b>AKSES DITOLAK!</b>"; continue; fi
                    
                    CMD_SHELL=$(echo "$MSG_TEXT" | sed 's/\/cek //')
                    
                    # Blacklist Perintah Berbahaya
                    if [[ "$CMD_SHELL" == *"rm "* ]] || [[ "$CMD_SHELL" == *"mv "* ]] || \
                       [[ "$CMD_SHELL" == *"reboot"* ]] || [[ "$CMD_SHELL" == *">"* ]] || \
                       [[ "$CMD_SHELL" == *";"* ]] || [[ "$CMD_SHELL" == *"|"* ]]; then
                        kirim_pesan "⚠️ <b>BLOKIR KEAMANAN:</b> Perintah berbahaya ditolak."
                        continue
                    fi

                    kirim_pesan "🔍 Cek: <code>$CMD_SHELL</code>"
                    HASIL=$(timeout 5s eval "$CMD_SHELL" 2>&1 | head -c 2000)
                    if [ -z "$HASIL" ]; then HASIL="(Kosong/Selesai)"; fi
                    kirim_pesan "<pre>$HASIL</pre>"
                fi

                # E. SAFE TUNNEL ROTATION (Rollback System)
                if [[ "$MSG_TEXT" == "/set_tunnel"* ]]; then
                    if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                    
                    TOKEN_BARU=$(echo "$MSG_TEXT" | awk '{print $2}')
                    if [ ${#TOKEN_BARU} -lt 30 ]; then kirim_pesan "❌ Token terlalu pendek!"; continue; fi
                    
                    kirim_pesan "🔄 <b>TESTING TOKEN BARU...</b>%0A(Auto-revert dalam 15 detik jika gagal)"
                    
                    # Backup Token Lama
                    TOKEN_LAMA=$(grep "TUNNEL_TOKEN=" "$CONFIG_FILE" | cut -d'"' -f2)
                    
                    # Apply Baru & Restart
                    sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\"$TOKEN_BARU\"|" "$CONFIG_FILE"
                    pkill -f cloudflared
                    nohup cloudflared tunnel run --token "$TOKEN_BARU" >/dev/null 2>&1 &
                    
                    # Tunggu & Verifikasi
                    sleep 15
                    if pgrep -f cloudflared >/dev/null; then
                        kirim_pesan "✅ <b>SUKSES!</b> Token baru aktif."
                    else
                        kirim_pesan "⚠️ <b>GAGAL!</b> Kembali ke token lama..."
                        sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=\"$TOKEN_LAMA\"|" "$CONFIG_FILE"
                        nohup cloudflared tunnel run --token "$TOKEN_LAMA" >/dev/null 2>&1 &
                    fi
                fi

                # F. UPDATE SCRIPT
                if [[ "$MSG_TEXT" == "/update"* ]]; then
                     if [ "$SENDER_ID" != "$ADMIN_ID" ]; then continue; fi
                     kirim_pesan "⬇️ Memulai Update v4.5..."
                     curl -sL "$GITHUB_URL" > "$HOME/update_temp.sh"
                     bash "$HOME/update_temp.sh" mode_update
                fi

                # Update Offset agar pesan tidak diproses ulang
                OFFSET=$UPDATE_ID
                
            done <<< "$PARSED_DATA"
        fi
    fi

    # Auto Backup Counter (6 Jam)
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge 4320 ]; then kirim_backup_zip "Auto Backup"; COUNTER=0; fi
    sleep 5
done
EOF
    chmod +x "$SERVICE_FILE"

    # ======================================================
    # 2. MENULIS MANAGER SCRIPT (MENU LOKAL)
    # ======================================================
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
    fi
    nohup bash "$SERVICE_FILE" >/dev/null 2>&1 &
    echo "✅ Service Started."
}

tampilkan_menu() {
    source "$CONFIG_FILE"
    while true; do
        clear
        echo "=== KASIRLITE v4.5: $NAMA_TOKO ==="
        echo "1. Cek Status Local"
        echo "2. Kirim Backup Manual"
        echo "3. Restart Service"
        echo "0. Keluar"
        read -p "Pilih: " PIL
        case $PIL in
            1) curl -I http://127.0.0.1:7575; read -p "Enter..." ;;
            2) 
               echo "Mengirim Backup..."
               cd "/storage/emulated/0/KasirToko/database" && zip -r -q "$HOME/manual.zip" .
               curl -s -F chat_id="$CHAT_ID" -F document=@"$HOME/manual.zip" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
               rm "$HOME/manual.zip"; read -p "Selesai..." ;;
            3) jalankan_layanan; sleep 2 ;;
            0) exit ;;
        esac
    done
}

if [ "$1" == "start" ] || [ "$1" == "restart_remote" ]; then 
    jalankan_layanan
else 
    tampilkan_menu
fi
EOF
    chmod +x "$MANAGER_FILE"
}

# ======================================================
# 3. LOGIKA INSTALASI / UPDATE
# ======================================================

if [ "$1" == "mode_update" ]; then
    # --- MODE UPDATE ---
    source "$CONFIG_FILE"
    # Pastikan ADMIN_ID ada (Migrasi dari v4.3 ke v4.5)
    if ! grep -q "ADMIN_ID" "$CONFIG_FILE"; then
        # Jika belum ada, gunakan CHAT_ID sebagai fallback sementara
        echo "ADMIN_ID=\"$CHAT_ID\"" >> "$CONFIG_FILE"
    fi
    update_system_files
    bash "$MANAGER_FILE" start
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="✅ <b>UPDATE v4.5 SUKSES!</b>%0ASistem sekarang aman & stabil." -d parse_mode="HTML" >/dev/null
    rm "$HOME/update_temp.sh" 2>/dev/null
    exit 0
else
    # --- MODE INSTALL BARU ---
    clear
    termux-wake-lock
    pkg update -y >/dev/null 2>&1 && pkg install -y cloudflared curl jq termux-api zip >/dev/null 2>&1
    termux-setup-storage
    mkdir -p "$DIR_UTAMA"
    
    UNIT=$(tr -dc A-Z0-9 </dev/urandom | head -c 4)
    # Kirim kode pairing
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="🔔 Pairing Request: <code>$UNIT</code>" -d parse_mode="HTML" >/dev/null
    echo "Menunggu Admin... Kode: $UNIT"
    
    OFFSET=0
    while true; do
        R=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates?offset=$((OFFSET+1))")
        OFFSET=$(echo "$R" | jq -r '.result[-1].update_id // empty')
        
        # Ambil pesan terakhir untuk pairing
        LAST_MSG=$(echo "$R" | jq '.result[-1].message // empty')
        TXT=$(echo "$LAST_MSG" | jq -r '.text // empty')
        
        if [[ "$TXT" == "/deploy $UNIT"* ]]; then
             TOKEN=$(echo "$TXT" | awk '{print $3}')
             NAMA=$(echo "$TXT" | awk '{print $4}')
             # OTOMATIS AMBIL ID PENGIRIM SEBAGAI ADMIN UTAMA
             SENDER_ID=$(echo "$LAST_MSG" | jq -r '.from.id // empty')
             
             [ -z "$NAMA" ] && NAMA="Cabang-$UNIT"
             break
        fi
        sleep 2
    done
    
    # Simpan Config dengan ADMIN_ID
    cat <<EOF > "$CONFIG_FILE"
NAMA_TOKO="$NAMA"
TUNNEL_TOKEN="$TOKEN"
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
ADMIN_ID="$SENDER_ID"
GITHUB_URL="$GITHUB_URL"
EOF
    update_system_files
    
    # Setup Alias
    source ~/.bashrc
    if ! grep -q "alias menu=" ~/.bashrc; then
        echo "alias menu='bash $MANAGER_FILE'" >> ~/.bashrc
        echo "alias nyala='bash $MANAGER_FILE start'" >> ~/.bashrc
    fi
    
    bash "$MANAGER_FILE" start
fi
