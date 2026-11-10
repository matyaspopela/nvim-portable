-- snacks.nvim: fuzzy finder, file explorer, terminal, lazygit, start screen,
-- notifications, indent guides, reference highlighting, big-file guard —
-- one fast plugin instead of ten.
local function P(source, opts)
  return function() Snacks.picker[source](opts) end
end

--- Ctrl+h/j/k/l inside a terminal split: jump to the neighbouring window, like
--- in normal mode. In floating terminals (lazygit) the keys go to the program.
local function term_nav(dir)
  ---@param self snacks.win
  return function(self)
    return self:is_floating() and '<C-' .. dir .. '>' or vim.schedule(function() vim.cmd.wincmd(dir) end)
  end
end

return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    bigfile = { enabled = true }, -- huge files open instantly (no LSP / Treesitter on them)
    quickfile = { enabled = true }, -- `nvim file.cpp` draws the file before plugins load
    input = { enabled = true }, -- rename / prompts in a small floating box
    notifier = { enabled = true, timeout = 3000 },
    scope = { enabled = true }, -- ii / ai = inside / around the current indent block
    words = { enabled = true, debounce = 200 }, -- highlight other uses of the symbol; ]] / [[ jump
    -- no rows of indent lines: one faint line marks the block the cursor is in
    indent = {
      enabled = true,
      indent = { enabled = false },
      scope = { enabled = true, char = '▏', underline = false },
      animate = { enabled = false },
    },
    statuscolumn = { enabled = true }, -- signs, git marks and folds next to the line numbers
    lazygit = { enabled = true }, -- lazygit gets the colour scheme's colours automatically
    terminal = { enabled = true },
    explorer = { enabled = true, replace_netrw = true },
    picker = {
      enabled = true,
      ui_select = true, -- code actions, cmake target lists etc. use the picker
      prompt = '\u{f0349}  ',
      layout = {
        cycle = true,
        preset = function() return vim.o.columns >= 120 and 'soft' or 'soft_narrow' end,
      },
      -- one rounded card: no separator line under the prompt, no line between
      -- list and preview (just space), no darkened backdrop
      icons = {
        tree = { vertical = '  ', middle = '  ', last = '  ' }, -- explorer: indentation, no tree lines
        diagnostics = { Error = '\u{f015a} ', Warn = '\u{f05d6} ', Info = '\u{f02fd} ', Hint = '\u{f0336} ' },
      },
      layouts = {
        soft = {
          layout = {
            box = 'horizontal', width = 0.8, min_width = 110, height = 0.8, backdrop = false,
            border = 'rounded', title = ' {title} {live} {flags}', title_pos = 'center',
            {
              box = 'vertical',
              { win = 'input', height = 1, border = { '', '', '', '', '', ' ', '', '' } },
              { win = 'list', border = 'none' },
            },
            { win = 'preview', width = 0.55, border = { '', '', '', '', '', '', '', ' ' } },
          },
        },
        sidebar = { -- the explorer
          preview = 'main',
          layout = {
            backdrop = false, width = 32, min_width = 32, height = 0, position = 'left', border = 'none', box = 'vertical',
            { win = 'input', height = 1, border = { '', ' ', '', '', '', ' ', '', '' }, title = '{title} {live} {flags}', title_pos = 'center' },
            { win = 'list', border = 'none' },
            { win = 'preview', title = '{preview}', height = 0.4, border = { '', ' ', '', '', '', '', '', '' } },
          },
        },
        soft_narrow = {
          layout = {
            box = 'vertical', width = 0.9, min_width = 60, height = 0.9, backdrop = false,
            border = 'rounded', title = ' {title} {live} {flags}', title_pos = 'center',
            { win = 'input', height = 1, border = { '', '', '', '', '', ' ', '', '' } },
            { win = 'list', border = 'none' },
            { win = 'preview', title = ' {preview} ', title_pos = 'center', height = 0.45, border = { '', ' ', '', '', '', '', '', '' } },
          },
        },
        select = { -- code actions, cmake targets, …
          layout = {
            box = 'vertical', width = 0.5, min_width = 60, max_width = 100, height = 0.4, min_height = 4,
            backdrop = false, border = 'rounded', title = ' {title} ', title_pos = 'center',
            { win = 'input', height = 1, border = { '', '', '', '', '', ' ', '', '' } },
            { win = 'list', border = 'none' },
          },
        },
      },
      matcher = { frecency = true }, -- files you open often rank higher
      sources = {
        files = { hidden = true }, -- show dotfiles (.clang-format, .github …); .gitignore'd stay hidden
        grep = { hidden = true },
        explorer = { hidden = true, layout = { preset = 'sidebar' } },
      },
    },
    -- start screen: a greeting instead of a banner, lowercase, plenty of air
    dashboard = {
      width = 50,
      preset = {
        keys = {
          { icon = '\u{f0349} ', key = 'f', desc = 'find file', action = ":lua Snacks.dashboard.pick('files')" },
          { icon = '\u{f13b8} ', key = 'g', desc = 'find text', action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = '\u{f02da} ', key = 'r', desc = 'recent files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = '\u{f0256} ', key = 'e', desc = 'explorer', action = function() Snacks.explorer() end },
          { icon = '\u{f099b} ', key = 's', desc = 'restore session', section = 'session' },
          { icon = '\u{f08bb} ', key = 'c', desc = 'config', action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })" },
          { icon = '\u{f0425} ', key = 'Q', desc = 'quit', action = ':Q' }, -- like everywhere: only Q quits
          { key = 'q', hidden = true, action = ':Close' }, -- says so (snacks' own q would leave a blank window)
        },
      },
      sections = {
        function()
          return { text = { { '\u{f011b}', hl = 'SnacksDashboardIcon' } }, align = 'center', padding = 1 }
        end,
        function()
          local hour = os.date('*t').hour
          local when = hour < 5 and 'night' or hour < 12 and 'morning' or hour < 18 and 'afternoon' or 'evening'
          local text = ('good %s, %s'):format(when, vim.env.USER or vim.env.USERNAME or 'friend')
          return { text = { { text, hl = 'SnacksDashboardHeader' } }, align = 'center' }
        end,
        function()
          local t = os.date('*t') -- (Windows' os.date has no %-d)
          local date = (os.date('%A') .. ' · ' .. t.day .. ' ' .. os.date('%B')):lower()
          return { text = { { date, hl = 'SnacksDashboardFooter' } }, align = 'center', padding = 2 }
        end,
        { section = 'keys', gap = 1, padding = 2 },
        { title = 'recent', section = 'recent_files', cwd = true, limit = 5, indent = 2, padding = 2 },
        { title = 'projects', section = 'projects', limit = 4, indent = 2, padding = 2 },
        { section = 'startup' },
      },
    },
    styles = {
      notification = { wo = { wrap = true } },
      terminal = {
        wo = { winbar = '' }, -- no title line above the shell
        keys = {
          nav_h = { '<C-h>', term_nav('h'), desc = 'Go to left window', expr = true, mode = 't' },
          nav_j = { '<C-j>', term_nav('j'), desc = 'Go to lower window', expr = true, mode = 't' },
          nav_k = { '<C-k>', term_nav('k'), desc = 'Go to upper window', expr = true, mode = 't' },
          nav_l = { '<C-l>', term_nav('l'), desc = 'Go to right window', expr = true, mode = 't' },
        },
      },
    },
  },
  keys = {
    -- find
    { '<leader><space>', P('smart'), desc = 'Find file (smart)' },
    { '<leader>ff', P('files'), desc = 'Find file' },
    { '<leader>fg', P('grep'), desc = 'Find text in project' },
    { '<leader>/', P('grep'), desc = 'Find text in project' },
    { '<leader>fw', P('grep_word'), desc = 'Find word under cursor', mode = { 'n', 'x' } },
    { '<leader>fb', P('buffers'), desc = 'Open buffers' },
    { '<leader>fr', P('recent'), desc = 'Recent files' },
    { '<leader>fl', P('lines'), desc = 'Lines in this file' },
    { '<leader>fd', P('diagnostics_buffer'), desc = 'Problems in this file' },
    { '<leader>fD', P('diagnostics'), desc = 'Problems everywhere' },
    { '<leader>fh', P('help'), desc = 'Help pages' },
    { '<leader>fk', P('keymaps'), desc = 'Key bindings' },
    { '<leader>fc', P('files', { cwd = vim.fn.stdpath('config') }), desc = 'Neovim config files' },
    { '<leader>fu', P('undo'), desc = 'Undo history' },
    { '<leader>fq', P('qflist'), desc = 'Quickfix list' },
    { '<leader>fj', P('jumps'), desc = 'Jump list' },
    { "<leader>f'", P('marks'), desc = 'Marks' },
    { '<leader>fp', P('projects'), desc = 'Projects' },
    { '<leader>f.', P('resume'), desc = 'Resume last search' },
    { '<leader>fn', function() Snacks.notifier.show_history() end, desc = 'Notification history' },
    { '<leader>e', function() Snacks.explorer() end, desc = 'File explorer' },
    -- git
    {
      '<leader>gg',
      function()
        if vim.fn.executable('lazygit') == 1 then Snacks.lazygit() else Snacks.picker.git_status() end
      end,
      desc = 'Lazygit',
    },
    { '<leader>gs', P('git_status'), desc = 'Git status' },
    { '<leader>gl', P('git_log'), desc = 'Git log' },
    { '<leader>gL', P('git_log_file'), desc = 'Git log of this file' },
    { '<leader>gd', P('git_diff'), desc = 'Changed hunks' },
    { '<leader>gB', function() Snacks.gitbrowse() end, desc = 'Open on GitHub / GitLab', mode = { 'n', 'x' } },
    -- terminal split at the bottom, in :pwd: Ctrl+/ shows / hides it (the shell
    -- keeps running). 2 Ctrl+/ = a second one. Windows Terminal sends Ctrl+/ as Ctrl+_
    { '<C-/>', function() Snacks.terminal() end, desc = 'Terminal', mode = { 'n', 't' } },
    { '<C-_>', function() Snacks.terminal() end, desc = 'which_key_ignore', mode = { 'n', 't' } },
    -- misc
    { ']]', function() Snacks.words.jump(vim.v.count1) end, desc = 'Next reference' },
    { '[[', function() Snacks.words.jump(-vim.v.count1) end, desc = 'Previous reference' },
    { '<leader>.', function() Snacks.scratch() end, desc = 'Scratch buffer' },
    { '<leader>uz', function() Snacks.zen() end, desc = 'Zen mode' },
    { '<leader>un', function() Snacks.notifier.hide() end, desc = 'Dismiss notifications' },
  },
  config = function(_, opts)
    require('snacks').setup(opts)

    -- Quitting with a terminal open: snacks closes its terminal windows on
    -- ExitPre, but Neovim cancels a quit when ExitPre changes the window layout,
    -- so the first :qa did nothing (a second one quit). Drop that hook from every
    -- terminal (snacks re-adds its hooks each time a terminal is shown again) and
    -- close terminal windows on VimLeavePre instead, once quitting is certain —
    -- sessions are then saved without them. (Patched right after startup, so
    -- loading the terminal module doesn't cost startup time.)
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      once = true,
      callback = function()
        local terminal = require('snacks.terminal')
        local open = terminal.open
        terminal.open = function(...)
          local term = open(...)
          if term then
            term.events = vim.tbl_filter(function(e) return e.event ~= 'ExitPre' end, term.events or {})
            if term.augroup then pcall(vim.api.nvim_clear_autocmds, { event = 'ExitPre', group = term.augroup }) end
          end
          return term
        end
      end,
    })
    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = vim.api.nvim_create_augroup('snacks_terminal_quit', { clear = true }),
      callback = function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'snacks_terminal' then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end
      end,
    })
  end,
  init = function()
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      once = true,
      callback = function()
        -- <leader>u… toggles; which-key shows each one's current state
        Snacks.toggle.option('relativenumber', { name = 'Relative numbers' }):map('<leader>ur')
        Snacks.toggle.line_number():map('<leader>ul')
        Snacks.toggle.option('wrap', { name = 'Wrap' }):map('<leader>uw')
        Snacks.toggle.option('spell', { name = 'Spelling' }):map('<leader>us')
        Snacks.toggle.diagnostics():map('<leader>ud')
        Snacks.toggle.inlay_hints():map('<leader>uh')
        Snacks.toggle.indent():map('<leader>ui')
        Snacks.toggle.treesitter():map('<leader>uT')
        Snacks.toggle.new({ -- Flexoki light ⇄ dark, remembered across restarts (also :Flexoki)
          id = 'flexoki_light',
          name = 'Light mode',
          get = function() return vim.o.background == 'light' end,
          set = function(on) require('flexoki').set(on and 'light' or 'dark') end,
        }):map('<leader>ub')
      end,
    })
  end,
}
