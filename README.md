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
- 🗜️ Packages everything into a single `<name>.tar.gz` tarball — Brewfile, install script, and dotfiles together
- 🔒 Security warnings when SSH keys or sensitive files are included
- 🎨 Colorized, emoji-annotated output throughout

---

## Requirements

- macOS
- [Homebrew](https://brew.sh)
- `brew bundle` (included with Homebrew)

**Optional but recommended:**

- [`mas`](https://github.com/mas-cli/mas) — required to capture Mac App Store apps (`brew install mas`)
- [`fzf`](https://github.com/junegunn/fzf) — enables interactive dotfile selection (`brew install fzf`)

---

## Usage

```bash
# Clone the repo
git clone https://github.com/your-username/brew-export.git
cd brew-export

# Make executable
chmod +x brew_export.sh

# Run — defaults to your hostname as the output name
./brew_export.sh

# Or specify a custom name
./brew_export.sh my-macbook-setup
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

Install `mas` before running `brew_export.sh` to ensure App Store apps are captured:

```bash
brew install mas
```

If the target machine isn't signed into the App Store when the install script runs, it will install all non-MAS packages first, then exit with clear instructions to sign in and re-run.

---

## Security

> ⚠️ **If you include `~/.ssh` files, your tarball may contain private keys.**

- The script will warn you prominently when SSH files are selected
- Store and transfer the tarball securely — encrypted drive, private channel, etc.
- **Never commit a tarball containing SSH keys or secrets to a public repository**

---

## License

MIT
