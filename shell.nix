{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell { buildInputs = [ yubikey-manager yubico-piv-tool ]; }
