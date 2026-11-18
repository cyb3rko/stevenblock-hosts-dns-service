# stevenblack-hosts-dns-service

Daily systemd-synced copy of the
[StevenBlack hosts](https://github.com/StevenBlack/hosts) file
(`fakenews-gambling-porn` variant) into `/etc/hosts`, merging your own
entries.

## How merging works

Your `/etc/hosts` keeps this layout:

```
...your entries, never touched by the service...

# >>> BEGIN local-hosts (auto-managed, do not edit)
...contents of local-hosts from this repo, replaced wholesale on each sync...
# <<< END local-hosts
# >>> BEGIN stevenblack-hosts (auto-managed, do not edit)
0.0.0.0 ads.example.com
...everything from the downloaded file, replaced wholesale on each sync...
# <<< END stevenblack-hosts
```

Anything **outside** the marked blocks (before or after them) is preserved
verbatim on every run. Your existing entries are already outside the blocks,
so the first run keeps all of them and just appends the managed blocks.
To add or remove your own entries, edit anywhere outside the blocks; to
uninstall the filter, delete everything between the two markers.

## Local extra entries (`local-hosts`)

The `local-hosts` file in this repo holds your own extra entries. On every
sync its contents are placed in a `local-hosts` block **above** the
StevenBlack block, where they take effect since they are first-match-wins.
Edit it in this repo, then either re-run `sudo ./install.sh` (which copies it
to `/etc/stevenblack-hosts/local-hosts`) or edit that installed copy directly,
and the next timer run picks it up. To force an immediate sync:

```
sudo systemctl start stevenblack-hosts.service
```

### Safety

- Download via `curl` from `raw.githubusercontent.com`, fails (leaving
  `/etc/hosts` untouched) on any error.
- Validation: rejects files <100 KB and files where <90% of non-comment lines
  are `<IP> <host...>` pairs (~161k entries validated per run here).
- Atomic install via `mktemp` + `mv` in the same directory, mode 644 root:root.
- Previous `/etc/hosts` copied to `/var/backups/hosts.stevenblack.bak`
  before any change.

## Install

```
sudo ./install.sh
```

This installs the script to `/usr/local/bin`, the units to
`/etc/systemd/system`, enables a daily timer (`OnCalendar=daily` + up to
30 min random delay, `Persistent=true` so a missed run catches up on boot),
and runs the first sync immediately, so the filter is active right away.
If that first sync fails (e.g. no network yet), `/etc/hosts` is left
unchanged and the timer retries later.

Manual run / logs:

```
sudo systemctl start stevenblack-hosts.service
journalctl -u stevenblack-hosts.service
```

## Test without installing

```
mkdir -p /tmp/sbtest/backup
cp /etc/hosts /tmp/sbtest/hosts
HOSTS_FILE=/tmp/sbtest/hosts \
BACKUP_FILE=/tmp/sbtest/backup/hosts.bak \
LOCAL_HOSTS_FILE=./local-hosts \
./stevenblack-hosts-sync.sh
```

Note: with ~161k filter lines (~4–5 MB) `/etc/hosts` is fed to glibc's
resolver; it is fully read into memory, so per-lookup cost is one mmap of the
file — this is the standard approach used by hosts-file blockers, but if you
notice slower first-lookup latency you can switch the URL to a
smaller variant later by editing `URL` in the script.
