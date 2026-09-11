# 🍺 brew-export

> Export your Homebrew setup — taps, packages, casks, and Mac App Store apps — into a portable Brewfile and self-contained install script.

`brew_export.sh` snapshots your entire Homebrew environment and selected dotfiles into a single tarball you can drop on a new Mac and run. One script in, one script out.

---

## Features

- 📦 Dumps a `Brewfile` via `brew bundle` — formulae, casks, taps, and MAS apps
- 🔧 Detects custom taps and bakes them into the install script
- 🛍️ Detects Mac App Store apps (via [`mas`](https://github.com/mas-cli/mas)) and handles sign-in gracefully on restore
- 🗂️ Scans `~` and `~/.ssh` for dotfiles and lets you select which ones to include
- ✨ Interactive multi-select via `fzf` (falls back to a numbered checklist if `fzf` isn't installed)
- 💾 Optionally saves your dotfile selections to `~/.config/brew-export/config.yml` — skip the picker on repeat runs
- 🗜️ Packages everything into a single `<name>.tar.gz` tarball — Brewfile, install script, and dotfiles together
- 🔒 Security warnings when SSH keys or sensitive files are included
- 🎨 Colorized, emoji-annotated output throughout

---

## Requirements

- macOS
- [Homebrew](https://brew.sh)
- `brew bundle` (included with Homebrew)

**Optional but recommended:**

- [`mas`](https://github.com/mas-cli/mas) — required to capture Mac App Store apps; installed automatically if App Store apps are detected (`brew install mas`)
- [`fzf`](https://github.com/junegunn/fzf) — enables interactive dotfile selection (`brew install fzf`)

---

## Install

```bash
brew install zackwag/tap/brew-export
```

## Usage

```bash
# Run — defaults to your hostname as the output name
brew-export

# Or specify a custom name
brew-export my-macbook-setup
```

This produces a tarball in the current directory:

```bash
my-macbook-setup.tar.gz
```

---

## What's inside the tarball

```plaintext
my-macbook-setup/
├── my-macbook-setup.Brewfile       # brew bundle dump output
├── my-macbook-setup_install.sh     # self-contained restore script
├── config.yml                      # saved dotfile preferences (if saved)
└── dotfiles/                       # any dotfiles you selected
    ├── .zshrc
    ├── .gitconfig
    └── .ssh/
        └── config
```

---

## Restoring on a new machine

Transfer the tarball to the new Mac, then:

```bash
tar -xzf my-macbook-setup.tar.gz
cd my-macbook-setup
bash my-macbook-setup_install.sh
```

The install script will walk through these steps automatically:

| Step | What happens |
|------|-------------|
| **1. Homebrew** | Checks if Homebrew is installed; installs it if not (handles Apple Silicon path automatically) |
| **2. Custom taps** | Re-adds any custom taps captured at export time |
| **3. App Store** | Checks `mas` sign-in; if not signed in, installs everything else and exits cleanly with instructions |
| **4. Brew bundle** | Runs `brew bundle install` from the Brewfile |
| **5. Dotfiles** | Copies dotfiles to `~`; prompts per file if one already exists |

### Dotfile conflict resolution

When a dotfile already exists at the destination, you'll be prompted:

```bash
⚠️  Already exists: ~/.zshrc
What would you like to do?
[o] Overwrite   [s] Skip   [b] Backup and overwrite
>
```

Choosing **backup** saves the existing file as `.zshrc.bak.YYYYMMDDHHMMSS` before overwriting.

---

## Mac App Store apps

If your Brewfile contains App Store apps, `brew_export.sh` will automatically install [`mas`](https://github.com/mas-cli/mas) via Homebrew if it isn't already present — no manual setup required.

If the target machine isn't signed into the App Store when the install script runs, it will install all non-MAS packages first, then exit with clear instructions to sign in and re-run.

---

## Saved preferences

After selecting dotfiles, the script offers to save your choices to `~/.config/brew-export/config.yml`. On the next run, you'll see a summary and can accept or re-pick:

```
📋 Found saved preferences (~/.config/brew-export/config.yml)
   5 dotfiles selected (e.g. .zshrc, .gitconfig, .ssh/config, ...)
   Use saved preferences? [Y/n]
```

- Press **Enter** or **Y** to reuse your saved selections
- Press **n** to drop into the normal picker
- Dotfiles that no longer exist are detected and automatically pruned

To reset, delete the config file: `rm ~/.config/brew-export/config.yml`

---

## Security

> ⚠️ **If you include `~/.ssh` files, your tarball may contain private keys.**

- The script will warn you prominently when SSH files are selected
- Store and transfer the tarball securely — encrypted drive, private channel, etc.
- **Never commit a tarball containing SSH keys or secrets to a public repository**

---

## License

MIT
