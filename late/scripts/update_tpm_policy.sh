#!/bin/bash -e
#
# Script to read current clevis passphrase stored to TPM with no PCR policy
# and update it to a new clevis passphrase stored to TPM with policy tied to
# secure boot state.
#
# intended use is OOBE.  Slot numbers are hardcoded from coming into OOBE.
#

usage() {
    exec >&2
    echo
    echo "Usage: $0 -d DEV"
    echo
    echo "Updates TPM policy to use PCR7":
    echo
    echo "  -d DEV  The bound LUKS device"
    echo
    exit 2
}

luks2_jwe() {
    # jose jwe fmt -c outputs extra \n, so clean it up
    cryptsetup token export "$@" \
        | jose fmt -j- -Og jwe -o- \
        | jose jwe fmt -i- -c \
        | tr -d '\n'

    local rc
    for rc in "${PIPESTATUS[@]}"; do
        [ $rc -eq 0 ] || return $rc
    done
    return 0
}

get_current_passphrase() {
cryptsetup luksDump "$1" | sed -rn 's|^\s+([0-9]+): clevis|\1|p' |
while read -r id; do
    jwe="$(luks2_jwe --token-id "$id" "$1")" || continue

    if pt="$(echo -n "$jwe" | clevis decrypt)"; then
        echo -n "$pt"
        break
    fi
done
}

while getopts "d:" o; do
    case "$o" in
    d) DEV="$OPTARG";;
    *) usage;;
    esac
done

if [ -z "$DEV" ]; then
    echo "Did not specify a device!" >&2
    usage
fi

if ! cryptsetup isLuks "$DEV"; then
    echo "$DEV is not a LUKS device!" >&2
    exit 1
fi

CURRENT=$(get_current_passphrase $DEV)
echo $CURRENT | clevis luks bind -d $DEV -s 2 tpm2 '{"pcr_bank":"sha256", "pcr_ids":"7"}' -k -
clevis luks unbind -d $DEV -s 1 -f
