-- ============================================================================
--  Debugger (nvim-dap + dap-ui). F5 starts it the IDE way (lua/ide/run.lua):
--  the CMake launch target, the make program, or the current file.
--
--  F5 start / continue   Shift+F5 stop   F9 breakpoint   F10 step over
--  F11 step into         Shift+F11 step out               (more under <leader>d)
--
--  gdb is the adapter: Ubuntu's gdb 15 speaks the debug protocol natively and
--  with GCC its pretty-printers show std::vector / map / string readably.
--  lldb-dap is added too when LLVM's lldb is installed (install.sh).
-- ============================================================================
local function dap() return require('dap') end

--- `a b 'c d' "e f"` -> { 'a', 'b', 'c d', 'e f' }
local function split_args(s)
  local args, i = {}, 1
  while true do
    i = s:find('%S', i)
    if not i then return args end
    local quote = s:sub(i, i)
    if quote == '"' or quote == "'" then
      local close = s:find(quote, i + 1, true) or #s + 1
      args[#args + 1] = s:sub(i + 1, close - 1)
      i = close + 1
    else
      local stop = s:find('%s', i) or #s + 1
      args[#args + 1] = s:sub(i, stop - 1)
      i = stop
    end
  end
end

--- Panels: variables / watches / call stack / breakpoints on the left, program
--- output and debugger console at the bottom. They open and close with the
--- session. (dap-ui fills in every option not given here.)
local function setup_dapui()
  local d, dapui = require('dap'), require('dapui')
  ---@diagnostic disable-next-line: missing-fields
  dapui.setup({
    controls = { enabled = true, element = 'console' }, ---@diagnostic disable-line: missing-fields
    layouts = {
      {
        position = 'left',
        size = 45,
        elements = {
          { id = 'scopes', size = 0.45 },
          { id = 'watches', size = 0.2 },
          { id = 'stacks', size = 0.2 },
          { id = 'breakpoints', size = 0.15 },
        },
      },
      { position = 'bottom', size = 12, elements = { { id = 'console', size = 0.5 }, { id = 'repl', size = 0.5 } } },
    },
    floating = { border = 'rounded' }, ---@diagnostic disable-line: missing-fields
  })
  d.listeners.after.event_initialized.dapui = function() dapui.open() end
  d.listeners.before.event_terminated.dapui = function() dapui.close() end
  d.listeners.before.event_exited.dapui = function() dapui.close() end
end

local M = {
  'mfussenegger/nvim-dap',
  dependencies = {
    { 'rcarriga/nvim-dap-ui', dependencies = { 'nvim-neotest/nvim-nio' }, config = setup_dapui },
    { 'theHamsta/nvim-dap-virtual-text', opts = { virt_text_pos = 'eol' } }, -- values next to the code
  },
  keys = {
    { '<F9>', function() dap().toggle_breakpoint() end, desc = 'Toggle breakpoint' },
    { '<F10>', function() dap().step_over() end, desc = 'Step over' },
    { '<F11>', function() dap().step_into() end, desc = 'Step into' },
    { '<S-F11>', function() dap().step_out() end, desc = 'Step out' },
    { '<F23>', function() dap().step_out() end, desc = 'which_key_ignore' }, -- Shift+F11 in some terminals
    { '<S-F5>', function() dap().terminate() end, desc = 'Stop debugging' },
    { '<F17>', function() dap().terminate() end, desc = 'which_key_ignore' }, -- Shift+F5 in some terminals
    { '<leader>dc', function() require('ide.run').debug() end, desc = 'Start / continue' },
    { '<leader>db', function() dap().toggle_breakpoint() end, desc = 'Toggle breakpoint' },
    { '<leader>dB', function() dap().set_breakpoint(vim.fn.input('Break when: ')) end, desc = 'Conditional breakpoint' },
    { '<leader>dl', function() dap().set_breakpoint(nil, nil, vim.fn.input('Log message ({expr} works): ')) end, desc = 'Log point' },
    { '<leader>dL', function() dap().list_breakpoints(true) end, desc = 'List breakpoints' },
    { '<leader>dx', function() dap().clear_breakpoints() end, desc = 'Clear all breakpoints' },
    { '<leader>dC', function() dap().run_to_cursor() end, desc = 'Run to cursor' },
    { '<leader>dO', function() dap().step_over() end, desc = 'Step over' },
    { '<leader>di', function() dap().step_into() end, desc = 'Step into' },
    { '<leader>do', function() dap().step_out() end, desc = 'Step out' },
    { '<leader>dk', function() dap().up() end, desc = 'Up the call stack' },
    { '<leader>dj', function() dap().down() end, desc = 'Down the call stack' },
    { '<leader>dp', function() dap().pause() end, desc = 'Pause' },
    { '<leader>dR', function() dap().run_last() end, desc = 'Run last configuration again' },
    { '<leader>dr', function() dap().repl.toggle() end, desc = 'Debugger console (REPL)' },
    { '<leader>dt', function() dap().terminate() end, desc = 'Stop debugging' },
    { '<leader>du', function() require('dapui').toggle() end, desc = 'Toggle debugger panels' },
    { '<leader>de', function() require('dapui').eval() end, desc = 'Evaluate expression', mode = { 'n', 'x' } },
    { '<leader>dw', function() require('dapui').elements.watches.add(vim.fn.expand('<cexpr>')) end, desc = 'Watch expression under cursor' },
  },
  config = function()
    local d = require('dap')

    -- Signs: Dap* groups from lua/flexoki. Red breakpoint, yellow conditional,
    -- blue log point, the stopped line washed in yellow.
    vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DapBreakpoint' })
    vim.fn.sign_define('DapBreakpointCondition', { text = '◐', texthl = 'DapBreakpointCondition' })
    vim.fn.sign_define('DapLogPoint', { text = '◆', texthl = 'DapLogPoint' })
    vim.fn.sign_define('DapBreakpointRejected', { text = '○', texthl = 'DapBreakpointRejected' })
    vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DapStopped', linehl = 'DapStoppedLine', numhl = 'DapStopped' })

    -- Adapters ---------------------------------------------------------------
    -- An empty Lua table goes out as a JSON array ([]), but debug adapters
    -- want `env` to be an object (gdb refuses to launch). cmake-tools sends
    -- env = {} when the target has no environment set, so drop it.
    local function drop_empty_env(config, on_config)
      if type(config.env) == 'table' and next(config.env) == nil then
        config = vim.deepcopy(config)
        config.env = nil
      end
      on_config(config)
    end

    -- gdb 15 (Ubuntu 24.04; fixed in gdb 16) has two quirks:
    --  * `launch` starts the program at once, before Neovim has sent the
    --    breakpoints, so a breakpoint early in the program is missed. So gdb
    --    stops at main first, Neovim configures breakpoints while it waits
    --    there, and the program continues. That stop is never shown, unless
    --    one of your breakpoints is on that very line.
    --  * `env` replaces the program's whole environment (PATH, HOME, …) instead
    --    of adding to it, so the additions are merged into the full environment.
    local function gdb_enrich(config, on_config)
      drop_empty_env(config, function(c)
        c = vim.deepcopy(c)
        if type(c.env) == 'table' then c.env = vim.tbl_extend('force', vim.fn.environ(), c.env) end
        if c.request == 'launch' and not c.stopAtBeginningOfMainSubprogram then
          c.stopAtBeginningOfMainSubprogram = true
          c.holdAtMain = true -- unknown launch fields are ignored by gdb
        end
        on_config(c)
      end)
    end

    -- Messages from gdb pass through this filter until the program has
    -- stopped at main: gdb's early `initialized` event (it makes Neovim send
    -- the breakpoints) is held back until then.
    local holds = setmetatable({}, { __mode = 'k' }) -- session -> hold state (forgotten with the session)
    d.listeners.on_session['ide.gdb_hold'] = function(_, s)
      if not (s and s.config and s.config.holdAtMain) or holds[s] then return end
      local handle_body = s.handle_body
      local hold = { deliver = function(body) handle_body(s, body) end }
      holds[s] = hold
      local function release_initialized()
        hold.done = true
        if hold.initialized then
          local body = hold.initialized
          hold.initialized = nil
          hold.deliver(body)
        end
      end
      hold.release_initialized = release_initialized
      s.handle_body = function(self, body)
        if hold.done then return handle_body(self, body) end
        local ok, msg = pcall(vim.json.decode, body)
        if ok and type(msg) == 'table' and msg.type == 'event' then
          if msg.event == 'initialized' then
            hold.initialized = body
            return
          elseif msg.event == 'stopped' and msg.body and msg.body.reason == 'breakpoint' then
            hold.stopped, hold.thread = body, msg.body.threadId -- parked at main
            return release_initialized() -- now Neovim sets breakpoints, then configurationDone
          elseif msg.event == 'stopped' or msg.event == 'exited' or msg.event == 'terminated' then
            release_initialized() -- crashed / ended before main: show it as it is
          end
        end
        return handle_body(self, body)
      end
    end
    -- A program without a `main` symbol never parks: don't hold back forever.
    d.listeners.after.launch['ide.gdb_hold'] = function(s)
      local hold = holds[s]
      if hold and not hold.done then
        vim.defer_fn(function() if not hold.done then hold.release_initialized() end end, 2000)
      end
    end
    -- Breakpoints are in place: continue from main, or show the stop if one
    -- of your breakpoints is on main's first line.
    d.listeners.after.configurationDone['ide.gdb_hold'] = function(s)
      local hold = holds[s]
      if not (hold and hold.stopped) then return end
      local body, thread = hold.stopped, hold.thread
      hold.stopped = nil
      s:request('stackTrace', { threadId = thread, startFrame = 0, levels = 1 }, function(_, res)
        local frame = res and res.stackFrames and res.stackFrames[1]
        local path = frame and frame.source and frame.source.path
        local buf = path and vim.fn.bufnr(path) or -1
        for _, bp in ipairs(buf > 0 and (require('dap.breakpoints').get(buf)[buf] or {}) or {}) do
          if bp.line == frame.line then return hold.deliver(body) end
        end
        s:request('continue', { threadId = thread }, function() end)
      end)
    end

    d.adapters.gdb = {
      type = 'executable',
      command = 'gdb',
      args = { '--interpreter=dap', '--eval-command', 'set print pretty on' },
      enrich_config = gdb_enrich,
    }
    local lldb_dap = require('config.lsp').llvm('lldb-dap')
    if vim.fn.executable(lldb_dap) == 1 then
      d.adapters.lldb = { type = 'executable', command = lldb_dap, name = 'lldb', enrich_config = drop_empty_env }
    end

    -- Configurations (F5 in a C/C++ file without a project, or <leader>dc then
    -- "pick": launch any executable, attach to a process or a gdbserver)
    local function program()
      local build = vim.uv.cwd() .. '/build'
      return require('dap.utils').pick_file({ executables = true, path = vim.uv.fs_stat(build) and build or nil })
    end
    local function args() return split_args(vim.fn.input('Arguments: ')) end
    if vim.g.is_win then
      -- Windows: codelldb (bundled in the portable folder). w64devkit's gdb is
      -- built without Python, so it can't speak the debug protocol. Every
      -- launch that asks for 'gdb' (F5 on a file, CMake, make) goes to codelldb.
      local codelldb = (vim.g.portable_root and vim.g.portable_root .. '/codelldb'
        or vim.fn.stdpath('data') .. '/mason/packages/codelldb/extension') .. '/adapter/codelldb.exe'
      d.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = { command = codelldb, args = { '--port', '${port}' }, detached = false },
        enrich_config = function(config, on_config)
          drop_empty_env(config, function(c)
            -- the program runs in a terminal split: cin / scanf input works
            if c.request == 'launch' and c.terminal == nil then
              c = vim.deepcopy(c)
              c.terminal = 'integrated'
            end
            on_config(c)
          end)
        end,
      }
      d.adapters.gdb = d.adapters.codelldb
      local cpp = {
        {
          name = 'Launch an executable', type = 'codelldb', request = 'launch',
          program = program, args = args, cwd = '${workspaceFolder}',
        },
        {
          name = 'Attach to a running process', type = 'codelldb', request = 'attach',
          pid = function() return require('dap.utils').pick_process() end,
        },
      }
      d.configurations.cpp = cpp
      d.configurations.c = cpp
      d.configurations.rust = cpp
      return
    end
    local cpp = {
      {
        name = 'gdb: launch an executable', type = 'gdb', request = 'launch',
        program = program, args = args, cwd = '${workspaceFolder}', stopAtBeginningOfMainSubprogram = false,
      },
      {
        name = 'gdb: attach to a running process', type = 'gdb', request = 'attach',
        pid = function() return require('dap.utils').pick_process() end, cwd = '${workspaceFolder}',
      },
      {
        name = 'gdb: attach to gdbserver (localhost:1234)', type = 'gdb', request = 'attach',
        target = 'localhost:1234', program = program, cwd = '${workspaceFolder}',
      },
    }
    if d.adapters.lldb then
      cpp[#cpp + 1] = {
        name = 'lldb: launch an executable (own terminal: interactive input)', type = 'lldb', request = 'launch',
        program = program, args = args, cwd = '${workspaceFolder}', runInTerminal = true,
      }
    end
    d.configurations.cpp = cpp
    d.configurations.c = cpp
    d.configurations.rust = cpp -- gdb understands Rust; F5 in a Cargo project builds first (lua/ide/run.lua)
    -- Python: nvim-dap-python below
  end,
}

