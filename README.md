## Development

1. Clone the repo with submodules: `git clone --recurse-submodules <url>` (or, in an existing clone, `git submodule update --init --recursive`).
2. The Hugo version is pinned in `shell.nix` and in `netlify.toml` (`HUGO_VERSION`); keep them in sync.
3. Add `use nix` to `.envrc`; run `direnv allow`.
4. Start the server: `hugo server --buildDrafts`.

## TODO

- Switch comments to giscus (currently disabled; Disqus removed).
