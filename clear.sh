#!/usr/bin/env bash
# Clear iServices caches after a failed iMessage / FaceTime / iCloud setup.
# Based on Dortania OpenCore Post-Install — "Clean out old attempts":
# https://dortania.github.io/OpenCore-Post-Install/universal/iservices.html
#
# Run on the macOS VM (not Linux/WSL). Before this script:
#   1. Sign out of Messages, FaceTime, and iCloud on the VM (optional but recommended).
#   2. Reset NVRAM from the OpenCore boot picker (Misc -> Security -> AllowNvramReset).
#   3. Reboot, then run this script.

set -euo pipefail

DRY_RUN=0
ASSUME_YES=0

usage() {
    cat <<'EOF'
Usage: clear-iservices-cache.sh [OPTIONS]

Remove cached iMessage / iCloud / identityservices data so a fresh iServices
login can regenerate keys (Dortania OpenCore iServices guide).

Options:
  -n, --dry-run   Print what would be removed; do not delete.
  -y, --yes       Skip confirmation prompt.
  -h, --help      Show this help.

Manual steps this script does NOT perform:
  - OpenCore NVRAM reset (do at boot picker before running)
  - Keychain cleanup (Keychain Access -> search "ids:", "iMessage", "facetime")
  - appleid.apple.com device list cleanup
EOF
}

log() {
    printf '==> %s\n' "$*"
}

warn() {
    printf '!! %s\n' "$*" >&2
}

remove_path() {
    local path=$1
    # shellcheck disable=SC2086
    local matches=( $path )

    if ((${#matches[@]} == 0)); then
        return 0
    fi

    for target in "${matches[@]}"; do
        if [[ ! -e "$target" ]]; then
            continue
        fi
        if ((DRY_RUN)); then
            printf '[dry-run] rm -rf %q\n' "$target"
        else
            rm -rf "$target"
            printf 'removed %s\n' "$target"
        fi
    done
}

while (($# > 0)); do
    case "$1" in
        -n | --dry-run) DRY_RUN=1 ;;
        -y | --yes) ASSUME_YES=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            warn "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    warn "This script must run on macOS (inside your VM)."
    exit 1
fi

cat <<'EOF'

This deletes local iServices caches and ~/Library/Messages (all iMessage history).

Do this AFTER OpenCore NVRAM reset and BEFORE signing into Messages/iCloud again.

Reference: https://dortania.github.io/OpenCore-Post-Install/universal/iservices.html

EOF

if (( ! ASSUME_YES && ! DRY_RUN )); then
    read -r -p "Continue? [y/N] " reply
    case "$reply" in
        [yY] | [yY][eE][sS]) ;;
        *)
            log "Aborted."
            exit 0
            ;;
    esac
fi

log "Stopping iServices agents (ignore errors if not running)..."
if ((DRY_RUN)); then
    printf '[dry-run] killall identityservicesd imagent avconferenced 2>/dev/null\n'
else
    killall identityservicesd imagent avconferenced 2>/dev/null || true
fi

log "Removing Caches (Dortania)..."
remove_path "${HOME}/Library/Caches/com.apple.iCloudHelper"*
remove_path "${HOME}/Library/Caches/com.apple.Messages"*
remove_path "${HOME}/Library/Caches/com.apple.imfoundation.IMRemoteURLConnectionAgent"*

log "Removing Preferences (Dortania)..."
remove_path "${HOME}/Library/Preferences/com.apple.iChat"*
remove_path "${HOME}/Library/Preferences/com.apple.icloud"*
remove_path "${HOME}/Library/Preferences/com.apple.imagent"*
remove_path "${HOME}/Library/Preferences/com.apple.imessage"*
remove_path "${HOME}/Library/Preferences/com.apple.imservice"*
remove_path "${HOME}/Library/Preferences/com.apple.ids.service"*
remove_path "${HOME}/Library/Preferences/com.apple.madrid.plist"*
remove_path "${HOME}/Library/Preferences/com.apple.imessage.bag.plist"*
remove_path "${HOME}/Library/Preferences/com.apple.identityserviced"*
remove_path "${HOME}/Library/Preferences/com.apple.security"*

log "Removing Messages data (Dortania)..."
remove_path "${HOME}/Library/Messages"

log "Removing ByHost idstatuscache (common follow-up to Dortania)..."
remove_path "${HOME}/Library/Preferences/ByHost/com.apple.identityservices.idstatuscache."*
remove_path "${HOME}/Library/Preferences/ByHost/"*idstatuscache*

log "Removing related FaceTime / IDS caches..."
remove_path "${HOME}/Library/Preferences/com.apple.facetime"*
remove_path "${HOME}/Library/Caches/com.apple.facetime"*
remove_path "${HOME}/Library/Caches/com.apple.bird"*
remove_path "${HOME}/Library/Caches/com.apple.CloudKit"*

if ((DRY_RUN)); then
    log "Dry run complete. No files were deleted."
else
    log "Done. Reboot the VM, then sign into iCloud and Messages again."
    log "Optional: clear Keychain entries (ids:, iMessage, FaceTime) per Dortania."
fi
