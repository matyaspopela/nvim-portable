-- ============================================================================
--  WSL integration. Loaded before everything else.
--
--  1. PATH    WSL appends ~30 Windows folders to $PATH. Every lookup of a
--             program that isn't installed (plugins do this often) then crawls
--             all of them over the slow 9P file bridge: measured 84 ms per
--             lookup on this laptop vs 0.4 ms with Linux folders only. Neovim
--             keeps the Linux folders and reaches the few Windows programs it
--             needs through symlinks in one folder on the Linux disk.
--  2. Copy    every y also lands in the Windows clipboard (OSC 52: the terminal
--             does it, no process is started, UTF-8 safe).
--     Paste   from Windows: Ctrl+V (instant, done by Windows Terminal), or
--             "+p / <leader>p (asks PowerShell, ~0.3 s).
--  3. Open    gx / :Open open URLs and Linux files in their Windows app.
-- ============================================================================
local M = {}

local uv = vim.uv
local WIN = '/mnt/c/Windows'
local POWERSHELL = WIN .. '/System32/WindowsPowerShell/v1.0/powershell.exe'
local is_wsl = vim.fn.has('wsl') == 1

--- Show a folder in the system file manager (Windows Explorer under WSL).
function M.reveal(dir)
  dir = dir or uv.cwd()
  if is_wsl then
    vim.system({ WIN .. '/explorer.exe', '.' }, { cwd = dir }) -- explorer.exe always exits with 1: ignore it
  else
    vim.ui.open(dir)
  end
end

-- Native Windows: Neovim talks to the clipboard itself (win32yank.exe ships
-- with it). Plain y is mirrored to the Windows clipboard, as under WSL.
if vim.fn.has('win32') == 1 then
  vim.api.nvim_create_autocmd('TextYankPost', {
    group = vim.api.nvim_create_augroup('win_clipboard', { clear = true }),
    callback = function()
      local ev = vim.v.event
      if ev.operator == 'y' and ev.regname == '' then pcall(vim.fn.setreg, '+', ev.regcontents, ev.regtype) end
    end,
  })
end

if not is_wsl then return M end

-- 1. PATH --------------------------------------------------------------------
local shims = vim.fn.stdpath('data') .. '/wsl-bin'
if not uv.fs_stat(shims) then
  vim.fn.mkdir(shims, 'p')
  for name, target in pairs({
    ['explorer.exe'] = WIN .. '/explorer.exe',
    ['clip.exe'] = WIN .. '/System32/clip.exe',
    ['cmd.exe'] = WIN .. '/System32/cmd.exe',
    ['wsl.exe'] = WIN .. '/System32/wsl.exe',
    ['powershell.exe'] = POWERSHELL,
  }) do
    uv.fs_symlink(target, shims .. '/' .. name)
  end
end

local dirs, seen = {}, {}
local function add(dir)
  if not seen[dir] then
    seen[dir] = true
    dirs[#dirs + 1] = dir
  end
end
for dir in (vim.env.PATH or ''):gmatch('[^:]+') do
  -- drop Windows folders and folders that don't exist (stat on the Linux disk is cheap)
  if not dir:find('^/mnt/%a/') and uv.fs_stat(dir) then add(dir) end
end
for _, dir in ipairs({ '/usr/local/bin', '/usr/bin', '/bin' }) do add(dir) end
add(shims)
vim.env.PATH = table.concat(dirs, ':')

-- 2. Clipboard -----------------------------------------------------------------
local ok, osc52 = pcall(require, 'vim.ui.clipboard.osc52')
if ok then
  local function paste()
    local out = vim.fn.system({
      POWERSHELL, '-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
      '[Console]::OutputEncoding = [Text.Encoding]::UTF8; [Console]::Out.Write((Get-Clipboard -Raw))',
    })
    return vim.split(out:gsub('\r', ''), '\n', { plain = true })
  end
  vim.g.clipboard = {
    name = 'wsl (osc52 copy, powershell paste)',
    copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
    paste = { ['+'] = paste, ['*'] = paste },
  }

  -- Plain y (no register given) is mirrored to Windows. Deletes (d, x, c) are
  -- not, so they never overwrite what you copied in another app.
  vim.api.nvim_create_autocmd('TextYankPost', {
    group = vim.api.nvim_create_augroup('wsl_clipboard', { clear = true }),
    callback = function()
      local ev = vim.v.event
      if ev.operator == 'y' and ev.regname == '' then osc52.copy('+')(ev.regcontents) end
    end,
  })
end

-- 3. Open in Windows -----------------------------------------------------------
-- rundll32 + url.dll = the Windows "open with default app" call. Unlike
-- explorer.exe it returns exit code 0, so gx doesn't report a false error.
---@diagnostic disable-next-line: duplicate-set-field
vim.ui.open = function(path)
  if not path:find('^%a[%w+.-]*:') then -- a local path, not a URL / mailto:
    local abs = vim.fs.abspath(vim.fs.normalize(path))
    if uv.fs_stat(abs) then
      local res = vim.system({ 'wslpath', '-w', abs }, { text = true }):wait()
      if res.code == 0 then path = vim.trim(res.stdout) end
    end
  end
  return vim.system({ WIN .. '/System32/rundll32.exe', 'url.dll,FileProtocolHandler', path }, { cwd = '/mnt/c' }), nil
end

return M
