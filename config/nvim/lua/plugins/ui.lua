-- Looks: statusline, tab bar of open files, key hints, LSP progress, icons.
-- Style: soft and rounded — "bubbles" in the statusline, no separator lines,
-- Flexoki colours (lua/flexoki): everything here follows light / dark live.
local icon = {
  error = '\u{f015a} ', warn = '\u{f05d6} ', info = '\u{f02fd} ', hint = '\u{f0336} ', terminal = '\u{f018d} ',
  cmake = '\u{e794} ', make = '\u{f0bE0} ', file = '\u{f0224} ', python = '\u{e73c} ', cargo = '\u{e7a8} ',
  lsp = '\u{f08bb} ', branch = '\u{e725}', modified = '●', readonly = '\u{f023}',
}

--- What F7 / Ctrl+F5 / F5 act on here: CMake (build type · launch target),
--- make, or the single file (debug / release profile). See lua/ide/run.lua.
local function build_status()
  local text, kind = require('ide.run').status()
  return text and icon[kind] .. text or ''
end

local function lsp_status()
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do names[#names + 1] = client.name end
  return #names > 0 and icon.lsp .. table.concat(names, ' ') or ''
end

local function recording()
  local reg = vim.fn.reg_recording()
  return reg ~= '' and '\u{f044a} recording @' .. reg or ''
end

return {
  { -- statusline: rounded bubbles floating on the editor background
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    init = function()
      -- blank statusline until lualine draws, so the default one doesn't flash
      vim.g.lualine_laststatus = vim.o.laststatus
      if vim.fn.argc(-1) > 0 then vim.o.statusline = ' ' else vim.o.laststatus = 0 end
    end,
    opts = function()
      vim.o.laststatus = vim.g.lualine_laststatus
      return {
        options = {
          theme = function() return require('flexoki').lualine() end, -- rebuilt when light / dark flips
          globalstatus = true,
          component_separators = '',
          section_separators = { left = '\u{e0b4}', right = '\u{e0b6}' },
          disabled_filetypes = { statusline = { 'snacks_dashboard' } },
          -- pickers, prompts and side panels don't take over the statusline
          ignore_focus = {
            'snacks_picker_input', 'snacks_picker_list', 'snacks_picker_preview', 'snacks_input',
            'snacks_layout_box', 'snacks_notif', 'trouble', 'dapui_scopes', 'dapui_watches',
            'dapui_stacks', 'dapui_breakpoints', 'dapui_console', 'dap-repl', 'mason', 'lazy',
          },
        },
        sections = {
          lualine_a = {
            -- both ends set: giving only one makes lualine drop the other cap
            { 'mode', separator = { left = '\u{e0b6}', right = '\u{e0b4}' }, padding = { left = 1, right = 1 }, fmt = string.lower },
          },
          lualine_b = {
            {
              'filetype',
              icon_only = true,
              padding = { left = 1, right = 0 },
              cond = function() return vim.bo.buftype ~= 'terminal' end,
            },
            {
              'filename',
              path = 1,
              symbols = { modified = ' ' .. icon.modified, readonly = ' ' .. icon.readonly, unnamed = 'untitled', newfile = '' },
              -- terminals: "󰆍 bash" instead of term://…//1234:/bin/bash
              fmt = function(name)
                if vim.bo.buftype ~= 'terminal' then return name end
                local prog = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0):match(':([^:]+)$') or 'shell', ':t')
                return icon.terminal .. (prog:gsub('%.[Ee][Xx][Ee]$', '')) -- Windows: sh, not sh.EXE
              end,
            },
          },
          lualine_c = {
            { 'branch', icon = icon.branch },
            { 'diff', symbols = { added = '+', modified = '~', removed = '-' } },
            { 'diagnostics', symbols = icon },
          },
          lualine_x = {
            { recording, color = 'DiagnosticWarn' },
            build_status,
            lsp_status,
          },
          lualine_y = {},
          lualine_z = {
            { 'location', separator = { left = '\u{e0b6}', right = '\u{e0b4}' }, padding = { left = 1, right = 1 } },
          },
        },
        extensions = { 'lazy', 'man', 'mason', 'quickfix' },
      }
    end,
  },

  { -- tab bar with the open files: plain names, the current one bright, the
    -- others dimmed. No separators or close buttons; hidden with a single file.
    'akinsho/bufferline.nvim',
    version = '*',
    event = 'VeryLazy',
    keys = {
      { '<S-h>', '<cmd>BufferLineCyclePrev<CR>', desc = 'Previous buffer' },
      { '<S-l>', '<cmd>BufferLineCycleNext<CR>', desc = 'Next buffer' },
      { '[B', '<cmd>BufferLineMovePrev<CR>', desc = 'Move buffer left' },
      { ']B', '<cmd>BufferLineMoveNext<CR>', desc = 'Move buffer right' },
      { '<leader>bp', '<cmd>BufferLineTogglePin<CR>', desc = 'Pin / unpin buffer' },
      { '<leader>bP', '<cmd>BufferLineGroupClose ungrouped<CR>', desc = 'Close unpinned buffers' },
      { '<leader>br', '<cmd>BufferLineCloseRight<CR>', desc = 'Close buffers to the right' },
      { '<leader>bl', '<cmd>BufferLineCloseLeft<CR>', desc = 'Close buffers to the left' },
      { '<leader>bj', '<cmd>BufferLinePick<CR>', desc = 'Jump to buffer (by letter)' },
    },
    -- colours: BufferLine* groups in lua/flexoki (bufferline is "themable", so they win)
    opts = function()
      return {
        options = {
          close_command = function(n) Snacks.bufdelete(n) end,
          right_mouse_command = function(n) Snacks.bufdelete(n) end,
          always_show_bufferline = false,
          show_buffer_close_icons = false,
          show_close_icon = false,
          separator_style = { '', '' },
          indicator = { style = 'none' },
          modified_icon = icon.modified,
          diagnostics = false,
          tab_size = 12,
          offsets = { { filetype = 'snacks_layout_box', text = '' } },
        },
      }
    end,
    config = function(_, opts)
      require('bufferline').setup(opts)
      -- redraw after a session restore adds buffers
      vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete' }, {
        group = vim.api.nvim_create_augroup('bufferline_refresh', { clear = true }),
        callback = function()
          vim.schedule(function() pcall(nvim_bufferline) end)
        end,
      })
    end,
  },

  { -- press <Space> (or g, z, [, ], ", …) and wait: a small rounded card in
    -- the corner shows what the next keys do
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      preset = 'helix',
      delay = 300,
      win = { border = 'rounded', padding = { 1, 2 }, title_pos = 'center' },
      icons = { separator = '→', group = '+ ', breadcrumb = '›' },
      spec = {
        { '<leader>b', group = 'buffer' },
        { '<leader>c', group = 'code' },
        { '<leader>d', group = 'debug' },
        { '<leader>f', group = 'find' },
        { '<leader>g', group = 'git' },
        { '<leader>m', group = 'build / run' },
        { '<leader>s', group = 'search & replace' },
        { '<leader>S', group = 'session' },
        { '<leader>t', group = 'test' },
        { '<leader>u', group = 'toggle' },
        { '<leader>x', group = 'problems / lists' },
        { '[', group = 'previous' },
        { ']', group = 'next' },
        { 'g', group = 'goto' },
        { 'z', group = 'fold / view' },
      },
    },
  },

  { -- LSP progress in the corner (e.g. clangd indexing 120/480)
    'j-hui/fidget.nvim',
    event = 'LspAttach',
    opts = { notification = { window = { winblend = 0, border = 'none' } } },
  },

  { -- file-type icons (Nerd Font) for picker, explorer, tab bar, statusline
    'nvim-mini/mini.icons',
    opts = {},
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field (mini.icons' own mock sets it too)
      package.preload['nvim-web-devicons'] = function()
        require('mini.icons').mock_nvim_web_devicons()
        return package.loaded['nvim-web-devicons']
      end
    end,
  },
}
