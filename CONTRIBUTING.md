# Contributing to brew-export

Thanks for your interest in improving brew-export, a script that snapshots your Homebrew setup and dotfiles into a portable tarball.

## Getting started

```sh
git clone https://github.com/zackwag/brew-export.git
cd brew-export
chmod +x brew_export.sh
./brew_export.sh
```

Requires macOS and [Homebrew](https://brew.sh). `fzf` is recommended for the interactive dotfile picker (falls back to a numbered checklist without it).

## Development

This is a single Bash script (`brew_export.sh`). There's no build step — edit the script directly and run it to test your changes. The Homebrew formula (`homebrew-tap/Formula/brew-export.rb`) just installs this script as `brew-export`; its formula test only checks the binary is executable.

Run [ShellCheck](https://www.shellcheck.net/) locally before opening a PR (`shellcheck brew_export.sh`, `brew install shellcheck` if you don't have it) — CI runs the same check and must pass.

## Commit messages and pull requests

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`, etc.). Pull requests are squash-merged, and the **PR title** becomes the commit on `main` — so PR titles must follow this format. This is enforced automatically by the "Conventional Commits" check.

Direct pushes to `main` are allowed but must also use a Conventional Commits-formatted commit message (validated by the same check).

## Opening a pull request

1. Fork the repo and create a branch off `main`.
2. Make your changes.
3. Open a pull request with a Conventional Commits-formatted title.
4. Wait for CI to pass — required checks must be green before merge.

## Reporting issues

Use [GitHub Issues](../../issues) for bugs and feature requests.
