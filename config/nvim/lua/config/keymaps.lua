-- General key bindings. LSP keys are in lua/config/lsp.lua, plugin keys next
-- to each plugin in lua/plugins/. Press <Space> and wait to see all of them.
local map = vim.keymap.set

map('i', 'jk', '<Esc>', { desc = 'Leave insert mode' })
map('n', '<Esc>', '<cmd>nohlsearch<CR><Esc>', { desc = 'Clear search highlight' })

-- Save
map({ 'n', 'i', 'x', 's' }, '<C-s>', '<cmd>write<CR><Esc>', { desc = 'Save file' })
map('n', '<leader>w', '<cmd>write<CR>', { desc = 'Save file' })

-- Closing never quits Neovim: :q, :wq, :x, ZZ, ZQ, Ctrl+w q and <leader>q close
-- the window — or, in the last editor window, just the file (the start screen
-- shows when no file is left). Neovim itself quits only with :Q / <leader>Q
-- (:Q! without asking about unsaved changes; :qa still works too).
local function is_editor(win)
  return vim.api.nvim_win_get_config(win).relative == '' and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ''
end

-- run an Ex command; on failure show just "E…: message" as a notification
local function try(cmd, title)
  local ok, err = pcall(vim.api.nvim_command, cmd)
  if not ok then
    err = tostring(err)
    vim.notify(err:match('E%d+: .*') or err, vim.log.levels.WARN, { title = title })
  end
  return ok
end

