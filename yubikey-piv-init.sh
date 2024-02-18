#
# Constraints:
# * macOS PKCS11 for SSH (ssh-keychain.dylib) only supports RSA keys
#   * YubiKey firmware 4.2.0 - 4.3.4 generate weak RSA keys (disabled)
# * macOS smartcard auth uses slots 9a + 9d (ECC or RSA)
#

PIN=123456
readonly PIN

PUK=12345678
readonly PUK

KEY=010203040506070801020304050607080102030405060708
readonly KEY

TMPDIR=$(mktemp -d)
readonly TMPDIR

# TODO
#readonly PIV_VERS=$(ykman piv info | grep "PIV version" | awk '{print $3}')

function generate_key() {
    local slot="$1"
    local alg="$2"
    
    shift 2
    
    local rest=$*
    
    # Require touch on all key operations for all slots
    
    #shellcheck disable=SC2086
    ykman piv keys generate -m ${KEY} -P ${PIN} \
	  -a "${alg}" ${rest} "${slot}" "${TMPDIR}/${slot}.pem"

    # Use attestation cert as the slot's certificate
    ykman piv keys attest "${slot}" "${TMPDIR}/${slot}_cert.pem"
    
    ykman piv certificates import -m ${KEY} -P ${PIN} \
	  "${slot}" "${TMPDIR}/${slot}_cert.pem"
}

function random_digits() {
    local length="$1"

    shuf --random-source=/dev/urandom -i 0-9 -r -n "${length}" | paste -sd ''
}

function main() {
    # Algorithm used for macOS authentication slots
    local mac_alg=ECCP256

    # Algorithm used for digital signature slot
    local sig_alg=ECCP384

    # Algorithm used for SSH key slots (e.g. Card Authentication)
    local ssh_alg=RSA2048

    echo "Resetting PIV applet..."
    ykman piv reset

    echo "Generating CCC and CHUID..."
    ykman piv objects generate ccc -m ${KEY} -P ${PIN}
    ykman piv objects generate chuid -m ${KEY} -P ${PIN}

    #
    # Generate PIV keys and use attestation certificates as their certs
    #
    echo "Generating PIV Authentication certificate..."
    generate_key 9a ${mac_alg} "--pin-policy ONCE --touch-policy CACHED"

    echo "Generating Digital Signature certificate..."
    generate_key 9c ${sig_alg} "--pin-policy ALWAYS --touch-policy ALWAYS"
    
    echo "Generating Key Management certificate..."
    generate_key 9d ${mac_alg} "--pin-policy ONCE --touch-policy CACHED"

    # Use RSA for Card Auth for compat w/ macOS SSH PKCS11 library
    echo "Generating Card Authentication certificate..."
    generate_key 9e ${ssh_alg} "--pin-policy NEVER --touch-policy NEVER"

    #
    # Reset management key, PIN, and PUK to random values
    #
    echo "Resetting management key to random key protected by PIN and touch..."
    ykman piv access change-management-key -m ${KEY} -P ${PIN} -p -t

    echo "Resetting PIN to a random PIN..."
    local newpin
    newpin=$(random_digits 6)
    ykman piv access change-pin -P ${PIN} -n "${newpin}"
    echo "PIN:${newpin}"

    echo "Resetting PUK to a random PUK..."
    local newpuk
    newpuk=$(random_digits 8)
    ykman piv access change-puk -p ${PUK} -n "${newpuk}"
    echo "PUK:${newpuk}"
}

main "$@"
