#!/usr/bin/env bash
# Syncs the StevenBlack hosts file (fakenews-gambling-porn variant) into
# /etc/hosts while preserving all user entries, plus an extra block of
# local entries from a repo-managed file.
#
# /etc/hosts layout used by this script:
#   <user entries, never touched>
#   # >>> BEGIN local-hosts (auto-managed, do not edit)
#   ...contents of LOCAL_HOSTS_FILE, replaced wholesale on every run...
#   # <<< END local-hosts
#   # >>> BEGIN stevenblack-hosts (auto-managed, do not edit)
#   ...downloaded block, replaced wholesale on every run...
#   # <<< END stevenblack-hosts
#
set -euo pipefail

URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
HOSTS_FILE="${HOSTS_FILE:-/etc/hosts}"
BACKUP_FILE="${BACKUP_FILE:-/var/backups/hosts.stevenblack.bak}"
LOCAL_HOSTS_FILE="${LOCAL_HOSTS_FILE:-/etc/stevenblack-hosts/local-hosts}"
LOCAL_BEGIN_MARKER="# >>> BEGIN local-hosts (auto-managed, do not edit)"
LOCAL_END_MARKER="# <<< END local-hosts"
BEGIN_MARKER="# >>> BEGIN stevenblack-hosts (auto-managed, do not edit)"
END_MARKER="# <<< END stevenblack-hosts"

tmp_download="$(mktemp)"
trap 'rm -f "$tmp_download" "$tmp_user"' EXIT
tmp_user="$(mktemp)"

# --- download -------------------------------------------------------------
if ! curl -fsSL --max-time 120 -o "$tmp_download" "$URL"; then
    echo "ERROR: download failed, /etc/hosts left unchanged" >&2
    exit 1
fi

# --- validate (never clobber /etc/hosts with an error page) ---------------
size="$(stat -c%s "$tmp_download")"
if (( size < 100000 )); then
    echo "ERROR: downloaded file suspiciously small ($size bytes), aborting" >&2
    exit 1
fi
total=0; valid=0
while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* || "$line" != *[![:space:]]* ]] && continue
    total=$((total + 1))
    if [[ "$line" =~ ^[0-9A-Fa-f:.]+[[:space:]]+[A-Za-z0-9._-]+([[:space:]]+[A-Za-z0-9._-]+)*[[:space:]]*$ ]]; then
        valid=$((valid + 1))
    fi
done < "$tmp_download"
if (( total < 1000 || valid * 10 < total * 9 )); then
    echo "ERROR: downloaded file failed validation ($valid/$total valid entries), aborting" >&2
    exit 1
fi

# --- extract user content (everything except both managed blocks) ---------
if [[ ! -f "$HOSTS_FILE" ]]; then
    echo "ERROR: $HOSTS_FILE does not exist" >&2
    exit 1
fi
in_block=0
while IFS= read -r line; do
    case "$line" in
        "$LOCAL_BEGIN_MARKER"|"$BEGIN_MARKER") in_block=1; continue ;;
        "$LOCAL_END_MARKER"|"$END_MARKER") in_block=0; continue ;;
    esac
    (( in_block )) || printf '%s\n' "$line" >> "$tmp_user"
done < "$HOSTS_FILE"

# --- build new hosts file (atomic install) --------------------------------
tmp_hosts="$(mktemp "${HOSTS_FILE%/*}/.hosts.XXXXXX")"
{
    cat "$tmp_user"
    if [[ -f "$LOCAL_HOSTS_FILE" ]]; then
        printf '%s\n' "$LOCAL_BEGIN_MARKER"
        cat "$LOCAL_HOSTS_FILE"
        printf '%s\n' "$LOCAL_END_MARKER"
    fi
    printf '%s\n' "$BEGIN_MARKER"
    cat "$tmp_download"
    printf '%s\n' "$END_MARKER"
} > "$tmp_hosts"

if ! cmp -s "$tmp_hosts" "$HOSTS_FILE" && [[ -f "$HOSTS_FILE" ]]; then
    mkdir -p "$(dirname "$BACKUP_FILE")"
    cp "$HOSTS_FILE" "$BACKUP_FILE"
fi

chmod 644 "$tmp_hosts"
[[ $(id -u) -eq 0 ]] && chown 0:0 "$tmp_hosts"
if mv "$tmp_hosts" "$HOSTS_FILE"; then
    echo "OK: synced $(grep -c '^[0-9A-Fa-f:.]' "$HOSTS_FILE") entries ($valid validated), local block from $LOCAL_HOSTS_FILE, backup at $BACKUP_FILE"
else
    rm -f "$tmp_hosts"
    echo "ERROR: failed to install $HOSTS_FILE" >&2
    exit 1
fi