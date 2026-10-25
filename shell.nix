with import <nixpkgs> { };
let
  # Pinned to the version used by Netlify (see netlify.toml).
  hugoVersion = "0.146.1";
  hugo = stdenv.mkDerivation {
    pname = "hugo-extended";
    version = hugoVersion;
    src = fetchurl {
      url = "https://github.com/gohugoio/hugo/releases/download/v${hugoVersion}/hugo_extended_${hugoVersion}_linux-amd64.tar.gz";
      sha256 = "0wrkdgqclkzs8lb5q69j6p3aadw94i9gcpfm0jhy6xfm7ji7p8f1";
    };
    sourceRoot = ".";
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    installPhase = ''
      install -Dm755 hugo $out/bin/hugo
    '';
  };
in
mkShell {
  buildInputs = [
    hugo
  ];
}
