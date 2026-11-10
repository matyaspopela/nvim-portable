-- ============================================================================
--  Language servers: Neovim's built-in LSP client. Server defaults (command,
--  filetypes, project root) come from nvim-lspconfig's lsp/*.lua files.
--
--    C / C++   clangd        the newest installed LLVM wins (install.sh can add
--                            apt.llvm.org); Mason has no ARM64 clangd
--    CMake     neocmakelsp   Mason (ARM64 build)
--    Lua       lua_ls        Mason; lazydev adds the Neovim API for config editing
--    Python    basedpyright + ruff   (~/.local/bin, installed with uv). The
--                            project's .venv (or $VIRTUAL_ENV) is picked up
--                            automatically: imports and types come from it.
--    Rust      rust_analyzer Mason (only when cargo is installed); clippy on save
--    Markdown  marksman
--    Shell     bashls (+ shellcheck)   JSON / YAML  jsonls / yamlls with the
--    TOML      taplo                   SchemaStore catalogue (package.json,
--                                      pyproject, GitHub workflows, clangd, …)
--  A server is only enabled when its program is installed.
--  <leader>ci (:checkhealth vim.lsp) shows what is running and why.
--
--  clangd needs compile_commands.json to know a project's flags and include
--  paths. CMake projects get it automatically (cmake-tools links it into the
--  project root). Files without one use the fallbackFlags below.
-- ============================================================================
local M = {}

--- Newest LLVM tool: /usr/lib/llvm-NN/bin/<name> with the highest NN, else <name>.
--- (Windows: just <name>; nvim.cmd puts the bundled clangd / clang-format on PATH.)
function M.llvm(name)
  local best, best_version = name, -1
  if vim.g.is_win then return name end
  for _, dir in ipairs(vim.fn.glob('/usr/lib/llvm-*/bin', false, true)) do
    local version = tonumber(dir:match('llvm%-(%d+)/bin$'))
    if version and version > best_version and vim.uv.fs_stat(dir .. '/' .. name) then
      best, best_version = dir .. '/' .. name, version
    end
  end
  return best
end

-- Diagnostics ---------------------------------------------------------------
local sev = vim.diagnostic.severity
-- soft, rounded outline icons (Material Design, in Cascadia Code NF)
M.icons = { [sev.ERROR] = '\u{f015a}', [sev.WARN] = '\u{f05d6}', [sev.INFO] = '\u{f02fd}', [sev.HINT] = '\u{f0336}' }
vim.diagnostic.config({
  severity_sort = true,
  update_in_insert = false, -- don't re-check while typing
  underline = true,
  -- The message shows at the end of the line only while the cursor is on that
  -- line, so the rest of the code stays clean. gl shows the full message.
  virtual_text = { current_line = true, spacing = 3, prefix = '●', source = 'if_many' },
  signs = { text = M.icons },
  float = { source = true, header = '', max_width = 90 },
})