local debugpy_python = vim.fn.expand('~/.local/share/uv/tools/debugpy/bin/python')

return {
  M,
  { -- Python debugging (debugpy). The adapter lives in its own uv tool
    -- environment (`uv tool install debugpy`, install.sh), the program runs in
    -- the project's .venv / $VIRTUAL_ENV, so nothing is installed into projects.
    -- F5 in a .py file: "file" = this file; also "file:args", attach, …
    -- Tests: <leader>t… (neotest, lua/plugins/test.lua) debug a test with td.
    'mfussenegger/nvim-dap-python',
    ft = 'python',
    dependencies = { 'mfussenegger/nvim-dap' },
    keys = {
      { '<leader>ds', function() require('dap-python').debug_selection() end, mode = 'x', ft = 'python', desc = 'Debug selected Python code' },
    },
    config = function()
      local dap_python = require('dap-python')
      if vim.g.is_win then
        dap_python.setup(vim.g.python_exe) -- debugpy: pip install debugpy
      elseif vim.fn.executable(debugpy_python) == 1 then
        dap_python.setup(debugpy_python)
      else
        dap_python.setup(vim.g.python_exe)
        vim.notify('debugpy not found: run  uv tool install debugpy', vim.log.levels.WARN, { title = 'Python debugger' })
      end
      dap_python.test_runner = 'pytest'
      ---@diagnostic disable-next-line: duplicate-set-field
      dap_python.resolve_python = function()
        local root = vim.fs.root(0, { 'pyproject.toml', 'uv.lock', '.venv', 'venv', 'setup.py', '.git' })
        return require('config.lsp').python(root) or vim.g.python_exe
      end
    end,
  },
}
