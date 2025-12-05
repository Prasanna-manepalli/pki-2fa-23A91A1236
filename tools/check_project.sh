#!/usr/bin/env bash
set -euo pipefail
echo "=== Project root: $(pwd) ==="
echo
echo "1) Git-tracked files (top 500):"
git ls-files | sed -n '1,500p' || true
echo
echo "2) Disk tree (non-hidden) recursively (first 200 lines):"
ls -laR | sed -n '1,200p' || true
echo
echo "3) Expected files (from README spec):"
cat <<'EOF'
student_private.pem
student_public.pem
instructor_public.pem
encrypted_signature.b64
Dockerfile
docker-compose.yaml
requirements.txt
.gitattributes
.gitignore
README.md
app/crypto_utils.py
app/totp_utils.py
app/server.py
app/generate_proof.py
scripts/cron_job.py
scripts/log_2fa_cron.py
scripts/run_cron.sh
scripts/run_uvicorn.sh
cron/totp_cron
cron/2fa-cron
EOF
echo
echo "4) Check which expected files are missing (on-disk):"
while IFS= read -r f; do
  if [[ -e "$f" ]]; then
    printf "OK     %-40s\n" "$f"
  else
    printf "MISSING %-40s\n" "$f"
  fi
done <<'EOF'
student_private.pem
student_public.pem
instructor_public.pem
encrypted_signature.b64
Dockerfile
docker-compose.yaml
requirements.txt
.gitattributes
.gitignore
README.md
app/crypto_utils.py
app/totp_utils.py
app/server.py
app/generate_proof.py
scripts/cron_job.py
scripts/log_2fa_cron.py
scripts/run_cron.sh
scripts/run_uvicorn.sh
cron/totp_cron
cron/2fa-cron
EOF
echo
echo "5) Name-mismatch quick checks:"
if [[ -f app/main.py ]]; then echo "Found app/main.py"; fi
if [[ -f app/server.py ]]; then echo "Found app/server.py"; fi
if [[ -f cron/totp_cron ]]; then echo "Found cron/totp_cron (used by Dockerfile)"; fi
if [[ -f cron/2fa-cron ]]; then echo "Found cron/2fa-cron (unused)"; fi
if [[ -f scripts/cron_job.py ]]; then echo "Found scripts/cron_job.py"; fi
if [[ -f scripts/log_2fa_cron.py ]]; then echo "Found scripts/log_2fa_cron.py"; fi
echo
echo "6) Show first 5 lines of cron files if present:"
if [[ -f cron/totp_cron ]]; then
  echo "---- cron/totp_cron ----"
  sed -n '1,5p' cron/totp_cron
fi
if [[ -f cron/2fa-cron ]]; then
  echo "---- cron/2fa-cron ----"
  sed -n '1,5p' cron/2fa-cron
fi
echo
echo "=== End of check ==="
