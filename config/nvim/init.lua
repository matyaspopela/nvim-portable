-- ============================================================================
--  Neovim as a C++ IDE  ·  portable Windows x64 edition
--  (the same config as the WSL one, with Windows branches where they differ:
--  g++ from w64devkit, codelldb for debugging, clangd / rg / fd bundled.
--  nvim.cmd in the portable folder sets PATH and keeps every file in there.)
--
--  Leader = <Space>. Press it and wait: every command is listed (which-key).
--  README.md in this folder explains the workflow and every key binding.
--
--  lua/config/wsl.lua        fast PATH, Windows clipboard, open files in Windows
--  lua/config/options.lua    editor settings
--  lua/config/keymaps.lua    general key bindings
--  lua/config/autocmds.lua   small automatic behaviours
--  lua/config/lazy.lua       plugin manager (lazy.nvim)
--  lua/config/lsp.lua        language servers (clangd, CMake, Lua, Python) + diagnostics
--  lua/ide/run.lua           F5 / Ctrl+F5 / F7: debug, run, build (CMake, make or one file)
--  lua/flexoki/              the Flexoki colour scheme, light + dark (<leader>ub)
--  lua/plugins/*.lua         plugins, one file per area
-- ============================================================================

vim.loader.enable() -- byte-compile and cache Lua modules: faster startup

vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'
vim.g.have_nerd_font = true -- Cascadia Code NF (fonts\ in the portable folder) is set in Windows Terminal
vim.g.is_win = vim.fn.has('win32') == 1
-- `python3` on Windows is usually the Microsoft Store stub; `python` is the real one
vim.g.python_exe = vim.g.is_win and 'python' or 'python3'
-- the portable folder (nvim.cmd sets it); nil when run some other way
vim.g.portable_root = vim.env.NVIM_PORTABLE and vim.fs.normalize(vim.env.NVIM_PORTABLE) or nil

require('config.wsl') -- first: everything after it looks up executables
require('config.options')
require('config.keymaps')
require('config.autocmds')
require('flexoki').setup() -- colour scheme (colors/flexoki.lua): before plugins, so they start with it
require('config.lazy')
require('config.lsp')
