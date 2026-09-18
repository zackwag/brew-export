# AGENTS.md

## Project overview

`brew_export.sh` — a single Bash script that snapshots a Homebrew setup (formulae, casks, taps, Mac App Store apps) plus selected dotfiles into a portable tarball with a self-contained install script.

## Setup

No install step. macOS + [Homebrew](https://brew.sh) required; `fzf` optional (interactive dotfile picker, falls back to a numbered checklist).

## Build / Run

```sh
./brew_export.sh [name]
```

## Test

No automated test suite. The Homebrew formula in `homebrew-tap/Formula/brew-export.rb` only asserts the installed binary is executable (`brew test`); it doesn't exercise the script's logic.

## Repository structure

- `brew_export.sh` — the entire tool
- `.github/workflows/update-tap.yml` — on a GitHub release, computes the new version/sha256 and pushes a formula update directly to `zackwag/homebrew-tap` via a PAT (`HOMEBREW_TAP_TOKEN`)

## Commit and PR conventions

- Commit messages and PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`, `build:`, `perf:`, `style:`, `revert:`), optionally with a scope, e.g. `fix(api): handle null response`.
- This repo squash-merges pull requests only; the PR title becomes the final commit message on `main`.
- A "Conventional Commits" CI check enforces this on both PR titles and direct-push commit messages.
- A "ShellCheck" CI check lints `brew_export.sh` on every PR and push to `main`. Fix reported issues rather than disabling them where possible; use a targeted `# shellcheck disable=SCxxxx` comment with a reason when a warning is a false positive.
- Branch protection on `main`: no force-pushes, no branch deletion, required status checks must pass.
- **Known issue (affects `homebrew-tap`, not this repo directly):** `update-tap.yml` pushes a commit to `homebrew-tap`'s `main` on every release, with message `Update brew-export to vX.Y.Z` — not Conventional-Commits-formatted, and a direct push rather than a PR. Since `homebrew-tap` now also requires the "Conventional Commits" check, this release automation will likely fail on the next release. Needs a fix — not addressed by this change.
