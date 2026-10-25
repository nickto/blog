with import <nixpkgs> { };
let
  # Pinned to the version used by Netlify. Keep in sync with HUGO_VERSION in netlify.toml.
  hugoVersion = "0.168.0";
  hugo = stdenv.mkDerivation {
    pname = "hugo-extended";
    version = hugoVersion;
    src = fetchurl {
      url = "https://github.com/gohugoio/hugo/releases/download/v${hugoVersion}/hugo_extended_${hugoVersion}_linux-amd64.tar.gz";
      hash = "sha256-eH8QAFcyiCTzjGrXyH/xDWRRrgp7w5ztqtDdK83hflM=";
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
