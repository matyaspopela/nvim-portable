-- Writing code: completion, formatting, Neovim-API types for config editing
local nerd = vim.g.have_nerd_font

return {
  { -- completion menu (fast, fuzzy, typo-tolerant), signature help, snippets
    -- (LSP's + friendly-snippets: `for`, `class`, `main`, `ifmain`, `def`, …)
    'saghen/blink.cmp',
    version = '1.*', -- release builds ship a prebuilt ARM64 fuzzy matcher
    dependencies = { 'rafamadriz/friendly-snippets' },
    event = { 'InsertEnter', 'CmdlineEnter' }, -- (lua/config/lsp.lua loads it at startup anyway)
    opts = {
      -- Tab / Shift-Tab move through the menu (and jump between snippet fields).
      -- Enter accepts only an item you picked; otherwise it's a normal new line
      -- (between brackets {|} it opens an indented line: mini.pairs).
      keymap = {
        preset = 'none',
        ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
        ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
        ['<CR>'] = {
          'accept',
          function() return _G.MiniPairs and MiniPairs.cr() end,
          'fallback',
        },
        ['<C-Space>'] = { 'show', 'show_documentation', 'hide_documentation' },
        ['<C-e>'] = { 'cancel', 'fallback' },
        ['<C-n>'] = { 'select_next', 'fallback' },
        ['<C-p>'] = { 'select_prev', 'fallback' },
        ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
        ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
        ['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },
      },
      appearance = { nerd_font_variant = 'mono' },
      completion = {
        list = { selection = { preselect = false, auto_insert = true } },
        accept = { auto_brackets = { enabled = true } }, -- sort|  ->  sort(|)
        menu = {
          border = 'rounded',
          scrollbar = false,
          draw = {
            padding = { 1, 1 },
            treesitter = { 'lsp' }, -- colour the labels like code
            -- icon + name (+ signature); the kind is already in the icon
            columns = nerd and { { 'kind_icon' }, { 'label', 'label_description', gap = 1 } }
              or { { 'label', 'label_description', gap = 1 }, { 'kind' } },
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          window = { border = 'rounded', scrollbar = false, max_width = 80 },
        },
        ghost_text = { enabled = true }, -- the selected item previewed in the code
      },
      signature = { enabled = true, window = { border = 'rounded', scrollbar = false, show_documentation = false } },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
        per_filetype = { lua = { inherit_defaults = true, 'lazydev' } },
        providers = {
          lazydev = { name = 'LazyDev', module = 'lazydev.integrations.blink', score_offset = 100 },
          buffer = { min_keyword_length = 3, max_items = 5 },
        },
      },
      -- ':' command line: menu yes, ghost text no (it glued half-matched names onto what you typed)
      cmdline = { completion = { menu = { auto_show = true }, ghost_text = { enabled = false } } },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },
  },

  { -- Manual formatting only: <leader>cf formats the file or selection.
    'stevearc/conform.nvim',
    cmd = 'ConformInfo',
    keys = {
      {
        '<leader>cf',
        function() require('conform').format({ async = true }) end,
        mode = { 'n', 'x' },
        desc = 'Format file / selection',
      },
    },
    opts = function()
      -- Style for C/C++ files whose project has no .clang-format: LLVM, with
      -- your indentation (tabs, 4 wide) and 100 columns.
      local function fallback_style(buf)
        local width = vim.bo[buf].shiftwidth > 0 and vim.bo[buf].shiftwidth or vim.bo[buf].tabstop
        return ('{BasedOnStyle: LLVM, IndentWidth: %d, TabWidth: %d, UseTab: %s, ColumnLimit: 100, '
          .. 'AllowShortFunctionsOnASingleLine: None, AllowShortLambdasOnASingleLine: None}')
          :format(width, vim.bo[buf].tabstop, vim.bo[buf].expandtab and 'Never' or 'ForIndentation')
      end
      local clang = { 'clang-format' }
      return {
        formatters_by_ft = {
          c = clang, cpp = clang, cuda = clang, proto = clang,
          cmake = { lsp_format = 'prefer' }, -- neocmakelsp formats CMakeLists.txt
          lua = { 'stylua', lsp_format = 'fallback' },
          python = { 'ruff_organize_imports', 'ruff_format' },
          rust = { 'rustfmt', lsp_format = 'fallback' },
        },
        default_format_opts = { lsp_format = 'fallback' },
        formatters = {
          ['clang-format'] = {
            command = require('config.lsp').llvm('clang-format'),
            prepend_args = function(_, ctx)
              local own = vim.fs.find({ '.clang-format', '_clang-format' }, { upward = true, path = ctx.dirname })[1]
              return { '--style=' .. (own and '{BasedOnStyle: InheritParentConfig, AllowShortFunctionsOnASingleLine: None, AllowShortLambdasOnASingleLine: None}' or fallback_style(ctx.buf)) }
            end,
          },
        },
      }
    end,
  },

  { -- <leader>cn on a function / class / file: a doc comment skeleton with the
    -- parameters filled in (Doxygen for C / C++, Google-style docstrings for
    -- Python, rustdoc, LuaDoc). Tab jumps between the fields.
    'danymat/neogen',
    cmd = 'Neogen',
    keys = { { '<leader>cn', function() require('neogen').generate() end, desc = 'Generate doc comment' } },
    opts = {
      snippet_engine = 'nvim',
      languages = {
        c = { template = { annotation_convention = 'doxygen' } },
        cpp = { template = { annotation_convention = 'doxygen' } },
        python = { template = { annotation_convention = 'google_docstrings' } },
      },
    },
  },

  { -- Neovim's Lua API in completion / hover while editing this config
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        { path = 'snacks.nvim', words = { 'Snacks' } },
      },
    },
  },
}
