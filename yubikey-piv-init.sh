#
# Constraints:
# * macOS PKCS11 for SSH (ssh-keychain.dylib) only supports RSA keys
#   * YubiKey firmware 4.2.0 - 4.3.4 generate weak RSA keys (disabled)
# * macOS smartcard auth uses slots 9a + 9d (ECC or RSA)
#

set -euxo pipefail

YKMAN=$(which ykman)
readonly YKMAN

PIN=123456
readonly PIN

NEW_PIN=$(random_digits 6)
readonly NEW_PIN

PUK=12345678
readonly PUK

NEW_PUK=$(random_digits 8)
readonly NEW_PUK

KEY=010203040506070801020304050607080102030405060708
readonly KEY

TMPDIR=$(mktemp -d)
readonly TMPDIR

# TODO
#readonly PIV_VERS=$(${YKMAN} piv info | grep "PIV version" | awk '{print $3}')

function generate_key() {
    local slot="$1"
    local alg="$2"
    
    shift 2
    
    local rest=$*
    
    ${YKMAN} piv keys generate -m ${KEY} -P ${PIN} \
	  -a "${alg}" "$@" "${slot}" "${TMPDIR}/${slot}.pem"

    # Use attestation cert as the slot's certificate
    ${YKMAN} piv keys attest "${slot}" "${TMPDIR}/${slot}_cert.pem"
    
    ${YKMAN} piv certificates import -m ${KEY} -P ${PIN} \
	  "${slot}" "${TMPDIR}/${slot}_cert.pem"
}

function random_digits() {
    local length="$1"

    shuf --random-source=/dev/urandom -i 0-9 -r -n "${length}" | paste -sd ''
}

function main() {
    echo "Resetting PIV applet..."
    ${YKMAN} piv reset

    echo "Generating CHUID..."
    ${YKMAN} piv objects generate chuid -m ${KEY} -P ${PIN}

    #
    # Generate PIV keys and use attestation certificates as their certs
    #

    # macOS does not support P-384 for PIV-based logon, so use P-256
    echo "Generating PIV Authentication certificate..."
    generate_key 9a ECCP256 "--pin-policy ONCE --touch-policy ALWAYS"

    echo "Generating Key Management certificate..."
    generate_key 9d ECCP256 "--pin-policy ONCE --touch-policy CACHED"

    # Use RSA for Card Auth for compat w/ macOS SSH PKCS11 library to
    # be able to use this slot for device-based authentication
    echo "Generating Card Authentication certificate..."
    generate_key 9e RSA2048 "--pin-policy NEVER --touch-policy ALWAYS"

    #
    # Reset management key, PIN, and PUK to random values
    #
    echo "Resetting management key to random key protected by PIN and touch..."
    ${YKMAN} piv access change-management-key -m ${KEY} -P ${PIN} -p -t

    echo "Resetting PIN to a random PIN..."
    ${YKMAN} piv access change-pin -P ${PIN} -n "${NEW_PIN}"
    echo "PIN:${NEW_PIN}"

    echo "Resetting PUK to a random PUK..."
    ${YKMAN} piv access change-puk -p ${PUK} -n "${NEW_PUK}"
    echo "PUK:${NEW_PUK}"
}

main "$@"