local function close(force)
  local win = vim.api.nvim_get_current_win()
  if vim.bo.filetype == 'snacks_dashboard' then
    return vim.notify('Neovim stays open: :Q quits', vim.log.levels.INFO, { title = 'Close', id = 'close_hint' })
  end
  local others = vim.tbl_filter(function(w)
    return w ~= win and vim.api.nvim_win_get_config(w).relative == ''
  end, vim.api.nvim_tabpage_list_wins(0))
  -- a popup, a side window (explorer, terminal, help, quickfix, …) or one of
  -- several editor splits: close just this window
  if vim.api.nvim_win_get_config(win).relative ~= '' or (#others > 0 and (not is_editor(win) or vim.iter(others):any(is_editor))) then
    try(force and 'close!' or 'close', 'Close')
    return
  end
  if #vim.api.nvim_list_tabpages() > 1 then
    return vim.cmd(force and 'tabclose!' or 'tabclose')
  end
  -- the last editor window: close the file, keep the window and Neovim
  Snacks.bufdelete({ force = force })
  vim.schedule(function()
    local files = vim.tbl_filter(function(b)
      return vim.bo[b].buflisted and vim.api.nvim_buf_get_name(b) ~= ''
    end, vim.api.nvim_list_bufs())
    -- draw the start screen into this window's empty buffer, as at startup
    -- (plain Snacks.dashboard() opens a float on top, and a file opened from
    -- there would end up in the float)
    if #files == 0 and vim.api.nvim_buf_get_name(0) == '' and not vim.bo.modified then
      ---@diagnostic disable-next-line: missing-fields (the rest comes from the dashboard config)
      Snacks.dashboard({ buf = 0, win = 0 })
    end
  end)
end

vim.api.nvim_create_user_command('Close', function(o) close(o.bang) end,
  { bang = true, desc = 'Close the window / file (never quits Neovim)' })
vim.api.nvim_create_user_command('WClose', function(o)
  if try(o.bang and 'update!' or 'update', 'Save') then close(o.bang) end
end, { bang = true, desc = 'Save, then close the window / file' })
vim.api.nvim_create_user_command('Q', function(o) vim.cmd(o.bang and 'qall!' or 'confirm qall') end,
  { bang = true, desc = 'Quit Neovim' })

-- :q → :Close, :wq / :x → :WClose — only when that is the whole command typed
-- at the : prompt (so :s/q/…/ or a search for "q" are left alone)
for typed, cmd in pairs({ q = 'Close', quit = 'Close', wq = 'WClose', x = 'WClose', xit = 'WClose', exit = 'WClose' }) do
  vim.cmd(("cnoreabbrev <expr> %s (getcmdtype() ==# ':' && getcmdline() ==# '%s') ? '%s' : '%s'"):format(typed, typed, cmd, typed))
end

map('n', '<leader>q', '<cmd>Close<CR>', { desc = 'Close window / file' })
map('n', '<leader>Q', '<cmd>Q<CR>', { desc = 'Quit Neovim' })
map('n', 'ZZ', '<cmd>WClose<CR>', { desc = 'Save and close' })
map('n', 'ZQ', '<cmd>Close!<CR>', { desc = 'Close without saving' })
map('n', '<C-w>q', '<cmd>Close<CR>', { desc = 'Close window / file' })
map('n', '<C-w><C-q>', '<cmd>Close<CR>', { desc = 'which_key_ignore' })

-- Windows (splits)
for _, k in ipairs({ 'h', 'j', 'k', 'l' }) do
  map('n', '<C-' .. k .. '>', '<C-w>' .. k, { desc = 'Go to window ' .. k })
end
map('n', '<leader>-', '<C-w>s', { desc = 'Split below' })
map('n', '<leader>|', '<C-w>v', { desc = 'Split right' })
map('n', '<A-Left>', '<cmd>vertical resize -4<CR>', { desc = 'Narrower window' })
map('n', '<A-Right>', '<cmd>vertical resize +4<CR>', { desc = 'Wider window' })
map('n', '<A-Up>', '<cmd>resize +2<CR>', { desc = 'Taller window' })
map('n', '<A-Down>', '<cmd>resize -2<CR>', { desc = 'Shorter window' })

-- Buffers (open files) — the tab bar at the top shows them. Shift+H / Shift+L
-- cycle through them (lua/plugins/ui.lua).
map('n', '<leader>bb', '<C-^>', { desc = 'Alternate buffer' })
map('n', '<leader>bd', function() Snacks.bufdelete() end, { desc = 'Close buffer' })
map('n', '<leader>bo', function() Snacks.bufdelete.other() end, { desc = 'Close other buffers' })

-- Editing
map('x', '>', '>gv', { desc = 'Indent, keep selection' })
map('x', '<', '<gv', { desc = 'Unindent, keep selection' })
map('n', '<A-j>', '<cmd>move .+1<CR>==', { desc = 'Move line down' })
map('n', '<A-k>', '<cmd>move .-2<CR>==', { desc = 'Move line up' })
map('i', '<A-j>', '<Esc><cmd>move .+1<CR>==gi', { desc = 'Move line down' })
map('i', '<A-k>', '<Esc><cmd>move .-2<CR>==gi', { desc = 'Move line up' })
map('x', '<A-j>', ":move '>+1<CR>gv=gv", { silent = true, desc = 'Move lines down' })
map('x', '<A-k>', ":move '<-2<CR>gv=gv", { silent = true, desc = 'Move lines up' })
for _, ch in ipairs({ ',', '.', ';' }) do -- u undoes a sentence, not the whole insert
  map('i', ch, ch .. '<C-g>u')
end
map('n', 'n', 'nzzzv', { desc = 'Next match (centred)' })
map('n', 'N', 'Nzzzv', { desc = 'Previous match (centred)' })

-- Windows clipboard (plain y already copies to Windows, see lua/config/wsl.lua)
map('n', '<leader>y', function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  vim.fn.setreg('+', lines, 'l')
  vim.notify(('Copied %d lines to the clipboard'):format(#lines))
end, { desc = 'Copy whole file to clipboard' })
map('x', '<leader>y', '"+y', { desc = 'Copy selection to clipboard' })
map({ 'n', 'x' }, '<leader>p', '"+p', { desc = 'Paste from Windows clipboard' })

-- Diagnostics (errors / warnings). ]d [d also work (Neovim defaults).
local function jump(count, severity)
  return function() vim.diagnostic.jump({ count = count, severity = severity }) end
end
map('n', ']e', jump(1, vim.diagnostic.severity.ERROR), { desc = 'Next error' })
map('n', '[e', jump(-1, vim.diagnostic.severity.ERROR), { desc = 'Previous error' })
map('n', ']w', jump(1, vim.diagnostic.severity.WARN), { desc = 'Next warning' })
map('n', '[w', jump(-1, vim.diagnostic.severity.WARN), { desc = 'Previous warning' })
map('n', 'gl', vim.diagnostic.open_float, { desc = 'Show full error message' })
map('n', '<leader>cd', vim.diagnostic.open_float, { desc = 'Line diagnostics' })

-- IDE: build / run / debug (lua/ide/run.lua decides CMake, make or single file)
local function ide(fn) return function() require('ide.run')[fn]() end end
map('n', '<F5>', ide('debug'), { desc = 'Debug: start / continue' })
map('n', '<C-F5>', ide('run'), { desc = 'Run (no debugger)' })
map('n', '<F29>', ide('run'), { desc = 'which_key_ignore' }) -- Ctrl+F5 in some terminals
map('n', '<F7>', ide('build'), { desc = 'Build' })
map('n', '<leader>mb', ide('build'), { desc = 'Build' })
map('n', '<leader>mr', ide('run'), { desc = 'Run' })
map('n', '<leader>md', ide('debug'), { desc = 'Debug' })
map('n', '<leader>mf', ide('run_file'), { desc = 'Build & run this file (no CMake)' })
map('n', '<leader>mm', ide('toggle_profile'), { desc = 'Single-file profile: debug ⇄ release' })
map('n', '<leader>mM', ide('toggle_folder_mode'), { desc = 'This folder: CMake / make ⇄ single file' })
vim.api.nvim_create_user_command('Build', ide('build'), { desc = 'Build (CMake / make / this file)' })
vim.api.nvim_create_user_command('Debug', ide('debug'), { desc = 'Debug (CMake / make / this file)' })
vim.api.nvim_create_user_command('Run', function(cmd)
  local run = require('ide.run')
  if cmd.args ~= '' or cmd.bang then run.args = cmd.args end -- single-file arguments; :Run! clears them
  run.run()
end, { nargs = '*', bang = true, complete = 'file', desc = 'Run (CMake / make / this file)' })

-- What the compiler made of it (lua/ide/asm.lua): assembly + optimisation remarks
local function asm(fn, arg) return function() require('ide.asm')[fn](arg) end end
map('n', '<leader>mA', asm('asm'), { desc = 'Assembly of this file (live, linked to source)' })
map('n', '<leader>mv', asm('remarks'), { desc = 'Optimisation remarks (vectorised? inlined?)' })
map('n', '<leader>mV', asm('clear_remarks'), { desc = 'Clear optimisation remarks' })
vim.api.nvim_create_user_command('Asm', function(cmd)
  require('ide.asm').asm(cmd.bang and '' or (cmd.args ~= '' and cmd.args or nil))
end, { nargs = '*', bang = true, desc = 'Assembly of this file; :Asm -O3 adds flags (remembered), :Asm! drops them' })
vim.api.nvim_create_user_command('OptRemarks', function(cmd) require('ide.asm').remarks(cmd.args) end,
  { nargs = '*', desc = 'Optimisation remarks for this file; extra flags allowed' })

-- Misc
map('n', '<leader>fE', function() require('config.wsl').reveal(vim.fn.expand('%:p:h')) end,
  { desc = "Show file's folder in Windows Explorer" })
map('n', '<leader>L', '<cmd>Lazy<CR>', { desc = 'Plugins (Lazy)' })
map('n', '<leader>cm', '<cmd>Mason<CR>', { desc = 'Language servers (Mason)' })
map('n', '<leader>ci', '<cmd>checkhealth vim.lsp<CR>', { desc = 'LSP status' })
