{ pkgs ? import <nixpkgs> { } }:
with pkgs;
writeShellApplication {
  name = "yubikey-piv-init";
  
  runtimeInputs = [ yubikey-manager ];
  text = builtins.readFile ./yubikey-piv-init.sh;
}
