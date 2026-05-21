#!/usr/bin/env bash
# brew_export.sh — exports your Homebrew setup + dotfiles into a portable tarball

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Determine output base name ────────────────────────────────────────────────
DEFAULT_NAME="$(hostname -s)"
BASE_NAME="${1:-$DEFAULT_NAME}"

BREWFILE="${BASE_NAME}.Brewfile"
INSTALL_SCRIPT="${BASE_NAME}_install.sh"
TARBALL="${BASE_NAME}.tar.gz"
WORK_DIR="$(mktemp -d)"
DOTFILES_DIR="${WORK_DIR}/${BASE_NAME}/dotfiles"

cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║       🍺  Brew Exporter  🍺           ║${RESET}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}📂 Output tarball:${RESET} ${YELLOW}${TARBALL}${RESET}"
echo ""

# ── Generate the Brewfile ─────────────────────────────────────────────────────
echo -e "${CYAN}📦 Dumping Brewfile...${RESET}"
brew bundle dump --file="${WORK_DIR}/${BASE_NAME}/${BREWFILE}" --force
echo -e "${GREEN}✅ Brewfile written.${RESET}"
echo ""

# ── Collect custom taps ───────────────────────────────────────────────────────
CUSTOM_TAPS=$(brew tap | grep -v '^homebrew/core$' | grep -v '^homebrew/cask$' || true)

if [[ -n "$CUSTOM_TAPS" ]]; then
  echo -e "${CYAN}🔍 Custom taps found:${RESET}"
  while IFS= read -r tap; do
    echo -e "   ${YELLOW}→${RESET} ${tap}"
  done <<< "$CUSTOM_TAPS"
  echo ""
else
  echo -e "${YELLOW}⚠️  No custom taps found.${RESET}"
  echo ""
fi

# ── Detect MAS apps ───────────────────────────────────────────────────────────
MAS_COUNT=0
if command -v mas &>/dev/null; then
  MAS_COUNT=$(grep -c '^mas ' "${WORK_DIR}/${BASE_NAME}/${BREWFILE}" 2>/dev/null || true)
fi

if [[ "$MAS_COUNT" -gt 0 ]]; then
  echo -e "${CYAN}🛍️  Mac App Store apps detected:${RESET} ${MAS_COUNT} app(s)"
  grep '^mas ' "${WORK_DIR}/${BASE_NAME}/${BREWFILE}" | while IFS= read -r line; do
    app_name=$(echo "$line" | sed 's/^mas "\(.*\)", id:.*/\1/')
    echo -e "   ${YELLOW}→${RESET} ${app_name}"
  done
  echo ""
elif ! command -v mas &>/dev/null; then
  echo -e "${YELLOW}⚠️  mas not installed — App Store apps will not be captured.${RESET}"
  echo -e "   ${CYAN}Tip: brew install mas${RESET} then re-run this script."
  echo ""
fi

# ── Dotfile selection ─────────────────────────────────────────────────────────
echo -e "${CYAN}🔍 Scanning for dotfiles...${RESET}"
echo ""

# Collect candidates from ~ (top-level dotfiles, non-directory)
CANDIDATES=()
while IFS= read -r f; do
  CANDIDATES+=("$f")
done < <(find "$HOME" -maxdepth 1 -name '.*' ! -type d | sort)

# ~/.ssh — with warning
if [[ -d "$HOME/.ssh" ]]; then
  echo -e "${YELLOW}🔑 ~/.ssh found.${RESET}"
  echo -e "${RED}   ⚠️  WARNING: ~/.ssh may contain private keys.${RESET}"
  echo -e "${RED}   Keep the generated tarball in a secure location if you include these.${RESET}"
  echo ""
  while IFS= read -r f; do
    CANDIDATES+=("$f")
  done < <(find "$HOME/.ssh" -maxdepth 1 -type f | sort)
fi

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}⚠️  No dotfiles found.${RESET}"
  SELECTED_FILES=()
