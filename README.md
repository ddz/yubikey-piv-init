# yubikey-piv-init
Opinionated initialization of YubiKey PIV applet

## Description

This script initializes the PIV applet on a Yubikey to be compatible
with a few applications, including:
* macOS [smart card authentication](https://developers.yubico.com/PIV/Guides/Smart_card-only_authentication_on_macOS.html)
* macOS [ssh-keychain.dylib](https://keith.github.io/xcode-man-pages/ssh-keychain.8.html)

## PIV Slot Configuration

All slots use the Yubikey-generated attestation certificate as the
slot certificate. This provides proof of hardware key generation, a
copy of the public key, PIN and touch policy configuration for the
slot.

### PIV Authentication (9a) and Key Management (9d)

These two slots store ECCP256 keys, require the PIN once per session,
and require a touch per operation with caching enabled. They are
configured to support macOS smart card authentication, which does not
currently support ECCP384 on PIV tokens.

### Digital Signature (9c)

This slot stores an ECCP384 key, requiring a PIN and touch for every
operation. This is intended to provide the maximum level of security
for signing operations.

### Card Authentication (9a)

This slot stores an RSA2048 key without requiring a PIN nor touch for
key operations in order to enable automatic authentication based on
physical possession of the Yubikey. RSA2048 was chosen for
compatibility with macOS `ssh-keychain.dylib`.

It is recommended that this only be used for trusted-device
authorization and not user-based authentication. For example, it could
be used as a device certificate for access to systems that perform
additional verification of user credentials.

## Usage

### Initialization

```
$ nix run github:ddz/yubikey-piv-init
Resetting PIV applet...
WARNING! This will delete all stored PIV data and restore factory settings. Proceed? [y/N]: y
Resetting PIV data...
Success! All PIV data have been cleared from the YubiKey.
Your YubiKey now has the default PIN, PUK and Management Key:
	PIN:	123456
	PUK:	12345678
	Management Key:	010203040506070801020304050607080102030405060708
Generating CCC and CHUID...
Generating PIV Authentication certificate...
Generating Digital Signature certificate...
Generating Key Management certificate...
Generating Card Authentication certificate...
Resetting management key to random key protected by PIN and touch...
Resetting PIN to a random PIN...
New PIN set.
PIN:274751
Resetting PUK to a random PUK...
New PUK set.
PUK:91744080
```

### macOS Authentication

The PIV Authentication (9a) and Card Management (9d) slots are
configured for
[smart card local pairing](https://support.apple.com/guide/deployment/use-a-smart-card-on-mac-depc705651a9/web)
for authentication to macOS.

### macOS SSH

The Card Authentication (9e) slot can be used for SSH authentication using
[SSH-KEYCHAIN(8)](https://keith.github.io/xcode-man-pages/ssh-keychain.8.html).


```
$ ssh-add -s /usr/lib/ssh-keychain.dylib
Enter passphrase for PKCS#11:
Card added: /usr/lib/ssh-keychain.dylib
```

```
$ ssh-add -L

```

```
$ ssh -o PKCS11Provider=/usr/lib/ssh-keychain.dylib <host>
```
