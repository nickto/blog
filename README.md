## Development

1. Clone the repo with submodules: `git clone --recurse-submodules <url>` (or, in an existing clone, `git submodule update --init --recursive`).
2. The Hugo version is pinned in `shell.nix` and in `netlify.toml` (`HUGO_VERSION`); keep them in sync.
3. Add `use nix` to `.envrc`; run `direnv allow`.
4. Start the server: `hugo server --buildDrafts`.

## Writing posts

- Put posts with their own files (images, PDFs) in a page bundle: `content/posts/<name>/index.md`, with the files next to it, and link to them by relative path.
- MathJax is loaded only on posts that set `math: true` in the front matter.

## Deployment

Netlify builds the site from `master` with `hugo --gc --minify` (see `netlify.toml`). Deploy previews and branch deploys use the same command with `-b $DEPLOY_PRIME_URL`.

## TODO

- Switch comments to giscus (currently disabled; Disqus removed).
