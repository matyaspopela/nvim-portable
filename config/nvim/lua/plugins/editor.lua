-- Editing and navigation: jump, search & replace, problems panel, sessions,
-- git signs, TODOs, indentation detection, brackets, surround, text objects
return {
  { -- S + a letter or two + the label that appears: you're there. Works after
    -- an operator too (dS…, yS…). Ctrl+Space selects syntax nodes, grow with ;
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = { modes = { char = { multi_line = false } } },
    keys = {
      { 'S', function() require('flash').jump() end, mode = { 'n', 'x', 'o' }, desc = 'Jump anywhere (flash)' },
      { '<C-Space>', function() require('flash').treesitter() end, mode = { 'n', 'x', 'o' }, desc = 'Select syntax node' },
      { 'r', function() require('flash').remote() end, mode = 'o', desc = 'Remote operation (flash)' },
    },
  },

  { -- project-wide search & replace (ripgrep) with a live preview of every change
    'MagicDuck/grug-far.nvim',
    cmd = { 'GrugFar', 'GrugFarWithin' },
    opts = { headerMaxWidth = 80 },
    keys = {
      {
        '<leader>sr',
        function()
          local ext = vim.bo.buftype == '' and vim.fn.expand('%:e')
          require('grug-far').open({
            transient = true,
            prefills = { filesFilter = ext and ext ~= '' and '*.' .. ext or nil },
          })
        end,
        mode = { 'n', 'x' },
        desc = 'Search & replace in project',
      },
      {
        '<leader>sw',
        function() require('grug-far').open({ transient = true, prefills = { search = vim.fn.expand('<cword>') } }) end,
        desc = 'Replace word under cursor in project',
      },
    },
  },

  { -- "Problems" panel, symbol outline, quickfix — the IDE side panels
    'folke/trouble.nvim',
    cmd = 'Trouble',
    opts = {
      focus = true,
      -- plain indentation instead of tree lines
      icons = { indent = { top = '  ', middle = '  ', last = '  ', ws = '  ' } },
    },
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>', desc = 'Problems (project)' },
      { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', desc = 'Problems (this file)' },
      { '<leader>xq', '<cmd>Trouble qflist toggle<CR>', desc = 'Quickfix list (build errors)' },
      { '<leader>xl', '<cmd>Trouble loclist toggle<CR>', desc = 'Location list' },
      { '<leader>xt', '<cmd>Trouble todo toggle<CR>', desc = 'TODO / FIXME list' },
      { '<leader>cs', '<cmd>Trouble symbols toggle focus=false win.size=40<CR>', desc = 'Symbols outline' },
      { '<leader>cS', '<cmd>Trouble lsp toggle focus=false win.position=right<CR>', desc = 'Definitions / references panel' },
      { -- ]q [q walk the Trouble list when it's open, else the quickfix list
        ']q',
        function()
          local trouble = require('trouble')
          if trouble.is_open() then
            ---@diagnostic disable-next-line: missing-parameter, missing-fields (trouble's own annotation is off; this is its documented call)
            trouble.next({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cnext)
            if not ok then vim.notify(err:gsub('^Vim%(%a+%):', ''), vim.log.levels.WARN) end
          end
        end,
        desc = 'Next quickfix / Trouble item',
      },
      {
        '[q',
        function()
          local trouble = require('trouble')
          if trouble.is_open() then
            ---@diagnostic disable-next-line: missing-parameter, missing-fields
            trouble.prev({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cprev)
            if not ok then vim.notify(err:gsub('^Vim%(%a+%):', ''), vim.log.levels.WARN) end
          end
        end,
        desc = 'Previous quickfix / Trouble item',
      },
    },
  },

  { -- sessions: open buffers and splits are saved per project folder on exit
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = {},
    keys = {
      { '<leader>Ss', function() require('persistence').load() end, desc = 'Restore session (this folder)' },
      { '<leader>Sl', function() require('persistence').load({ last = true }) end, desc = 'Restore last session' },
      { '<leader>Sf', function() require('persistence').select() end, desc = 'Pick a session' },
      { '<leader>Sd', function() require('persistence').stop() end, desc = "Don't save this session" },
    },
  },

  { -- git: changed lines in the gutter, hunk preview / stage / reset, blame
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      -- thin marks next to the line numbers
      signs = {
        add = { text = '▎' }, change = { text = '▎' }, delete = { text = '\u{f0da}' },
        topdelete = { text = '\u{f0da}' }, changedelete = { text = '▎' }, untracked = { text = '▎' },
      },
      signs_staged = {
        add = { text = '▎' }, change = { text = '▎' }, delete = { text = '\u{f0da}' },
        topdelete = { text = '\u{f0da}' }, changedelete = { text = '▎' },
      },
      on_attach = function(buf)
        local gs = require('gitsigns')
        local function map(lhs, rhs, desc, mode)
          vim.keymap.set(mode or 'n', lhs, rhs, { buffer = buf, desc = desc })
        end
        map(']h', function() gs.nav_hunk('next') end, 'Next git change')
        map('[h', function() gs.nav_hunk('prev') end, 'Previous git change')
        map('<leader>gp', gs.preview_hunk_inline, 'Preview change')
        map('<leader>gS', gs.stage_hunk, 'Stage / unstage change', { 'n', 'x' })
        map('<leader>gr', gs.reset_hunk, 'Undo change (reset hunk)', { 'n', 'x' })
        map('<leader>gR', gs.reset_buffer, 'Undo all changes in file')
        map('<leader>gb', function() gs.blame_line({ full = true }) end, 'Blame line')
        map('<leader>gt', gs.toggle_current_line_blame, 'Toggle inline blame')
        map('<leader>gD', gs.diffthis, 'Diff file against index')
        map('ih', gs.select_hunk, 'Inside git change', { 'o', 'x' })
      end,
    },
  },

  { -- git diffs & history in a tab: every changed file side by side, a 3-way
    -- merge view for conflicts (]x [x jump between them; <leader>co / ct / cb / ca
    -- take ours / theirs / base / all), file and branch history. q closes it.
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles' },
    keys = {
      {
        '<leader>gv',
        function()
          if next(require('diffview.lib').views) then vim.cmd('DiffviewClose') else vim.cmd('DiffviewOpen') end
        end,
        desc = 'Diff view: all changes / merge conflicts (toggle)',
      },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<CR>', desc = 'History of this file' },
      { '<leader>gh', ":'<,'>DiffviewFileHistory<CR>", mode = 'x', desc = 'History of the selected lines' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<CR>', desc = 'History of the branch' },
    },
    opts = function()
      local close = { 'n', 'q', '<cmd>DiffviewClose<CR>', { desc = 'Close diff view' } }
      return {
        enhanced_diff_hl = true, -- changed words stand out inside changed lines
        view = { merge_tool = { layout = 'diff3_mixed' } },
        file_panel = { win_config = { width = 34 } },
        keymaps = { view = { close }, file_panel = { close }, file_history_panel = { close } },
      }
    end,
  },

  { -- TODO / FIXME / HACK / NOTE comments highlighted; ]t [t jump, <leader>ft lists
    'folke/todo-comments.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {},
    keys = {
      { ']t', function() require('todo-comments').jump_next() end, desc = 'Next TODO' },
      { '[t', function() require('todo-comments').jump_prev() end, desc = 'Previous TODO' },
      { '<leader>ft', function() Snacks.picker.todo_comments() end, desc = 'TODOs in project' }, ---@diagnostic disable-line: undefined-field
    },
  },

  { -- detects whether an existing file uses tabs or spaces (and how many)
    'NMAC427/guess-indent.nvim',
    event = 'BufReadPre',
    opts = {},
  },

  { -- auto-close ( [ { " ' — only before a space / closing bracket / line end,
    -- and a quote after a letter stays single (don't, 1'000'000, \" still work)
    'nvim-mini/mini.pairs',
    event = 'InsertEnter',
    opts = {
      modes = { insert = true, command = false, terminal = false },
      mappings = {
        ['('] = { action = 'open', pair = '()', neigh_pattern = '[^\\][%s%)%]%},;\n]' },
        ['['] = { action = 'open', pair = '[]', neigh_pattern = '[^\\][%s%)%]%},;\n]' },
        ['{'] = { action = 'open', pair = '{}', neigh_pattern = '[^\\][%s%)%]%},;\n]' },
        [')'] = { action = 'close', pair = '()', neigh_pattern = '[^\\].' },
        [']'] = { action = 'close', pair = '[]', neigh_pattern = '[^\\].' },
        ['}'] = { action = 'close', pair = '{}', neigh_pattern = '[^\\].' },
        ['"'] = { action = 'closeopen', pair = '""', neigh_pattern = '[^%w\\][%s%)%]%},;\n]', register = { cr = false } },
        ["'"] = { action = 'closeopen', pair = "''", neigh_pattern = '[^%w\\][%s%)%]%},;\n]', register = { cr = false } },
        ['`'] = false,
      },
    },
  },

  { -- surround:  saiw)  wrap word in ( )   sd"  delete quotes   sr)]  ( ) -> [ ]
    'nvim-mini/mini.surround',
    keys = { { 's', mode = { 'n', 'x' } } },
    opts = { n_lines = 50 },
  },

  { -- text objects:  daf delete function   cia change argument   vic inside class
    -- yiq inside quotes   dib inside any bracket   cio inside if / loop body
    'nvim-mini/mini.ai',
    event = 'VeryLazy',
    dependencies = { { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'main' } },
    opts = function()
      local ts = require('mini.ai').gen_spec.treesitter
      return {
        n_lines = 500,
        custom_textobjects = {
          f = ts({ a = '@function.outer', i = '@function.inner' }),
          c = ts({ a = '@class.outer', i = '@class.inner' }),
          o = ts({ a = { '@conditional.outer', '@loop.outer' }, i = { '@conditional.inner', '@loop.inner' } }),
          F = ts({ a = '@call.outer', i = '@call.inner' }),
        },
      }
    end,
  },
}
