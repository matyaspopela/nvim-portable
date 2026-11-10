-- Editor settings
local o = vim.opt

-- Screen
o.number = true
o.relativenumber = true -- jump with 5j, 12k, d3j …  (<leader>ur toggles)
o.cursorline = true
o.signcolumn = 'yes' -- room for error / git / breakpoint signs, text never jumps
o.termguicolors = true
-- the cursor takes the colour scheme's caret colour (Flexoki: paper on dark, ink on light)
o.guicursor = 'n-v-c-sm:block-Cursor,i-ci-ve:ver25-Cursor,r-cr-o:hor20-Cursor,t:block-blinkon500-blinkoff500-TermCursor'
o.showmode = false -- the statusline shows the mode
o.laststatus = 3 -- one statusline for the whole screen
o.ruler = false
o.scrolloff = 8
o.sidescrolloff = 8
o.splitright = true
o.splitbelow = true
o.splitkeep = 'screen' -- text doesn't move when a split opens or closes
o.mouse = 'a'
o.winborder = 'rounded' -- borders on hover docs, diagnostics and other floats
o.pumheight = 12
o.wrap = false -- code doesn't wrap; prose filetypes turn it on (autocmds.lua)
o.linebreak = true
o.breakindent = true
o.smoothscroll = true
o.list = true
o.listchars = { tab = '  ', trail = '·', nbsp = '␣', extends = '›', precedes = '‹' }
o.fillchars = { eob = ' ', diff = '╱', fold = ' ', foldsep = ' ', foldopen = '\u{f47c}', foldclose = '\u{f460}' }
o.confirm = true -- ask to save instead of refusing :q with unsaved changes
o.shortmess:append('WIcC') -- no "written", intro or completion chatter
o.virtualedit = 'block' -- block selection may go past line ends
o.jumpoptions = 'stack,view' -- Ctrl-O / Ctrl-I work like browser back / forward
o.wildmode = 'longest:full,full'

-- Indentation: real tabs shown 4 wide (your CLion habit). A project's
-- .editorconfig, its .clang-format (when formatting), or the indentation an
-- existing file already uses (guess-indent) wins over this.
o.expandtab = false
o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4
o.autoindent = true
o.smartindent = false -- C/C++ use cindent from their ftplugin
-- cindent in LLVM / clang-format style: case labels and access specifiers not
-- indented, namespace bodies not indented, arguments aligned to the paren.
o.cinoptions = ':0,l1,g0,N-s,E-s,t0,(0,Ws,j1,J1'

-- Search
o.ignorecase = true
o.smartcase = true
o.inccommand = 'split' -- :s/old/new previews every change live
o.grepprg = 'rg --vimgrep --smart-case'
o.grepformat = '%f:%l:%c:%m'

-- Files
o.swapfile = false
o.undofile = true -- undo history survives restarts
o.undolevels = 10000
o.autoread = true
o.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'help', 'globals', 'skiprtp', 'folds' }

-- Timing
o.updatetime = 200 -- CursorHold: highlight references, save swap/undo
o.timeoutlen = 400 -- time to finish a key sequence (which-key pops up after it)
o.ttimeoutlen = 10 -- Esc is instant

-- Completion menu (blink.cmp draws it; these apply to the built-in fallback)
o.completeopt = { 'menu', 'menuone', 'noselect', 'popup' }

-- Folding by syntax tree, all open by default. za toggles, zM / zR close / open all.
o.foldmethod = 'expr'
o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
o.foldtext = '' -- a folded line keeps its syntax colours
o.foldlevel = 99
o.foldlevelstart = 99

-- Diff: better alignment of moved / changed blocks
o.diffopt:append({ 'algorithm:histogram', 'indent-heuristic' })

o.spelllang = { 'en' }

-- Tools installed with :Mason come first on PATH (Mason itself loads lazily)
local mason_bin = vim.fn.stdpath('data') .. '/mason/bin'
local sep = vim.g.is_win and ';' or ':'
if not (sep .. vim.env.PATH .. sep):find(sep .. mason_bin .. sep, 1, true) then
  vim.env.PATH = mason_bin .. sep .. vim.env.PATH
end

-- Providers this config doesn't use (skips their startup checks)
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
