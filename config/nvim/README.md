# Neovim C++ IDE

> **Portable Windows edition.** This copy runs from the portable folder on native Windows.
> The keys and workflow below are the same. The Windows differences (g++ from w64devkit,
> codelldb instead of gdb for F5, bundled tools, no install.sh) are in the README.md two
> folders up. Linux paths and install steps below only apply to the WSL / Linux setup.

Neovim 0.12 set up as a full IDE for C++ / systems programming and Python, tuned for this
machine: **Lenovo 83HL, Snapdragon X Plus (8 Oryon cores, ARM64), 32 GB RAM, WSL2 Ubuntu
24.04**. Colour scheme: **[Flexoki](https://stephango.com/flexoki)** by Steph Ango, dark and
light, built into this config (`colors/flexoki.lua`, `lua/flexoki/`).

Leader key = **Space**. Press it and wait: every command shows up (which-key).

### The look

**Flexoki**, ink on paper. Every colour is a value from the canonical palette
([github.com/kepano/flexoki](https://github.com/kepano/flexoki)), nothing blended or
approximated. Dark uses the 400 accents on `#100F0F`, light the 600 accents on paper
`#FFFCF0`, as stephango.com prescribes. Code colours follow kepano's own Flexoki ports
(the Sublime scheme and the reference screenshot):

| | |
|---|---|
| keywords, `if`, `return` | green |
| `#include`, `#define`, `import` | red |
| `class`, `struct`, `int`, `auto`, `def` | blue |
| type, class & function names, macros | orange |
| variables, members, parameters | blue |
| strings | cyan · escapes `\n` red |
| numbers | purple |
| `true`, `nullptr`, `None`, constants | yellow |
| `this`, `self` | magenta |
| library symbols (`std::vector`, `print`, `len`) | green |
| `const`, `static`, `async` (modifiers) | plain text |
| punctuation, operators, `std::` | muted |
| comments | faint |

clangd's semantic tokens refine this: a macro is orange wherever it's used, `std::` types
are green, and an argument passed by non-const reference / pointer is *italic* at the call
site, so you see which arguments a function may modify.

**Light / dark: `<Space>ub`** (or `:Flexoki toggle | dark | light`). Instant, remembered
across restarts. Neovim also sets Windows Terminal's background to match while it runs,
so the padding around the editor never shows a different colour, and resets it on exit.

The UI around the code stays soft and rounded, with no separator lines:

- **Statusline**: rounded "bubbles" floating on the editor background. Mode (`normal` green,
  `insert` yellow, `visual` orange, `replace` red, `command` blue), then the file; on the
  right what F7 builds, the language server and the cursor position.
- **Tab bar**: plain file names, the current one bright. No close buttons or separators,
  and hidden when only one file is open.
- **Popups** (hover docs, completion, pickers, code actions, notifications, which-key): one
  style everywhere, editor background with a soft rounded outline (Flexoki `ui-3`).
  Selections in warm grey.
- **Gutter**: no background strip; round outline icons for problems, thin `▎` git marks.
- **Indentation**: no rows of guide lines, just one faint line marking the block the cursor
  is in.
- **Start screen**: a greeting and the date instead of a banner.

All of it lives in `lua/flexoki/` (palette + every highlight group, including all plugins
here) and `lua/plugins/ui.lua` (statusline, tabs, which-key).
`extras/windows-terminal-flexoki.json` has matching Windows Terminal schemes + window themes.

---

## 1. One-time setup

```bash
bash ~/.config/nvim/install.sh
```

Asks for your sudo password once, then installs:

| What | Why |
|---|---|
| LLVM 22 from apt.llvm.org (clangd, clang-format, clang-tidy, lldb-dap) | Ubuntu's clangd 18 can't parse GCC 13's `<expected>` (you get false errors on C++23 code). Mason has no ARM64 clangd. Neovim picks the newest LLVM automatically. |
| ninja, ccache, mold | Faster CMake builds and rebuilds (used automatically for new build folders). |
| unzip, cppcheck, valgrind, gdb, cmake | Mason needs unzip; the rest are standard C++ tools. |
| lazygit (ARM64) | Already installed in `~/.local/bin`; the script skips it. |

Safe to run again. Everything else (plugins, parsers, Mason packages) is already installed.

---

## 2. Daily workflow

```bash
cd ~/code/myproject      # the folder with CMakeLists.txt (or Makefile)
nvim                     # start screen: recent files, projects, restore session
```

Start Neovim **in the project's root folder**. That folder decides how F5 / F7 / Ctrl+F5 work:

| Project has | F7 build | Ctrl+F5 run | F5 debug |
|---|---|---|---|
| (a `.py` file is open) | nothing to build | `uv run` (uv / pyproject project), else the `.venv`'s python, else python3 | debugpy: this file, or pick a configuration |
| `CMakeLists.txt` | `cmake --build` (configures first if needed) | runs the launch target in a terminal split | builds, then debugs the launch target |
| `Cargo.toml` | `cargo build`, errors to quickfix | `cargo run` | builds, then debugs the binary with gdb |
| `Makefile` | `make -j8` | asks once which program to run | asks once, then debugs it |
| neither | compiles the current `.cpp` / `.c` file | runs it in a terminal split | debugs it |

- **Python environments**: basedpyright, the debugger and the test runner all use the
  project's `.venv` (or `venv`, or an activated `$VIRTUAL_ENV`) automatically, with no config file
  needed. `uv venv` / `uv sync` in a new project and reopen the file.

- **Folder with a CMakeLists.txt that shouldn't build your file?** (e.g. CLion's
  `comp-programming`, which puts several solutions with their own `main()` into one program):
  press **`<Space>mM`** once in that folder. F7 / Ctrl+F5 / F5 then work on the current file
  there, and the choice is remembered. Press it again to switch back.
- The statusline shows what F7 acts on: `CMake · Debug · target`, `CMake · F7 to configure`
  (not configured yet: F7 does it, asking for the build type once), `make`, or
  `single file · debug`.
- Build errors and warnings land in the **quickfix list**: `]q` / `[q` walk through them,
  `<leader>xq` shows them in a panel.
- CMake projects: `compile_commands.json` is linked into the project root after every configure,
  so clangd knows every flag and include path. Build folders: `build/Debug`, `build/Release`, …
- Single files: binaries go to `~/.cache/nvim/ide`, never next to your code. Profile **debug**
  (`-O0 -g3`, AddressSanitizer + UBSan, `_GLIBCXX_ASSERTIONS`) or **release** (`-O2 -mcpu=native`),
  switch with `<leader>mm`. Program arguments / input file: `:Run < input.txt` (remembered),
  `:Run!` clears them.
- Sessions are saved per folder when you quit (`:Q`); `s` on the start screen restores them.

---

## 3. Keys

### Essentials
| Key | Action |
|---|---|
| `<Space><Space>` | find file (smart: recent + frecency) |
| `<Space>/` or `<Space>fg` | search text in project (ripgrep) |
| `<Space>e` | file explorer (a add, d delete, r rename, c copy, m move, H hidden, I ignored) |
| `Ctrl+s` / `<Space>w` | save |
| `:q` / `<Space>q` | close the window or file — **never quits Neovim** (see below) |
| `:Q` / `<Space>Q` | quit Neovim (asks about unsaved files; `:Q!` doesn't) |
| `Ctrl+/` | terminal at the bottom, in the project folder (toggle; see Terminal below) |
| `jk` | leave insert mode |
| `S` + 1–2 chars + label | jump anywhere on screen (flash) |
| `<Space>fk` | search all key bindings |

**Closing vs quitting.** `:q`, `:q!`, `:wq`, `:x`, `ZZ`, `ZQ`, `Ctrl+w q` and `<Space>q` only
close things: a split, the explorer, the terminal, help or a popup closes its window; in the
last code window they close the file (the next open file shows, or the start screen when none
is left). Unsaved changes are asked about as usual; `!` discards them, `:wq` / `:x` / `ZZ` save
first. Neovim itself quits only with **`:Q`** (capital), `<Space>Q`, `Q` on the start screen,
or `:qa`.

### Code (LSP: clangd)
| Key | Action |
|---|---|
| `gd` / `F12` | go to definition |
| `gr` / `Shift+F12` | references |
| `gD` / `gI` / `gy` | declaration / implementations / type definition |
| `K` | documentation popup (press again to enter it) |
| `gK`, insert `Ctrl+k` | signature help |
| `Alt+o` / `<Space>ch` | switch header ⇄ source |
| `Alt+Enter` / `<Space>ca` | quick fix / code action: applies "(fix available)" fixes, e.g. push_back → emplace_back |
| `<Space>cr` / `F2` | rename symbol (project-wide) |
| `<Space>cf` | format file / selection (clang-format) |
| `<Space>cn` | doc comment skeleton for the function / class under the cursor (Doxygen, Google docstrings, rustdoc) |
| `<Space>cs` | symbols outline panel |
| `<Space>cc` / `<Space>cC` | callers / callees |
| `<Space>ct` / `<Space>cT` | derived classes / base classes |
| `<Space>fs` / `<Space>fS` | symbols in file / project |
| `gl` | full error message under cursor |
| `]e` `[e` / `]w` `[w` / `]d` `[d` | next/previous error / warning / any diagnostic |
| `<Space>xx` / `<Space>xX` | Problems panel (project / this file) |
| `<Space>cR` | restart language servers |
| `<Space>ci` | LSP status (`:checkhealth vim.lsp`) |

Quick fixes, like CLion: when a warning ends in **"(fix available)"** (clang-tidy / clangd),
press **`Alt+Enter`** (or `<Space>ca`) anywhere on that line. A list of fixes opens; `Enter`
applies the selected one. Unused `#include`s (greyed out) are removed the same way.
(Your Windows Terminal also sends `Shift+Enter` as Alt+Enter, a binding you had set up
before, so `Shift+Enter` in normal mode opens the same list.)

**SQL in raw strings** is highlighted as SQL. Tag the string with its language,
`R"sql( SELECT … )sql"`, or just write a plain `R"( SELECT … FROM … )"`: statements starting
with select / insert into / update … set / delete from / with … as / create table … (any case,
leading `--` comments fine) are detected by shape, so a string like `R"(Update available)"`
stays plain text. Ordinary `"…"` strings are not touched. (Rules: `queries/cpp/injections.scm`
and the top of `lua/plugins/treesitter.lua`; other languages work the same way, e.g.
`R"json( … )json"`.)

Completion: menu appears while typing. `Tab` / `Shift+Tab` move, `Enter` accepts the item you
picked (otherwise it's a normal new line), `Ctrl+Space` opens it / toggles docs, `Ctrl+e` closes.

Formatting is **manual only**: `<Space>cf` formats the file or Visual selection.
Saving never formats. C/C++ formatting keeps function and lambda bodies multiline,
while inheriting the project style (or LLVM with tabs and 100 columns as a fallback).

### Build / run (`<Space>m`)
| Key | Action |
|---|---|
| `F7` / `<Space>mb` | build |
| `Ctrl+F5` / `<Space>mr` | run |
| `<Space>mf` | build & run the current file (ignores CMake) |
| `<Space>mg` | CMake: configure |
| `<Space>mt` | CMake: build type (Debug / Release / RelWithDebInfo / MinSizeRel) |
| `<Space>ms` / `<Space>ml` | CMake: build target / launch target |
| `<Space>ma` | CMake: arguments & env for the launch target |
| `<Space>mp` | CMake: configure preset (`CMakePresets.json`) |
| `<Space>mT` | run tests (ctest) |
| `<Space>mc` / `<Space>mx` / `<Space>mo` | clean / stop build / show build output |
| `<Space>mm` | single-file profile debug ⇄ release |
| `<Space>mM` | this folder: CMake / make ⇄ single file (remembered per folder) |
| `<Space>mA` / `:Asm [flags]` | **assembly** of this file, Compiler-Explorer style but local |
| `<Space>mv` / `:OptRemarks [flags]` | **optimisation remarks**: which loops were vectorised, which weren't and why |
| `<Space>mV` | clear the remarks |

**Seeing what the compiler did.** `<Space>mA` compiles the current file with its *real* flags
(from `compile_commands.json`; single files use the release profile) and shows the assembly in
a split: directives and debug noise removed, names demangled, function labels highlighted. The
instructions generated by the line under your cursor are highlighted, and `Enter` on an
instruction jumps back to its source line. Saving recompiles it. `:Asm -O3 -march=native` tries
other flags (remembered; `:Asm!` drops them). `<Space>mv` asks the compiler for its
optimisation remarks (clang `-Rpass`, gcc `-fopt-info`) and shows them as diagnostics on the
lines: vectorised loops as info, missed ones as warnings with the reason. If the build has no
`-O`, `-O2` is used for this. Nothing leaves the machine.

### Terminal
`Ctrl+/` opens a terminal split at the bottom, already in the project folder: type compile
commands, `git`, `ls`, … there. `Ctrl+/` again hides it (the shell keeps running, with its
history and output); `2 Ctrl+/` opens a second one.

| Key (inside the terminal) | Action |
|---|---|
| `Ctrl+k` (or `Ctrl+h/j/l`) | jump to the code window above, without closing the terminal |
| `Ctrl+j` (from the code) | jump back down into the terminal |
| `Esc` `Esc` | normal mode: scroll, search, copy output with `y`; `i` to type again |
| `q` (in normal mode) | hide the terminal |

You don't need the terminal to build: F7 / Ctrl+F5 / F5 compile, run and debug, and
`:Run < input.txt` runs the current program with input. `:q` in the terminal hides it (the
shell keeps running, `Ctrl+/` brings it back); `:Q` quits Neovim with a terminal open too.

### Debugger (`<Space>d`): gdb, with readable `std::vector` / `map` / `string`
| Key | Action |
|---|---|
| `F5` | start / continue |
| `Shift+F5` | stop |
| `F9` | toggle breakpoint |
| `F10` / `F11` / `Shift+F11` | step over / into / out |
| `<Space>dB` / `<Space>dl` | conditional breakpoint / log point |
| `<Space>dC` | run to cursor |
| `<Space>de` | evaluate expression (or selection) |
| `<Space>dw` | watch expression under cursor |
| `<Space>dk` / `<Space>dj` | up / down the call stack |
| `<Space>du` | toggle the debugger panels |
| `<Space>dr` | debugger console (gdb commands work there) |
| `<Space>dL` / `<Space>dx` | list / clear breakpoints |

| `<Space>ds` (visual, Python) | debug the selected Python code |

Panels open automatically: variables, watches, call stack, breakpoints (left); program output and
console (bottom). Variable values also appear next to the code. Python uses debugpy (installed
as its own uv tool, so nothing goes into your projects); Rust uses gdb like C++.

### Tests (`<Space>t`): pytest and CTest (GoogleTest, Catch2, doctest, …)
| Key | Action |
|---|---|
| `<Space>tt` / `<Space>tf` / `<Space>ta` | run nearest test / this file / whole project |
| `<Space>td` | **debug** the nearest test (breakpoints work) |
| `<Space>tl` / `<Space>tS` | run last again / stop |
| `<Space>ts` | test tree: run or jump to any test |
| `<Space>to` / `<Space>tO` | output of the test under the cursor / output panel |
| `<Space>tw` | watch: re-run this file's tests on every save |
| `]n` / `[n` | next / previous failed test |

✓ / ✗ appear in the sign column; failure messages show on the failing line. C++ tests come
from CTest, so configure and build the CMake project first (F7).

### Find (`<Space>f`)
`ff` files · `fg` text · `fw` word under cursor · `fb` buffers · `fr` recent · `fl` lines ·
`fd`/`fD` problems · `ft` TODOs · `fh` help · `fk` keys · `fu` undo history · `fq` quickfix ·
`fj` jumps · `fp` projects · `fc` Neovim config · `f.` resume last search · `fn` notifications ·
`fE` show folder in Windows Explorer

Inside a picker: type to filter, `Enter` open, `Ctrl+s` open in a split, `Tab` select several,
`Esc` close.

### Git (`<Space>g`)
`gg` lazygit · `gs` status · `gl`/`gL` log (project / file) · `gd` changed hunks · `gp` preview
change · `gS` stage change · `gr`/`gR` undo change / whole file · `gb` blame line · `gt` inline blame ·
`gD` diff file · `gB` open on GitHub · `]h` `[h` next / previous change ·
`gv` **diff view** (every changed file side by side; on a merge conflict a 3-way view where
`<Space>co` / `ct` / `cb` / `ca` take ours / theirs / base / all, `]x` `[x` jump) · `gh` history
of this file (in visual mode: of the selected lines) · `gH` branch history

### Buffers & windows
| Key | Action |
|---|---|
| `Shift+h` / `Shift+l` | previous / next buffer (tab bar) |
| `<Space>bd` / `<Space>bo` | close buffer / close all others |
| `<Space>bp` / `<Space>bj` | pin buffer / jump to buffer by letter |
| `Ctrl+h/j/k/l` | move between windows |
| `<Space>-` / `<Space>\|` | split below / right |
| `Alt+arrows` | resize window |

### Editing
| Key | Action |
|---|---|
| `gc{motion}` / `gcc` | comment |
| `saiw)` / `sd"` / `sr)]` | surround: add / delete / replace |
| `daf` `cif` `vac` `cia` `dio` | text objects: function, class, argument, if/loop body |
| `]f` `[f` / `]c` `[c` / `]a` `[a` | next / previous function / class / argument |
| `Ctrl+Space` (normal) | select syntax node, repeat to grow |
| `Alt+j` / `Alt+k` | move line(s) |
| `<Space>sr` / `<Space>sw` | search & replace in project (live preview) |
| `]t` `[t` | next / previous TODO |
| `]]` `[[` | next / previous use of the symbol |
| `<Space>y` / `<Space>p` | copy whole file to / paste from Windows clipboard |
| `Ctrl+q` | block selection (Windows Terminal uses Ctrl+v for paste) |

Plain `y` also copies to the Windows clipboard. Paste text from Windows with `Ctrl+v`.

### Toggles (`<Space>u`)
`ub` **light / dark** · `uh` inlay hints · `ud` diagnostics · `uf` format on save · `ui` scope line · `uc` sticky
header · `uw` wrap · `us` spelling · `ur` relative numbers · `ul` line numbers · `uz` zen mode ·
`un` dismiss notifications · `uT` treesitter

### Sessions (`<Space>S`)
`Ss` restore this folder's session · `Sl` last session · `Sf` pick one · `Sd` don't save this one

---

## 4. How to run it: terminal setup (applied)

**Keep Windows Terminal, but skip PowerShell.** You used to open PowerShell, type `wsl`, then
type `nvim`. PowerShell loads its profile first (~0.5–1 s) and then just hosts `wsl.exe`, so it's
an extra layer that does nothing for you. Windows Terminal now starts Ubuntu directly:

- **New window or tab** → bash in **`C:\Users\matya`** (`/mnt/c/Users/matya`, where
  CLionProjects is). Ubuntu is the default profile. Your Linux home is one `cd` away.
- **Explorer → right-click a folder → Open in Terminal** → bash *in that folder* (e.g.
  `/mnt/c/Users/matya/CLionProjects/...`), then type `nvim`.
- **Neovim** profile (tab dropdown `˅`, or `Ctrl+Shift+Space` → Neovim) → straight into Neovim;
  quitting it leaves you in bash.
- PowerShell and cmd are still in the dropdown.

Fastest ways to get a terminal: pin Windows Terminal as the first taskbar icon (`Win+1`), or
press ``Win+` `` anywhere for the drop-down terminal (Windows Terminal's quake mode).

Why Windows Terminal and not WezTerm / Alacritty / Kitty: on a Snapdragon (Windows on ARM),
Windows Terminal is the only one with a **native ARM64 build** and a GPU renderer (Atlas engine on
your Adreno). The others either don't exist on Windows or run under x64 emulation: slower to
start, more battery. Windows Terminal already supports everything this config uses: true colour,
curly underlines, OSC 52 clipboard, Nerd Font glyphs (Cascadia Code NF is installed).

What was changed in Windows Terminal's `settings.json` on 2026-10-25. It lives in
`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState`, next to the
backups: `settings.json.bak-2026-10-25` (original), then one per step: `…-catppuccin`,
`…-kanagawa`, `…-linuxhome`, `…-altenter`.

1. **Default profile → Ubuntu** (`"defaultProfile": "{b8026bb6-6374-5614-ad7a-11fa571eae5c}"`).
2. The Ubuntu profile starts in your Windows user folder: `"startingDirectory": "%USERPROFILE%"`
   (`C:\Users\matya` → `/mnt/c/Users/matya`). Explorer's "Open in Terminal" overrides it with
   the folder you clicked. For the Linux home instead, set it to
   `"//wsl.localhost/Ubuntu/home/matya"`. (Don't use `--cd` in the command line: it would
   block Explorer's folder.)
3. A **Neovim profile** that opens straight into Neovim, in the same folder, and drops to bash
   when you quit:
   ```json
   { "name": "Neovim", "commandline": "wsl.exe -d Ubuntu -- bash -lic \"nvim; exec bash\"",
     "startingDirectory": "%USERPROFILE%" }
   ```
4. **Since 2026-11-09: Flexoki Dark** colour scheme and window theme for every profile, from
   `extras/windows-terminal-flexoki.json` (same ANSI colours as Neovim's `:terminal`). Flexoki
   Light is in the file too: Settings → Profiles → Defaults → Appearance → Colour scheme, and
   Settings → Appearance → Theme. Backup: `settings.json.bak-2026-11-09-pre-flexoki`.
   Before that: **KanagawaDragon** colour scheme for every profile, copied unchanged from kanagawa's
   [`extras/windows-terminal/kanagawa.json`](https://github.com/rebelot/kanagawa.nvim/tree/master/extras/windows-terminal)
   (background `#181616`). Kanagawa ships no window theme for Windows Terminal, so the
   "Kanagawa Dragon" window theme is built from dragon's palette: tab `#181616` (editor
   background), tab row `#0D0C0C`, unfocused `#12120F`. The Catppuccin Mocha scheme is still
   in the file if you ever want to switch back (Settings → Profiles → Defaults → Appearance).
5. **F11 and Alt+Enter freed** for Neovim ("step into", quick fixes):
   `{ "keys": "f11", "id": null }` and `{ "keys": "alt+enter", "id": null }` in `"keybindings"`.
   **Fullscreen is now `Alt+Shift+Enter`.**

The first terminal after booting Windows takes ~1–2 s while the WSL VM starts. After that new
tabs open instantly.

---

## 5. WSL tips that matter for C++

- **Keep bigger projects on the Linux disk** (`~/code/...`), not under `/mnt/c/...`. Every file
  access to `/mnt/c` goes through the 9P bridge. Measured on your CLionProjects: listing 6,200
  files takes 349 ms there vs 26 ms on the Linux disk, so the file finder, search, git signs,
  clangd indexing and builds are all slower. Small single-file folders (competitive
  programming) are fine where they are. CLion can open Linux-side projects via
  `\\wsl.localhost\Ubuntu\home\matya\code` and build them with its WSL toolchain.
- Working in `C:\Users\matya\CLionProjects` from WSL: it's `/mnt/c/Users/matya/CLionProjects`.
  Shortcut: `ln -s /mnt/c/Users/matya/CLionProjects ~/clion`, then `cd ~/clion/<project> && nvim`.
  Files you change in CLion meanwhile are reloaded when you switch back to Neovim.
- Optional `C:\Users\matya\.wslconfig` (then `wsl --shutdown` once):
  ```ini
  [experimental]
  autoMemoryReclaim=gradual   # hand memory the Linux page cache no longer needs back to Windows
  sparseVhd=true              # the Linux disk image shrinks again when you delete files
  ```
- `~/.bashrc` PATH (fixed 2026-10-25): line 118 used to be a **Windows Git-Bash PATH**
  (`/c/Users/...`, `/mingw64/bin`, …) pasted in by mistake, which broke `explorer.exe`, `clip.exe`
  and `code` in the terminal. It now lists the Linux folders, Go in `~`, and four Windows folders
  (System32, Windows, PowerShell, VS Code): 16 entries, an unknown command is reported in ~7 ms.
  The old file: `~/.bashrc.bak-2026-10-25-before-path-fix`.

---

## 6. What's tuned for this machine

- **PATH inside Neovim**: WSL appends ~30 Windows folders. Every lookup of a program that isn't
  installed (plugins do this a lot) then crawls them over 9P: **84 ms per lookup measured here,
  0.4 ms** with Linux folders only. Neovim keeps the Linux folders and reaches `explorer.exe`,
  `clip.exe` and `powershell.exe` through symlinks in `~/.local/share/nvim/wsl-bin`.
- **Treesitter + C++**: compiling the C++ highlight queries takes ~0.2 s on this CPU, once per
  session. When Neovim starts in a C/C++ project (or any folder with C/C++ files), that happens
  the first time you're idle (start screen), so the first file opens in ~25 ms instead of ~230 ms.
  (`nvim file.cpp` still pays it once at startup: the file has to be coloured before it's shown.)
- **gdb 15 fixes**: Ubuntu's gdb starts the program before Neovim has sent the breakpoints, so a
  breakpoint early in `main` could be missed, and it replaces the program's whole environment when
  one variable is set. Both are handled in `lua/plugins/debug.lua` (verified: breakpoints are hit
  every time, including on the first line of `main`).
- **clangd**: `-j=6` (8 cores, 2 left for Neovim and the compiler), background indexing at low
  priority, preambles in RAM (`--pch-storage=memory`), quiet log. Your old setup had filled
  `lsp.log` with 260 MB of clangd chatter: one disk write per request. It's emptied now.
- **Builds**: Ninja + ccache for new CMake build folders, `CMAKE_BUILD_PARALLEL_LEVEL=8`,
  `make -j8`, `-mcpu=native` for single-file release builds (GCC detects the Oryon features).
- **Startup**: ~30 ms to the start screen when plugged in, ~50 ms on battery (Windows clocks
  the Snapdragon down). Plugins load on first use.
- **Clipboard**: copying is an OSC 52 escape sequence handled by Windows Terminal (instant, no
  process, UTF-8 safe). Pasting from Windows: `Ctrl+v` (instant).
- **ARM64 everywhere**: clangd from apt.llvm.org, Mason packages with native aarch64 builds
  (lua-language-server, neocmakelsp), blink.cmp's prebuilt aarch64 matcher, lazygit arm64.

---

## 7. Files

```
init.lua                  entry point
install.sh                one-time toolchain setup
lua/config/wsl.lua        PATH, clipboard, open-in-Windows
lua/config/options.lua    editor settings (tabs 4 wide, folding, search, …)
lua/config/keymaps.lua    general keys + F5 / F7 / Ctrl+F5
lua/config/autocmds.lua   small automatic behaviours
lua/config/lazy.lua       plugin manager
lua/config/lsp.lua        language servers, diagnostics, LSP keys
lua/ide/run.lua           build / run / debug logic (Python, CMake, Cargo, make, single file)
lua/ide/asm.lua           assembly view + optimisation remarks
colors/flexoki.lua        :colorscheme flexoki
lua/flexoki/
  palette.lua             the canonical Flexoki palette (base + 8 accents, 50–950) and roles
  init.lua                every highlight group, terminal colours, lualine theme, light/dark
lua/plugins/
  ui.lua                  statusline bubbles, tab bar, which-key, LSP progress, icons
  snacks.lua              finder, explorer, terminal, lazygit, start screen, notifications
  editor.lua              flash, search & replace, Problems panel, sessions, git, diffview, TODOs, pairs
  coding.lua              completion + snippets, formatting, doc comments, Lua API for config editing
  lsp.lua                 lspconfig, Mason, SchemaStore
  treesitter.lua          syntax trees, text objects, sticky header, SQL-in-string check
  cmake.lua               cmake-tools
  debug.lua               debugger (nvim-dap, dap-ui, gdb, lldb, debugpy)
  test.lua                neotest: pytest, CTest
extras/windows-terminal-flexoki.json   matching Windows Terminal schemes + themes
lazy-lock.json            exact plugin versions
~/.config/clangd/config.yaml   clangd defaults: clang-tidy checks, inlay hints, unused includes
```

Maintenance: `:Lazy update` (plugins), `:Mason` (language servers), `:TSUpdate` (parsers),
`:checkhealth` (everything).

Language servers also set up: CMake (neocmakelsp), Lua, Python (basedpyright + ruff), Rust
(rust-analyzer with clippy), Markdown (marksman), Bash (bashls + shellcheck), JSON / YAML
(with the SchemaStore catalogue: `package.json`, `pyproject.toml`, `.clang-format`, GitHub
workflows, … are validated and completed), TOML (taplo). clangd runs with `--query-driver`, so it
uses the headers and target of the compiler your build actually calls (including cross
compilers under `/opt`).

## 9. 2026-11-09: Flexoki + more IDE

- Kanagawa → **Flexoki** (dark + light, `<Space>ub`), written from the canonical palette with
  every plugin themed. The old config is in `~/.config/nvim.bak-2026-11-09-pre-flexoki`.
- C++ / systems: assembly view and optimisation remarks (`<Space>mA`, `<Space>mv`),
  `--query-driver` for clangd, Rust / Cargo support (LSP, build, run, debug, format).
- Python: automatic `.venv` detection, run with `uv`, debugpy debugging, pytest.
- IDE: tests (neotest), diffview (merge conflicts, history), snippets (friendly-snippets),
  doc comments (`<Space>cn`), JSON / YAML / TOML / Bash language servers.

## 8. What changed from the old config

Removed: the competitive-programming tooling (templates, Competitive Companion, sample tests,
stress tests), custom snippets, the asm/hex view, the markdown editing module, the Python REPL,
the nyoom look (custom statusline, mode colours, banner, cheatsheet), and the other colour schemes
with their highlight overrides. The previous setup is untouched in `~/.config/nvim.bak-2026-10-25`
(clangd config in `~/.config/clangd.bak-2026-10-25`).
