# Portable Neovim C++ IDE for Windows (Flexoki)

Neovim, the Flexoki colour scheme (dark + light) and a full C++ toolchain in **one
folder**. Nothing is installed and no admin rights are needed. Unzip it, run it,
and delete the folder when you are done. Everything Neovim writes (plugins,
undo history, sessions, caches) stays inside the folder.

For Windows 10 / 11 on **x64**: any normal Intel / AMD PC. (It also runs on ARM
Windows through emulation.)

## Get it running (school PC)

1. **Download** `nvim-portable.zip` from this repository's
   [Releases](../../releases/latest) page. Or download it from a terminal:

   ```bat
   curl.exe -L -o nvim-portable.zip https://github.com/matyaspopela/nvim-portable/releases/latest/download/nvim-portable.zip
   ```

2. **Unzip it into a folder you own**, for example `C:\Users\<you>\nvim-portable`.
   Use a path with no spaces, and not inside OneDrive or a network drive (those are slow).
   The fastest way to unzip is the `tar` that comes with Windows: it takes seconds,
   where Explorer takes minutes for the roughly 10,000 files:

   ```bat
   cd %USERPROFILE%
   tar -xf nvim-portable.zip
   ```

   If you unzip with Explorer instead, first right-click the zip, choose
   *Properties*, and tick *Unblock*. Otherwise Windows may ask
   "do you want to run this file?" for every program.

3. **Run `setup-terminal.cmd` once** (double-click it). It does three things, for your
   user only and without admin rights:
   * installs the Cascadia Code NF font, which has the icons the statusline and file tree use;
   * adds two Windows Terminal profiles, **Neovim (portable)** and **Dev shell (g++)**,
     both with the Flexoki colours. Your Terminal settings file is not changed;
   * copies the clangd defaults (clang-tidy checks, inlay hints) to `%LOCALAPPDATA%\clangd`,
     the only place clangd on Windows reads them from.

   Then restart Windows Terminal and pick **Neovim (portable)** from the ˅ menu
   next to the + tab button.

4. Without Windows Terminal: run `nvim.cmd` (double-click it, or `nvim.cmd file.cpp`
   from a command prompt). For a command prompt where `g++`, `make`, `cmake` and
   `gdb` work, use `shell.cmd`.

To remove everything: run `setup-terminal.cmd uninstall`, then delete the folder.

## What's inside

| Folder | What | Version |
|---|---|---|
| `nvim\` | Neovim, the official Windows build | 0.12.6 |
| `w64devkit\` | GCC / g++, gdb, make, CMake, Ninja, ctags, busybox shell tools | GCC 16.2 (w64devkit 2.11) |
| `clangd\` | clangd: completion, errors as you type, go to definition, clang-tidy | 23.1 |
| `codelldb\` | debugger used by F5 | 1.12.3 |
| `tools\` | clang-format, ripgrep, fd | 23.1, 15.2, 10.5 |
| `fonts\` | Cascadia Code NF (used by `setup-terminal.cmd`) | 2407.24 |
| `config\nvim\` | the Neovim config: same as the WSL one, with Windows branches | |
| `data\` | plugins (pinned in `lazy-lock.json`) and 42 prebuilt Treesitter parsers | |

The plugins are already in the folder, so Neovim works offline from the first start.

## Using it

The full guide to keys and workflow is in [config/nvim/README.md](config/nvim/README.md).
The basics:

* `Space`, then wait: every command is listed.
* **F7** build · **Ctrl+F5** run · **F5** debug · **F9** breakpoint · **F10 / F11** step.
  This works for a single `.cpp` file, a `CMakeLists.txt` project or a `Makefile`.
* `Space u b` switches between light and dark mode (remembered).
* `Space f f` finds a file · `Space f g` searches text · `Space e` opens the file tree.
* `Space m A` shows the assembly for the file; `Space m m` switches the single-file build between debug and release.
* Quit with `:Q`. In this config `:q` only closes a window.

### Differences from the WSL / Linux setup

* **Compiler:** MinGW g++ 16 (w64devkit) builds native `.exe` files.
  The single-file debug profile uses `-fsanitize=undefined -fsanitize-trap=all -D_GLIBCXX_ASSERTIONS`,
  because MinGW has no AddressSanitizer. A bad index or undefined behaviour stops the program
  under the debugger right where it happens. Release uses `-O2 -march=native`.
* **Debugger:** codelldb (F5). w64devkit's gdb has no Python, so it can't drive the
  debugger UI; it still works as plain `gdb` in the dev shell. The program's input and
  output appear in a terminal split, so `cin` works.
* **CMake:** builds use Ninja. `compile_commands.json` is copied, not linked, into the
  project root, because Windows links need admin rights or Developer Mode.
* **Not included:** Python tools, lazygit, Mason's extra language servers (`:Mason` can
  add them if the PC has internet). Git comes from the PC; the editor works without it.
* **Clipboard:** `y` copies to the Windows clipboard, and Ctrl+V or `Space p` pastes.

## If something doesn't work

* **"This app has been blocked by your system administrator"** means the PC blocks
  programs that run from your user folder (AppLocker). Only IT can change that.
* **Icons show as boxes:** the font isn't set. Run `setup-terminal.cmd`, then restart
  Windows Terminal, or set the font to *Cascadia Code NF* in the profile.
* **First file open is slow:** clangd indexes the standard library once, and the
  folder's first run compiles Lua caches. Both are fast after that.
* **Check the setup:** `:checkhealth` inside Neovim.

## How this folder was put together

Official release builds, unzipped unchanged: Neovim (neovim/neovim), w64devkit
(skeeto/w64devkit), clangd (clangd/clangd), codelldb (vadimcn/codelldb, the
`.vsix` unpacked: `adapter`, `lldb`), ripgrep, fd, clang-format (static build from
cpp-linter/clang-tools-static-binaries) and Cascadia Code (microsoft/cascadia-code).
The plugins were installed with `Lazy! restore` from `lazy-lock.json`, and the parsers
were built with the tree-sitter CLI and the bundled gcc. Each component keeps its own
licence; see the licence files in its folder.