-- Hover / signature popups, tidied: clangd's "### function foo" heading becomes
-- bold text (the ** are concealed, no raw #), its "---" rules become plain
-- blank lines, and runs of blank lines collapse into one.
local open_floating_preview = vim.lsp.util.open_floating_preview
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
  if syntax == 'markdown' and type(contents) == 'table' then
    local tidy, in_code = {}, false
    local function push(line)
      if line == '' and (#tidy == 0 or tidy[#tidy] == '') then return end
      tidy[#tidy + 1] = line
    end
    for _, line in ipairs(contents) do
      if line:match('^%s*```') then in_code = not in_code end
      if in_code or line:match('^%s*```') then
        tidy[#tidy + 1] = line
      elseif line:match('^%s*[-*_][-*_][-*_]+%s*$') then
        push('')
      elseif line:match('^#+%s+%S') then
        push((line:gsub('^#+%s+(.+)$', '**%1**')))
        push('') -- a line right under it must not turn into a heading underline
      else
        push(line)
      end
    end
    while tidy[#tidy] == '' do tidy[#tidy] = nil end
    contents = tidy
  end
  return open_floating_preview(contents, syntax, opts)
end

-- Servers -------------------------------------------------------------------
-- Completion capabilities from blink.cmp (snippets, auto-imports, …). This
-- loads blink now so every server starts with them.
vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })

local cores = vim.uv.available_parallelism()
vim.lsp.config('clangd', {
  cmd = {
    M.llvm('clangd'),
    '--background-index', -- index the whole project (cached in .cache/clangd)
    '--background-index-priority=low', -- indexing never slows typing or builds
    '-j=' .. math.max(2, cores - 2), -- 8 cores: leave 2 for Neovim and the compiler
    '--clang-tidy', -- clang-tidy checks while you type (~/.config/clangd/config.yaml)
    '--header-insertion=iwyu', -- completing a symbol adds its #include
    '--completion-style=detailed',
    '--function-arg-placeholders=1',
    '--all-scopes-completion', -- complete symbols from namespaces not yet used
    '--pch-storage=memory', -- plenty of RAM: keep preambles in memory, faster re-parses
    -- ask the project's real compiler (g++, a cross gcc like aarch64-none-elf-gcc,
    -- clang) for its system headers and target, so libstdc++ / newlib / the
    -- sysroot clangd sees are exactly the ones the build uses
    vim.g.is_win and '--query-driver=**/*.exe'
      or ('--query-driver=/usr/bin/*,/usr/local/bin/*,/usr/lib/llvm-*/bin/*,/opt/**/bin/*,' .. vim.env.HOME .. '/.local/**/bin/*'),
    '--log=error', -- clangd logs every request otherwise; Neovim writes each line to lsp.log
  },
  -- (Windows: clangd reads its user config only from %LOCALAPPDATA%\clangd;
  -- setup-terminal.cmd puts the portable folder's config\clangd\config.yaml there.)
  init_options = {
    -- Windows: files without compile_commands.json are parsed as MinGW g++
    -- would (its libstdc++ headers), not as MSVC (whose headers aren't there)
    fallbackFlags = vim.list_extend(vim.g.is_win and { '--target=x86_64-w64-mingw32' } or {},
      { '-std=c++23', '-Wall', '-Wextra', '-Wpedantic' }),
  },
})

vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      workspace = { checkThirdParty = false },
      completion = { callSnippet = 'Replace' },
      hint = { enable = true, arrayIndex = 'Disable' },
      telemetry = { enable = false },
    },
  },
})

--- The project's Python: <root>/.venv (uv, poetry in-project, python -m venv),
--- <root>/venv, or the activated $VIRTUAL_ENV. nil = basedpyright's default.
function M.python(root)
  for _, dir in ipairs({ root and root .. '/.venv', root and root .. '/venv', vim.env.VIRTUAL_ENV }) do
    local exe = vim.g.is_win and '/Scripts/python.exe' or '/bin/python'
    if dir and vim.uv.fs_stat(dir .. exe) then return dir .. exe end
  end
end

vim.lsp.config('basedpyright', {
  -- point basedpyright at the project's venv before it starts analysing, so
  -- third-party imports resolve without a pyrightconfig.json
  before_init = function(_, config)
    local python = M.python(config.root_dir)
    if python then
      config.settings = config.settings or {}
      config.settings.python = vim.tbl_extend('force', config.settings.python or {}, { pythonPath = python })
    end
  end,
  settings = {
    basedpyright = {
      disableOrganizeImports = true, -- ruff does it
      analysis = {
        typeCheckingMode = 'standard',
        diagnosticMode = 'openFilesOnly',
        autoImportCompletions = true,
      },
    },
  },
})

vim.lsp.config('marksman', {
  root_markers = { '.marksman.toml', '.obsidian', '.git' },
})

vim.lsp.config('rust_analyzer', {
  settings = {
    ['rust-analyzer'] = {
      check = { command = 'clippy' }, -- lints on save
      cargo = { allFeatures = true },
      inlayHints = { closureReturnTypeHints = { enable = 'with_block' } },
    },
  },
})

-- JSON / YAML: schemas for every well-known file (SchemaStore.nvim)
local function schemastore() return package.loaded['schemastore'] or require('schemastore') end
vim.lsp.config('jsonls', {
  before_init = function(_, config)
    config.settings.json = { schemas = schemastore().json.schemas(), validate = { enable = true } }
  end,
  settings = { json = {} },
})
vim.lsp.config('yamlls', {
  before_init = function(_, config)
    config.settings.yaml = {
      schemaStore = { enable = false, url = '' }, -- SchemaStore.nvim provides them instead
      schemas = schemastore().yaml.schemas(),
      keyOrdering = false,
    }
  end,
  settings = { yaml = {}, redhat = { telemetry = { enabled = false } } },
})

M.servers = {
  'clangd', 'neocmake', 'lua_ls', 'basedpyright', 'ruff', 'marksman', 'bashls',
  'rust_analyzer', 'jsonls', 'yamlls', 'taplo',
}

