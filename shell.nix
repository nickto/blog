with import <nixpkgs> { };
let
  shell = mkShell {
  buildInputs = [
    hugo
  ];
  };
in
shell
