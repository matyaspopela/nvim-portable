-- lazy.nvim: plugin manager. Installs itself and every plugin on first start.
--   :Lazy            status window (U update, S sync, X clean, P profile)
--   lazy-lock.json   pins the exact plugin versions; commit it with your dotfiles
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' }, { out, 'WarningMsg' } }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  spec = { { import = 'plugins' } },
  defaults = { lazy = true }, -- plugins load when first needed (event / key / command)
  install = { colorscheme = { 'flexoki' } },
  checker = { enabled = false }, -- update when *you* decide: :Lazy update
  change_detection = { notify = false },
  rocks = { enabled = false },
  ui = { border = 'rounded', backdrop = 100 },
  performance = {
    rtp = {
      disabled_plugins = { 'gzip', 'netrwPlugin', 'rplugin', 'tarPlugin', 'tohtml', 'tutor', 'zipPlugin' },
    },
  },
})
