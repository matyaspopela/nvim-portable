#!/usr/bin/env bash
# ============================================================================
#  One-time setup of everything this Neovim config uses. Run it in WSL:
#
#      bash ~/.config/nvim/install.sh
#
#  Asks for your sudo password once. Safe to run again: it skips what's there.
#
#   Ubuntu apt     gdb, cmake, ninja, ccache, mold, unzip, cppcheck, valgrind
#   apt.llvm.org   current LLVM (22): clangd, clang-format, clang-tidy, lldb-dap,
#                  clang, lld. Ubuntu 24.04's clangd 18 can't parse GCC 13's
#                  <expected>, and Mason has no ARM64 build of clangd.
#   GitHub         lazygit (ARM64) -> ~/.local/bin
#   uv tools       debugpy (Python debugger adapter, its own environment)
#   Neovim         plugins at the versions in lazy-lock.json, Treesitter
#                  parsers, Mason packages (language servers, stylua, shellcheck)
# ============================================================================
set -euo pipefail

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

step 'Ubuntu packages'
sudo apt-get update
sudo apt-get install -y build-essential gdb cmake ninja-build ccache mold unzip cppcheck valgrind \
  python3-venv curl wget gnupg lsb-release software-properties-common

step 'LLVM from apt.llvm.org'
llvm_sh="$(mktemp)"
curl -fsSL https://apt.llvm.org/llvm.sh -o "$llvm_sh"
LLVM_VERSION="${LLVM_VERSION:-$(sed -n 's/^CURRENT_LLVM_STABLE=//p' "$llvm_sh")}"
if [ -x "/usr/lib/llvm-$LLVM_VERSION/bin/clangd" ]; then
  echo "LLVM $LLVM_VERSION is already installed"
else
  sudo bash "$llvm_sh" "$LLVM_VERSION" # clang, clangd, lldb (lldb-dap), lld
fi
rm -f "$llvm_sh"
sudo apt-get install -y "clang-format-$LLVM_VERSION" "clang-tidy-$LLVM_VERSION"
echo "Neovim picks /usr/lib/llvm-$LLVM_VERSION/bin/clangd automatically (newest LLVM wins)."

step 'lazygit'
if have lazygit; then
  echo "already installed: $(lazygit --version | sed 's/.*version=\([^,]*\).*/\1/')"
else
  case "$(uname -m)" in aarch64) arch=arm64 ;; x86_64) arch=x86_64 ;; *) arch='' ;; esac
  if [ -n "$arch" ]; then
    ver="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')"
    tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_linux_${arch}.tar.gz" \
      | tar -xz -C "$tmp" lazygit
    mkdir -p ~/.local/bin && install -m 755 "$tmp/lazygit" ~/.local/bin/lazygit && rm -rf "$tmp"
    echo "installed lazygit $ver"
  fi
fi

step 'Python debugger (debugpy)'
if have uv; then
  uv tool install debugpy 2>/dev/null || uv tool upgrade debugpy
else
  echo 'uv not found: install it (curl -LsSf https://astral.sh/uv/install.sh | sh), then run this again'
fi

step 'Neovim plugins, parsers, language servers'
nvim --headless '+Lazy! restore' +qa
nvim --headless -c 'lua require("nvim-treesitter").install(vim.g.treesitter_parsers):wait(600000)' -c qa
nvim --headless -c 'MasonInstall lua-language-server neocmakelsp stylua bash-language-server shellcheck json-lsp yaml-language-server taplo' -c qa
if have cargo; then nvim --headless -c 'MasonInstall rust-analyzer' -c qa; fi

step 'Done'
echo 'Start Neovim inside a project folder:  cd ~/code/myproject && nvim'
echo 'Health check inside Neovim:            :checkhealth vim.lsp snacks'