else
  # ── fzf path ────────────────────────────────────────────────────────────────
  if command -v fzf &>/dev/null; then
    echo -e "${CYAN}📝 Select dotfiles to include${RESET} ${YELLOW}(TAB to multi-select, ENTER to confirm):${RESET}"
    echo ""
    SELECTED_RAW=$(printf '%s\n' "${CANDIDATES[@]}" | \
      fzf --multi \
          --prompt="  dotfiles > " \
          --header="TAB = select/deselect  |  ENTER = confirm  |  ESC = skip all" \
          --color="header:cyan,prompt:yellow,pointer:green" \
          --preview='echo {}' \
          --preview-window=hidden \
          || true)
    mapfile -t SELECTED_FILES <<< "$SELECTED_RAW"
    # Filter out empty lines (ESC / no selection)
    SELECTED_FILES=("${SELECTED_FILES[@]:-}")
    SELECTED_FILES=($(printf '%s\n' "${SELECTED_FILES[@]}" | grep -v '^$' || true))

  # ── Numbered checklist fallback ──────────────────────────────────────────────
  else
    echo -e "${YELLOW}⚠️  fzf not found — using numbered checklist.${RESET}"
    echo -e "${CYAN}   Install fzf for a better experience: brew install fzf${RESET}"
    echo ""
    echo -e "${CYAN}📝 Available dotfiles:${RESET}"
    for i in "${!CANDIDATES[@]}"; do
      printf "   ${YELLOW}%3d)${RESET} %s\n" "$((i+1))" "${CANDIDATES[$i]}"
    done
    echo ""
    echo -e "${CYAN}Enter numbers to include (e.g. 1 3 5), or ENTER to skip:${RESET}"
    read -r -p "  > " SELECTION

    SELECTED_FILES=()
    if [[ -n "$SELECTION" ]]; then
      for num in $SELECTION; do
        idx=$((num - 1))
        if [[ $idx -ge 0 && $idx -lt ${#CANDIDATES[@]} ]]; then
          SELECTED_FILES+=("${CANDIDATES[$idx]}")
        else
          echo -e "${RED}  ⚠️  Invalid selection: ${num} — skipped.${RESET}"
        fi
      done
    fi
  fi
fi

# ── Copy selected dotfiles into work dir ──────────────────────────────────────
mkdir -p "${DOTFILES_DIR}"
COPIED_DOTFILES=()

if [[ ${#SELECTED_FILES[@]} -gt 0 ]]; then
  echo ""
  echo -e "${CYAN}📋 Copying selected dotfiles:${RESET}"
  for f in "${SELECTED_FILES[@]}"; do
    [[ -z "$f" ]] && continue
    # Preserve relative path from HOME (e.g. .ssh/id_rsa → dotfiles/.ssh/id_rsa)
    REL="${f#$HOME/}"
    DEST="${DOTFILES_DIR}/${REL}"
    mkdir -p "$(dirname "$DEST")"
    cp "$f" "$DEST"
    COPIED_DOTFILES+=("$REL")
    echo -e "   ${GREEN}✅${RESET} ${REL}"
  done
  echo ""
else
  echo -e "${YELLOW}   No dotfiles selected — skipping.${RESET}"
  echo ""
fi

# ── Build the install script ──────────────────────────────────────────────────
echo -e "${CYAN}🔨 Generating install script...${RESET}"

INSTALL_SCRIPT_PATH="${WORK_DIR}/${BASE_NAME}/${INSTALL_SCRIPT}"

cat > "${INSTALL_SCRIPT_PATH}" << 'SCRIPT_HEADER'
#!/usr/bin/env bash
# Generated by brew_export.sh
# Restores your Homebrew environment and dotfiles.

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_HEADER

cat >> "${INSTALL_SCRIPT_PATH}" << INJECT_VARS
BREWFILE="\${SCRIPT_DIR}/${BREWFILE}"
HAS_MAS_APPS="${MAS_COUNT}"
INJECT_VARS

# Inject dotfiles list
echo 'DOTFILES=(' >> "${INSTALL_SCRIPT_PATH}"
for rel in "${COPIED_DOTFILES[@]:-}"; do
  [[ -z "$rel" ]] && continue
  echo "  \"${rel}\"" >> "${INSTALL_SCRIPT_PATH}"
done
echo ')' >> "${INSTALL_SCRIPT_PATH}"

cat >> "${INSTALL_SCRIPT_PATH}" << 'SCRIPT_BODY'

echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║     🍺  Brew Environment Restore  🍺  ║${RESET}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${RESET}"
echo ""

# ── Step 1: Install Homebrew if missing ───────────────────────────────────────
echo -e "${CYAN}🔎 Step 1: Checking for Homebrew...${RESET}"

if ! command -v brew &>/dev/null; then
  echo -e "${YELLOW}🍺 Homebrew not found. Installing...${RESET}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  echo -e "${GREEN}✅ Homebrew installed successfully.${RESET}"
else
  echo -e "${GREEN}✅ Homebrew already installed:${RESET} $(brew --version | head -1)"
fi

# ── Step 2: Add custom taps ───────────────────────────────────────────────────
echo ""
echo -e "${CYAN}🔧 Step 2: Adding custom taps...${RESET}"
SCRIPT_BODY

# Inject tap commands
if [[ -z "$CUSTOM_TAPS" ]]; then
  echo 'echo -e "${YELLOW}   No custom taps to add.${RESET}"' >> "${INSTALL_SCRIPT_PATH}"
else
  while IFS= read -r tap; do
    echo "echo -e \"\${YELLOW}  → Tapping ${tap}...\${RESET}\"" >> "${INSTALL_SCRIPT_PATH}"
    echo "brew tap \"${tap}\" 2>/dev/null && echo -e \"\${GREEN}  ✅ Tapped ${tap}\${RESET}\" || echo -e \"\${RED}  ⚠️  Could not tap ${tap} (may already exist)\${RESET}\"" >> "${INSTALL_SCRIPT_PATH}"
  done <<< "$CUSTOM_TAPS"
fi

cat >> "${INSTALL_SCRIPT_PATH}" << 'SCRIPT_MAS'

# ── Step 3: Mac App Store sign-in check ───────────────────────────────────────
echo ""
echo -e "${CYAN}🛍️  Step 3: Mac App Store apps...${RESET}"

if [[ "$HAS_MAS_APPS" -gt 0 ]]; then
  if ! command -v mas &>/dev/null; then
    echo -e "${YELLOW}  → mas not found. Installing via Homebrew...${RESET}"
    brew install mas
    echo -e "${GREEN}  ✅ mas installed.${RESET}"
  else
    echo -e "${GREEN}  ✅ mas already installed: $(mas version)${RESET}"
  fi

  MAS_ACCOUNT=$(mas account 2>/dev/null || true)
  if [[ -z "$MAS_ACCOUNT" ]]; then
    echo ""
    echo -e "${RED}  ❌ Not signed into the Mac App Store.${RESET}"
    echo -e "${YELLOW}  ⚠️  Please sign in:${RESET}"
    echo -e "     ${CYAN}1. Open the App Store app${RESET}"
    echo -e "     ${CYAN}2. Sign in with your Apple ID${RESET}"
    echo -e "     ${CYAN}3. Re-run this script${RESET}"
    echo ""
    echo -e "${YELLOW}  Skipping ${HAS_MAS_APPS} App Store app(s) for now.${RESET}"
    BREWFILE_NO_MAS=$(mktemp)
    grep -v '^mas ' "${BREWFILE}" > "${BREWFILE_NO_MAS}"
    echo -e "${CYAN}📦 Step 4: Installing non-MAS packages from Brewfile...${RESET}"
    brew bundle install --file="${BREWFILE_NO_MAS}"
    rm -f "${BREWFILE_NO_MAS}"
    echo ""
    echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${YELLOW}║  ⚠️  Partial restore — sign into App Store and  ║${RESET}"
    echo -e "${BOLD}${YELLOW}║      re-run to install remaining MAS apps.       ║${RESET}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════╝${RESET}"
    echo ""
    exit 0
  else
    echo -e "${GREEN}  ✅ Signed into App Store as:${RESET} ${MAS_ACCOUNT}"
  fi
else
  echo -e "${YELLOW}  No App Store apps in Brewfile — skipping.${RESET}"
fi

# ── Step 4: Install from Brewfile ─────────────────────────────────────────────
echo ""
echo -e "${CYAN}📦 Step 4: Installing from Brewfile...${RESET}"
echo -e "   ${YELLOW}→${RESET} ${BREWFILE}"
echo ""

if [[ ! -f "${BREWFILE}" ]]; then
  echo -e "${RED}❌ Brewfile not found at: ${BREWFILE}${RESET}"
  echo -e "${YELLOW}   Make sure you extracted the tarball and are running from inside it.${RESET}"
  exit 1
fi

brew bundle install --file="${BREWFILE}"

# ── Step 5: Restore dotfiles ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}🗂️  Step 5: Restoring dotfiles...${RESET}"

if [[ ${#DOTFILES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}   No dotfiles in this archive — skipping.${RESET}"
else
  DOTFILES_SRC="${SCRIPT_DIR}/dotfiles"
  SKIPPED=()
  RESTORED=()

  for rel in "${DOTFILES[@]}"; do
    SRC="${DOTFILES_SRC}/${rel}"
    DEST="${HOME}/${rel}"

    if [[ ! -f "$SRC" ]]; then
      echo -e "${RED}   ⚠️  Missing in archive: ${rel}${RESET}"
      continue
    fi

    if [[ -f "$DEST" ]]; then
      echo ""
      echo -e "${YELLOW}   ⚠️  Already exists: ${DEST}${RESET}"
      echo -e "   What would you like to do?"
      echo -e "   ${CYAN}[o]${RESET} Overwrite   ${CYAN}[s]${RESET} Skip   ${CYAN}[b]${RESET} Backup and overwrite"
      read -r -p "   > " CHOICE </dev/tty

      case "${CHOICE,,}" in
        o)
          cp "$SRC" "$DEST"
          RESTORED+=("$rel")
          echo -e "${GREEN}   ✅ Overwritten: ${rel}${RESET}"
          ;;
        b)
          BACKUP="${DEST}.bak.$(date +%Y%m%d%H%M%S)"
          cp "$DEST" "$BACKUP"
          cp "$SRC" "$DEST"
          RESTORED+=("$rel")
          echo -e "${GREEN}   ✅ Backed up to $(basename "$BACKUP") and overwritten: ${rel}${RESET}"
          ;;
        *)
          SKIPPED+=("$rel")
          echo -e "${YELLOW}   ⏭️  Skipped: ${rel}${RESET}"
          ;;
      esac
    else
      mkdir -p "$(dirname "$DEST")"
      cp "$SRC" "$DEST"
      RESTORED+=("$rel")
      echo -e "${GREEN}   ✅ Restored: ${rel}${RESET}"
    fi
  done

  echo ""
  echo -e "${CYAN}   Dotfile summary:${RESET}"
  echo -e "   ${GREEN}Restored: ${#RESTORED[@]}${RESET}  ${YELLOW}Skipped: ${#SKIPPED[@]}${RESET}"
fi

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║  🎉  Environment restored! Cheers.   ║${RESET}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${RESET}"
echo ""
SCRIPT_MAS

chmod +x "${INSTALL_SCRIPT_PATH}"

# ── Package into tarball ──────────────────────────────────────────────────────
echo -e "${GREEN}✅ Install script written.${RESET}"
echo ""
echo -e "${CYAN}🗜️  Creating tarball...${RESET}"

tar -czf "${TARBALL}" -C "${WORK_DIR}" "${BASE_NAME}"

echo -e "${GREEN}✅ Tarball created: ${TARBALL}${RESET}"
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║        ✅  Export complete!           ║${RESET}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}Transfer ${YELLOW}${TARBALL}${CYAN} to your new machine, then:${RESET}"
echo -e "   ${YELLOW}tar -xzf ${TARBALL}${RESET}"
echo -e "   ${YELLOW}cd ${BASE_NAME}${RESET}"
echo -e "   ${YELLOW}bash ${INSTALL_SCRIPT}${RESET}"

if [[ "$MAS_COUNT" -gt 0 || $(find "${DOTFILES_DIR}" -name 'id_*' 2>/dev/null | wc -l) -gt 0 ]]; then
  echo ""
  echo -e "${RED}🔒 Security reminder: This tarball may contain sensitive data.${RESET}"
  echo -e "${YELLOW}   Store and transfer it securely (encrypted drive, private channel, etc).${RESET}"
fi
echo ""
