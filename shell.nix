# Hugo from the nixos-26.05 channel. Keep the version in sync with HUGO_VERSION in netlify.toml.
{ pkgs ? import (fetchTarball "channel:nixos-26.05") { } }:
pkgs.mkShell {
  buildInputs = [ pkgs.hugo ];
}