--- Enable every server in M.servers whose program is installed. Safe to call
--- again (e.g. after Mason installed something).
function M.enable_installed()
  for _, name in ipairs(M.servers) do
    local cmd = vim.lsp.config[name] and vim.lsp.config[name].cmd
    if type(cmd) == 'function' or (type(cmd) == 'table' and vim.fn.executable(cmd[1]) == 1) then
      vim.lsp.enable(name)
    end
  end
end
M.enable_installed()

--- Code actions like CLion's Alt+Enter: the fixes for a problem on the cursor's
--- line show up wherever the cursor is on that line. (Neovim on its own only sends
--- the server the problems under the cursor, so on the line but off the
--- underlined part you got "no code actions".) Visual mode: actions for the selection.
local function code_action()
  if vim.api.nvim_get_mode().mode:find('^[vV\22]') then return vim.lsp.buf.code_action() end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local diags = vim.diagnostic.get(0, { lnum = row - 1 })
  local on_problem = vim.iter(diags):any(function(d)
    local last = (d.end_lnum or d.lnum) > d.lnum and math.huge or (d.end_col or d.col)
    return col >= d.col and col <= last
  end)
  if #diags > 0 and not on_problem then
    return vim.lsp.buf.code_action({ range = { start = { row, 0 }, ['end'] = { row, #vim.api.nvim_get_current_line() } } })
  end
  vim.lsp.buf.code_action()
end

-- Keys, once a server attaches to a buffer -----------------------------------
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp_attach', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then return end
    local buf = ev.buf
    local function map(lhs, rhs, desc, mode)
      vim.keymap.set(mode or 'n', lhs, rhs, { buffer = buf, desc = desc, nowait = true })
    end
    local function pick(source) return function() Snacks.picker[source]() end end

    if client.name == 'ruff' then
      client.server_capabilities.hoverProvider = false -- basedpyright's docs are better
    end

    map('gd', pick('lsp_definitions'), 'Go to definition')
    map('<F12>', pick('lsp_definitions'), 'Go to definition')
    map('gD', pick('lsp_declarations'), 'Go to declaration')
    map('gr', pick('lsp_references'), 'References')
    map('<S-F12>', pick('lsp_references'), 'References')
    map('gI', pick('lsp_implementations'), 'Implementations')
    map('gy', pick('lsp_type_definitions'), 'Type definition')
    map('K', function() vim.lsp.buf.hover({ max_width = 90, max_height = 25 }) end, 'Documentation')
    map('gK', function() vim.lsp.buf.signature_help({ max_width = 90 }) end, 'Signature help')
    map('<leader>ca', code_action, 'Code action / quick fix', { 'n', 'x' })
    map('<M-CR>', code_action, 'Quick fix / code action (Alt+Enter, like CLion)', { 'n', 'x' })
    map('<leader>cr', vim.lsp.buf.rename, 'Rename symbol')
    map('<F2>', vim.lsp.buf.rename, 'Rename symbol')
    map('<leader>fs', pick('lsp_symbols'), 'Symbols in file')
    map('<leader>fS', pick('lsp_workspace_symbols'), 'Symbols in project')
    map('<leader>cR', '<cmd>lsp restart<CR>', 'Restart language servers')

    if client:supports_method('textDocument/prepareCallHierarchy') then
      map('<leader>cc', pick('lsp_incoming_calls'), 'Callers (incoming calls)')
      map('<leader>cC', pick('lsp_outgoing_calls'), 'Callees (outgoing calls)')
    end
    if client:supports_method('textDocument/prepareTypeHierarchy') then
      map('<leader>ct', function() vim.lsp.buf.typehierarchy('subtypes') end, 'Derived classes')
      map('<leader>cT', function() vim.lsp.buf.typehierarchy('supertypes') end, 'Base classes')
    end
    if client.name == 'clangd' then
      map('<A-o>', '<cmd>LspClangdSwitchSourceHeader<CR>', 'Switch source / header')
      map('<leader>ch', '<cmd>LspClangdSwitchSourceHeader<CR>', 'Switch source / header')
      map('<leader>cI', '<cmd>LspClangdShowSymbolInfo<CR>', 'Symbol info')
    end
    if client:supports_method('textDocument/inlayHint') then
      vim.lsp.inlay_hint.enable(true, { bufnr = buf }) -- parameter names, deduced types (<leader>uh)
    end
  end,
})

return M
