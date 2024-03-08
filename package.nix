{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
writeShellApplication {
  name = "yubikey-piv-init";

  runtimeInputs = [ coreutils yubikey-manager ];
  text = builtins.readFile ./yubikey-piv-init.sh;
}
