#!/usr/bin/env bash
# Skenario uji kegagalan untuk sistem load balancer + replicated app.
#
# Cara pakai:
#   bash src/tests/uji_kegagalan.sh              # seluruh skenario
#   URL=http://localhost:8080 bash src/tests/uji_kegagalan.sh
#
# Perkakas opsional: hey (brew install hey) untuk uji beban 1000 permintaan.
# Hasil setiap skenario disalin ke docs/hasil-uji-kegagalan.md.
set -u

URL="${URL:-http://localhost:8080}"
PROYEK="github.com/KELOMPOK-3-MK3/mkkl1030-loadbalancer-redis"

catat() { printf '\n%s\n' "$*"; }

# Menghitung berapa respons yang dilayani tiap app server.
hitung_server() {
  awk -F'"server": *"' '{if (NF>1) {split($2,a,"\""); c[a[1]]++}}
                          END {for (s in c) printf "  %s: %d respons\n", s, c[s]}'
}

# Menghitung alamat upstream dari log akses Nginx. Dipakai untuk membuktikan
# pembagian beban pada uji beban tinggi: dua cuplikan (sebelum dan sesudah)
# dibandingkan, selisihnya adalah milik uji beban itu sendiri.
hitung_upstream() {
  docker compose logs nginx 2>/dev/null \
    | grep -o 'upstream=[0-9.]*:[0-9]*' \
    | sed 's/upstream=//' | sort | uniq -c
}

# Menunggu sebuah container berstatus healthy (maks 40 detik).
tunggu_sehat() {
  local nama="$1" status
  for _ in $(seq 1 20); do
    status=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}tanpa-healthcheck{{end}}' "$nama" 2>/dev/null)
    if [ "$status" = "healthy" ] || [ "$status" = "tanpa-healthcheck" ]; then
      echo "  $nama siap ($status)"
      return 0
    fi
    sleep 2
  done
  echo "  $nama belum siap setelah 40 detik"
  return 1
}

# ===========================================================================
catat "=== 1. Keadaan normal: 10 permintaan, catat app yang melayani ==="
NORMAL=$(for i in $(seq 1 10); do curl -s "$URL/"; echo; done)
echo "$NORMAL"
echo "$NORMAL" | hitung_server

# ===========================================================================
catat "=== 2. Beban tinggi: 1000 permintaan, 50 bersamaan ==="
# Cuplikan log sebelum uji beban, supaya bisa dihitung selisihnya sesudah.
SEBELUM_LOG=$(hitung_upstream)
if command -v hey >/dev/null 2>&1; then
  hey -n 1000 -c 50 "$URL/" 2>&1 | grep -Ei \
    'Requests/sec|Total:|Average:|Fastest:|Slowest:|Status code|\[200\]|response time histogram' \
    | head -20
else
  echo "  hey tidak terpasang — dilewati (pasang: brew install hey)"
fi
SESUDAH_LOG=$(hitung_upstream)
echo "--- pembagian upstream (selisih log sebelum vs sesudah uji beban) ---"
python3 - "$SEBELUM_LOG" "$SESUDAH_LOG" <<'PY'
import re, sys

def baca(teks):
    hasil = {}
    for baris in teks.strip().splitlines():
        m = re.match(r'\s*(\d+)\s+(\S+)', baris)
        if m:
            hasil[m.group(2)] = int(m.group(1))
    return hasil

sebelum, sesudah = baca(sys.argv[1]), baca(sys.argv[2])
total = 0
for alamat in sorted(set(sebelum) | set(sesudah)):
    naik = sesudah.get(alamat, 0) - sebelum.get(alamat, 0)
    total += naik
    print(f"  {alamat:22} +{naik}")
if total:
    for alamat in sorted(set(sebelum) | set(sesudah)):
        naik = sesudah.get(alamat, 0) - sebelum.get(alamat, 0)
        print(f"  {alamat:22} {naik / total * 100:5.1f}%")
    print(f"  total tercatat: {total} permintaan")
PY

# ===========================================================================
catat "=== 3. Matikan app1 saat sistem berjalan ==="
docker compose stop app1 >/dev/null 2>&1
echo "--- 5 permintaan setelah app1 mati (harus dijawab app2) ---"
SAAT_MATI=$(for i in $(seq 1 5); do curl -s "$URL/"; echo; done)
echo "$SAAT_MATI"
echo "$SAAT_MATI" | hitung_server
docker compose start app1 >/dev/null 2>&1
tunggu_sehat mkkl1030-loadbalancer-redis-app1-1

# ===========================================================================
catat "=== 4. Restart Redis dan periksa ketahanan status ==="
SEBELUM=$(curl -s "$URL/state")
echo "sebelum: $SEBELUM"
docker compose restart redis >/dev/null 2>&1
tunggu_sehat mkkl1030-loadbalancer-redis-redis-1
sleep 2
SESUDAH=$(curl -s "$URL/state")
echo "sesudah: $SESUDAH"
python3 - "$SEBELUM" "$SESUDAH" <<'PY'
import json, sys
a, b = (json.loads(x) for x in sys.argv[1:3])
print("  nilai permintaan_total bertahan" if a.get("permintaan_total") == b.get("permintaan_total")
      else f"  BERUBAH: {a.get('permintaan_total')} -> {b.get('permintaan_total')}")
PY

# ===========================================================================
catat "=== 5. Batas waktu baca: permintaan 8 detik dengan proxy_read_timeout 5s ==="
echo "  klien mengirim /slow?detik=8 (maks tunggu 30 detik)"
T0=$(python3 -c 'import time; print(time.time())')
KODE=$(curl -s -m 30 -o /tmp/slow-body.txt -w '%{http_code}' "$URL/slow?detik=8")
T1=$(python3 -c 'import time; print(time.time())')
echo "  kode HTTP: $KODE"
echo "  isi: $(cat /tmp/slow-body.txt)"
python3 -c "print(f'  waktu tanggap klien: {($T1-$T0)*1000:.0f} ms')"

# ===========================================================================
catat "=== 6. Redis mati: app server tetap melayani, status kesehatan menurun ==="
docker compose stop redis >/dev/null 2>&1
sleep 2
echo "--- permintaan saat Redis mati (tidak boleh 5xx) ---"
curl -s -o /tmp/mati-body.txt -w '  kode HTTP: %{http_code}\n' "$URL/"
echo "  isi: $(cat /tmp/mati-body.txt)"
echo "--- status kesehatan (harus 503 agar node dibuang dari perputaran) ---"
curl -s -o /dev/null -w '  kode HTTP: %{http_code}\n' "$URL/health"
docker compose start redis >/dev/null 2>&1
tunggu_sehat mkkl1030-loadbalancer-redis-redis-1

catat "=== Selesai ==="
docker compose ps
