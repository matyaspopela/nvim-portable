-- Language-server plumbing. The servers themselves are set up in lua/config/lsp.lua.
-- Mason package -> the program it installs. All have native ARM64 Linux builds
-- or run on Node (installed).
local ensure_installed = {
  ['lua-language-server'] = 'lua-language-server',
  neocmakelsp = 'neocmakelsp',
  stylua = 'stylua', -- Lua formatter (<leader>cf in this config)
  ['bash-language-server'] = 'bash-language-server',
  shellcheck = 'shellcheck', -- bashls shows its warnings
  ['json-lsp'] = 'vscode-json-language-server',
  ['yaml-language-server'] = 'yaml-language-server',
  taplo = 'taplo', -- TOML: Cargo.toml, pyproject.toml
}
if vim.fn.executable('cargo') == 1 then ensure_installed['rust-analyzer'] = 'rust-analyzer' end
-- Portable Windows edition: clangd, clang-format, rg, fd come bundled; nothing
-- is downloaded behind your back (:Mason installs more when you want them).
if vim.g.is_win then ensure_installed = {} end

return {
  -- Server definitions (command, filetypes, root markers) for vim.lsp.config
  { 'neovim/nvim-lspconfig', lazy = false },

  -- JSON / YAML schemas for jsonls / yamlls (lua/config/lsp.lua)
  { 'b0o/SchemaStore.nvim', version = false },

  { -- :Mason installs language servers / tools into ~/.local/share/nvim/mason.
    -- Not used for clangd: upstream ships no ARM64 Linux build (install.sh
    -- gets a current one from apt.llvm.org instead).
    'mason-org/mason.nvim',
    cmd = { 'Mason', 'MasonInstall', 'MasonUpdate', 'MasonUninstall', 'MasonLog' },
    opts = { PATH = 'skip', ui = { border = 'rounded' } }, -- lua/config/options.lua puts mason/bin on PATH
    init = function()
      -- First start on a new machine: install what's missing in the background.
      vim.api.nvim_create_autocmd('User', {
        pattern = 'VeryLazy',
        once = true,
        callback = function()
          local bin = vim.fn.stdpath('data') .. '/mason/bin/'
          local missing = {}
          for pkg, exe in pairs(ensure_installed) do
            if not vim.uv.fs_stat(bin .. exe) then missing[#missing + 1] = pkg end
          end
          if #missing == 0 then return end
          require('lazy').load({ plugins = { 'mason.nvim' } })
          local registry = require('mason-registry')
          registry.refresh(function()
            for _, name in ipairs(missing) do
              local ok, pkg = pcall(registry.get_package, name)
              if ok and not pkg:is_installed() and not pkg:is_installing() then
                vim.notify('Mason: installing ' .. name .. '…', vim.log.levels.INFO, { title = 'Mason' })
                pkg:install({}, function(success)
                  vim.schedule(function()
                    if success then
                      vim.notify('Mason: installed ' .. name, vim.log.levels.INFO, { title = 'Mason' })
                      require('config.lsp').enable_installed()
                    else
                      vim.notify('Mason: failed to install ' .. name .. ' (:MasonLog)', vim.log.levels.ERROR, { title = 'Mason' })
                    end
                  end)
                end)
              end
            end
          end)
        end,
      })
    end,
  },
}
