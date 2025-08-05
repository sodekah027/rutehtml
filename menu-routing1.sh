#!/usr/bin/env bash

CONFIG="/var/lib/marzban/xray_config.json"

# ======== FUNCTION =========

show_rules() {
    echo "===== RULE DOMAIN YANG TERPASANG (server-routing) ====="
    jq -r '.routing.rules[] | select(.outboundTag=="server-routing") .domainSuffix[]?' "$CONFIG" | nl -w2 -s'. '
    echo "========================================================"
}

add_rule() {
    read -rp "Masukkan domain baru (ex: wifiman.me) : " DOMAIN
    [ -z "$DOMAIN" ] && echo "batal." && return

    # ===== Cek apakah outbound server-routing sudah ada ======
    HAS_OUTBOUND=$(jq '.outbounds[]? | select(.tag=="server-routing")' "$CONFIG")
    if [[ -z "$HAS_OUTBOUND" ]]; then
      echo "Outbound belum ada... membuat..."
      jq '.
          | .outbounds += [{
              "tag":"server-routing",
              "protocol":"vless",
              "settings":{
                  "vnext":[
                    {
                      "address":"",
                      "port":443,
                      "users":[{ "id":"","encryption":"none"}]
                    }
                  ]
                },
              "streamSettings":{
                "network":"ws",
                "security":"tls",
                "tlsSettings":{"serverName":"","allowInsecure":true},
                "wsSettings":{"path":"/vless","headers":{"Host":""}}
              }
            }]' "$CONFIG" > tmp && mv tmp "$CONFIG"
    fi

    # ====== Cek apakah sudah ada rule server-routing ==========
    HAS_RULE=$(jq '.routing.rules[]? | select(.outboundTag=="server-routing")' "$CONFIG")
    if [[ -z "$HAS_RULE" ]]; then
      echo "Rule belum ada... membuat rule baru..."
      jq '.
          | .routing.rules += [{
              "type":"field",
              "domain":[],
              "outboundTag":"server-routing"
            }]' "$CONFIG" > tmp && mv tmp "$CONFIG"
    fi

    # ===== Tambahkan DOMAIN ke rule =====
    jq --arg d "$DOMAIN" \
      '(.routing.rules[] | select(.outboundTag=="server-routing") .domain) += [$d]' \
       "$CONFIG" > tmp && mv tmp "$CONFIG"

    echo "✔ Domain '$DOMAIN' telah ditambahkan."
    echo "→ silahkan buat_token / restart marzban / reboot"
}

del_rule() {
    show_rules
    read -rp "Masukkan domain yang ingin dihapus : " DOMAIN
    [ -z "$DOMAIN" ] && echo "batal." && return

    jq --arg d "$DOMAIN" \
      '(.routing.rules[] | select(.outboundTag=="server-routing") .domain) -= [$d]' \
      "$CONFIG" > tmp && mv tmp "$CONFIG"

    echo "✔ Domain '$DOMAIN' dihapus."
    echo "→ silahkan buat_token / restart marzban / reboot"
}

change_account() {
    read -rp "Address VLESS ROUTING : " ADDR
    read -rp "UUID VLESS ROUTING    : " UUID

    jq --arg a "$ADDR" --arg u "$UUID" \
      '(.outbounds[]| select(.tag=="server-routing")| .settings.vnext[0].address) = $a |
       (.outbounds[]| select(.tag=="server-routing")| .settings.vnext[0].users[0].id) = $u |
       (.outbounds[]| select(.tag=="server-routing")| .streamSettings.tlsSettings.serverName) = $a |
       (.outbounds[]| select(.tag=="server-routing")| .streamSettings.wsSettings.headers.Host) = $a' \
       "$CONFIG" > tmp && mv tmp "$CONFIG"

    echo "✔ Akun server-routing telah diganti."
    echo "→ silahkan buat_token / restart marzban / reboot"
}

# ================= MAIN MENU ==================

while true; do
echo "========== MENU ROUTING =========="
echo "1) Tambah Rule"
echo "2) Hapus Rule"
echo "3) Ganti Akun Routing"
echo "4) Lihat Rule yang aktif"
echo "0) Keluar"
echo "=================================="
read -rp "Pilih menu : " MENU

case "$MENU" in
    1) add_rule ;;
    2) del_rule ;;
    3) change_account ;;
    4) show_rules ;;
    0) exit 0 ;;
    *) echo "Salah pilih!" ;;
esac
echo ""
done
