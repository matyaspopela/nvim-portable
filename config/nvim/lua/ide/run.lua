-- ============================================================================
--  Build / run / debug like an IDE. The project type comes from the folder
--  Neovim was started in (:pwd):
--
--    a Python file    run it in the project's environment: `uv run` when the
--                     project has pyproject.toml / uv.lock, else its .venv,
--                     else python3. F5 debugs it (debugpy, lua/plugins/debug.lua)
--    CMakeLists.txt   cmake-tools: configure, build, run / debug the launch target
--    Cargo.toml       cargo build (errors -> quickfix), cargo run, debug the
--                     built binary with gdb
--    Makefile         make -j<cores>; errors go to the quickfix list
--    anything else    the current C / C++ file on its own (g++ / gcc). The binary
--                     goes to ~/.cache/nvim/ide, never next to your code.
--
--    F5          debug: start / continue        Ctrl+F5      run (no debugger)
--    F7          build                          <leader>mf   build & run this file
--    <leader>mm  single-file profile: debug (sanitizers) ⇄ release (-O2)
--    <leader>mM  this folder: CMake / make ⇄ single file (remembered per folder;
--                e.g. a competitive-programming folder whose CMakeLists.txt
--                isn't meant to build the file you're editing)
--    :Run {args}  run with arguments, e.g.  :Run < input.txt  (remembered)
-- ============================================================================
local M = {}
local uv = vim.uv

M.profile = 'debug'
M.flags = {
  cpp = { '-std=c++23' },
  c = { '-std=c17' },
  common = { '-Wall', '-Wextra', '-Wpedantic', '-Wshadow' },
  -- AddressSanitizer + UBSan catch out-of-bounds, use-after-free, overflow, …
  debug = { '-O0', '-g3', '-fno-omit-frame-pointer', '-fsanitize=address,undefined', '-D_GLIBCXX_ASSERTIONS' },
  release = { '-O2', '-g', '-mcpu=native', '-DNDEBUG' }, -- -mcpu=native: tuned for this Snapdragon
}
if vim.g.is_win then
  -- MinGW g++ has no AddressSanitizer. UBSan in trap mode (no runtime library
  -- needed) stops the program at undefined behaviour, and _GLIBCXX_ASSERTIONS
  -- catches out-of-bounds [] on vectors / strings.
  M.flags.debug = { '-O0', '-g3', '-fno-omit-frame-pointer', '-fsanitize=undefined', '-fsanitize-trap=all', '-D_GLIBCXX_ASSERTIONS' }
  M.flags.release = { '-O2', '-g', '-march=native', '-DNDEBUG' } -- tuned for the PC it is built on
end
local EXE = vim.g.is_win and '.exe' or ''
-- runs "program args" with redirections (< in.txt): bash on Linux, w64devkit's sh on Windows
local SH = vim.g.is_win and 'sh' or 'bash'
M.args = '' -- program arguments for single-file runs (:Run sets them)

local cores = uv.available_parallelism()

-- gcc / clang / ld messages -> quickfix entries (error / warning / note);
-- source excerpts, carets and "In file included from" lines are dropped.
local EFM = table.concat({
  '%f:%l:%c: fatal %trror: %m',
  '%f:%l:%c: %trror: %m',
  '%f:%l:%c: %tarning: %m',
  '%f:%l:%c: %tote: %m',
  '%f:%l: %trror: %m',
  '%f:%l: %tarning: %m',
  '%f:(%*[^)]): %m', -- linker: main.cpp:(.text+0x1c): undefined reference to …
  '%f:%l:%c: %trror%m', -- rustc (cargo --message-format=short): error[E0425]: …
  '%-G%.%#',
}, ',')

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'Build', id = 'ide_build' })
end

local function exists(name) return uv.fs_stat((uv.cwd() or '') .. '/' .. name) ~= nil end

-- What :pwd contains, re-checked at most every 2 s: the statusline asks often,
-- and on /mnt/c every file check crosses the slow 9P bridge.
local probe = { at = -math.huge }
local function project()
  local cwd, now = uv.cwd() or '', uv.now()
  if probe.cwd ~= cwd or now - probe.at > 2000 then
    probe = {
      cwd = cwd, at = now, cmake = exists('CMakeLists.txt'),
      make = exists('Makefile') or exists('makefile') or exists('GNUmakefile'),
      cargo = exists('Cargo.toml'),
    }
  end
  return probe
end
local function has_cmake() return project().cmake end
local function has_make() return project().make end
local function is_cargo() return project().cargo and not project().cmake end
local function is_python() return vim.bo.filetype == 'python' end

-- Folders switched to single-file mode (<leader>mM), remembered across restarts
local mode_file = vim.fn.stdpath('data') .. '/ide-single-file-folders.json'
local single_folders ---@type table<string, boolean>?

local function folders()
  if not single_folders then
    local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(mode_file), '\n')) end)
    single_folders = ok and type(data) == 'table' and data or {}
  end
  return single_folders
end

--- True when :pwd has a CMakeLists.txt / Makefile but was switched to single-file mode.
function M.single_file_mode()
  return (has_cmake() or has_make()) and folders()[uv.cwd() or ''] == true
end

local function is_cmake() return has_cmake() and not M.single_file_mode() end
local function is_make() return has_make() and not has_cmake() and not M.single_file_mode() end

function M.toggle_folder_mode()
  local cwd = uv.cwd() or ''
  if not (has_cmake() or has_make()) then
    notify('No CMakeLists.txt / Makefile in ' .. cwd .. ': F7 / Ctrl+F5 / F5 already work on the current file')
    return
  end
  local f = folders()
  f[cwd] = (not f[cwd]) or nil
  vim.fn.writefile({ vim.json.encode(f) }, mode_file)
  notify(f[cwd] and 'This folder: single file — F7 / Ctrl+F5 / F5 build, run and debug the current file'
    or ('This folder: ' .. (has_cmake() and 'CMake' or 'make') .. ' — F7 / Ctrl+F5 / F5 use the project'))
  vim.cmd.redrawstatus()
end

--- For the statusline: what F7 / Ctrl+F5 / F5 act on here.
--- Returns text and kind ('cmake' | 'make' | 'file'), or nil when there's nothing to say.
function M.status()
  local p = project()
  if is_python() then
    local py = M.python_cmd(vim.api.nvim_buf_get_name(0))
    return py[1] == 'uv' and 'uv run' or ('python · ' .. (py.env or 'system')), 'python'
  elseif is_cargo() and not M.single_file_mode() then
    return 'cargo', 'cargo'
  elseif M.single_file_mode() or (not p.cmake and not p.make and (vim.bo.filetype == 'cpp' or vim.bo.filetype == 'c')) then
    return 'single file · ' .. M.profile, 'file'
  elseif p.cmake then
    local ct = package.loaded['cmake-tools']
    local kind = ct and (ct.get_build_type() or ct.get_configure_preset())
    if not kind then return 'CMake · F7 to configure', 'cmake' end
    local target = ct.get_launch_target()
    return 'CMake · ' .. kind .. ((target and target ~= '') and (' · ' .. target) or ''), 'cmake'
  elseif p.make then
    return 'make', 'make'
  end
end

--- Fill the quickfix list from compiler output; returns the number of entries.
local function set_quickfix(title, output)
  local lines = vim.split(output, '\n', { trimempty = true })
  vim.fn.setqflist({}, ' ', { title = title, lines = lines, efm = EFM })
  return #vim.fn.getqflist()
end

-- Program output: one terminal split at the bottom, replaced on every run.
local run_buf
local function run_in_terminal(cmd, cwd)
  if run_buf and vim.api.nvim_buf_is_valid(run_buf) then
    vim.api.nvim_buf_delete(run_buf, { force = true })
  end
  vim.cmd('botright 12split')
  run_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, run_buf)
  vim.fn.jobstart(cmd, { term = true, cwd = cwd, env = { UBSAN_OPTIONS = 'print_stacktrace=1' } })
  vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = run_buf, desc = 'Close output' })
  vim.cmd.startinsert() -- type the program's input right away
end

-- Single file -------------------------------------------------------------------

local last = {} -- the file built last: F7 / Ctrl+F5 still work from the output window

--- Compile the current C / C++ file (or the last one), then call on_done(exe, src).
function M.compile_file(profile, on_done)
  local buf = vim.api.nvim_get_current_buf()
  local ft, src = vim.bo[buf].filetype, vim.api.nvim_buf_get_name(buf)
  if ft ~= 'c' and ft ~= 'cpp' and last.src and uv.fs_stat(last.src) then
    ft, src = last.ft, last.src
  elseif ft ~= 'c' and ft ~= 'cpp' then
    notify('Not a C / C++ file (and no CMakeLists.txt / Makefile in ' .. uv.cwd() .. ')', vim.log.levels.WARN)
    return
  elseif src == '' then
    notify('Save the file first', vim.log.levels.WARN)
    return
  end
  last.ft, last.src = ft, src
  vim.cmd('silent! wall') -- like an IDE: save everything before building

  local dir = vim.fs.normalize(vim.fn.stdpath('cache')) .. '/ide'
  vim.fn.mkdir(dir, 'p')
  local exe = ('%s/%s-%s-%s%s'):format(dir, vim.fn.fnamemodify(src, ':t:r'), vim.fn.sha256(src):sub(1, 8), profile, EXE)
  local compiler = ft == 'cpp' and 'g++' or 'gcc'
  local cmd = vim.iter({ { compiler }, M.flags[ft], M.flags.common, M.flags[profile], { src, '-o', exe } })
    :flatten():totable()
  if ft == 'c' then table.insert(cmd, '-lm') end

  notify(('Compiling %s (%s)…'):format(vim.fn.fnamemodify(src, ':t'), profile))
  local start = uv.hrtime()
  vim.system(cmd, { cwd = vim.fs.dirname(src), text = true }, vim.schedule_wrap(function(res)
    local problems = set_quickfix(compiler .. ' ' .. vim.fn.fnamemodify(src, ':t'), res.stderr .. res.stdout)
    if res.code ~= 0 then
      notify(('Build failed: %d problem(s), see the quickfix list (]q / [q)'):format(problems), vim.log.levels.ERROR)
      vim.cmd('botright copen')
      return
    end
    local secs = (uv.hrtime() - start) / 1e9
    if problems > 0 then
      notify(('Built in %.1f s with %d warning(s): ]q / [q'):format(secs, problems), vim.log.levels.WARN)
    else
      notify(('Built in %.1f s'):format(secs))
    end
    if on_done then on_done(exe, src) end
  end))
end

function M.run_file()
  M.compile_file(M.profile, function(exe, src)
    local cmd = M.args == '' and { exe } or { SH, '-c', vim.fn.shellescape(exe) .. ' ' .. M.args }
    run_in_terminal(cmd, vim.fs.dirname(src))
  end)
end

function M.debug_file()
  M.compile_file('debug', function(exe, src)
    require('dap').run({
      type = vim.g.is_win and 'codelldb' or 'gdb',
      request = 'launch',
      name = 'Debug ' .. vim.fn.fnamemodify(src, ':t'),
      program = exe,
      args = vim.split(M.args, '%s+', { trimempty = true }), -- gdb starts the program through a shell: "< in.txt" works
      cwd = vim.fs.dirname(src),
      env = { ASAN_OPTIONS = 'detect_leaks=0' }, -- LeakSanitizer can't run under a debugger
      stopAtBeginningOfMainSubprogram = false,
    })
  end)
end

function M.toggle_profile()
  M.profile = M.profile == 'debug' and 'release' or 'debug'
  vim.notify('Single-file profile: ' .. M.profile .. '\n' .. table.concat(M.flags[M.profile], ' '),
    vim.log.levels.INFO, { title = 'Build' })
  vim.cmd.redrawstatus()
end

-- Makefile projects ---------------------------------------------------------

local function make(on_done)
  vim.cmd('silent! wall')
  notify(('make -j%d…'):format(cores))
  local start = uv.hrtime()
  vim.system({ 'make', '-j' .. cores }, { cwd = uv.cwd(), text = true }, vim.schedule_wrap(function(res)
    local problems = set_quickfix('make', res.stderr .. res.stdout)
    if res.code ~= 0 then
      notify(('make failed: %d problem(s), see the quickfix list'):format(problems), vim.log.levels.ERROR)
      vim.cmd('botright copen')
      return
    end
    notify(('make finished in %.1f s%s'):format((uv.hrtime() - start) / 1e9,
      problems > 0 and (', %d warning(s)'):format(problems) or ''), problems > 0 and vim.log.levels.WARN or nil)
    if on_done then on_done() end
  end))
end

local make_program = {} -- cwd -> program to run / debug after make

local function ask_program(then_do)
  local cwd = uv.cwd() or '.'
  if make_program[cwd] then return then_do(make_program[cwd]) end
  vim.ui.input({ prompt = 'Program to run (after make): ', default = './', completion = 'file' }, function(path)
    if not path or path == '' or path == './' then return end
    make_program[cwd] = path
    then_do(path)
  end)
end

-- Python ------------------------------------------------------------------------

local py_cache = {} -- file's folder -> command (statusline asks often)

--- How to run a Python file: { 'uv', 'run', … } inside a uv / pyproject
--- project, else the project's venv python, else python3. `.env` names the venv.
function M.python_cmd(file)
  local dir = vim.fs.dirname(file ~= '' and file or (uv.cwd() .. '/x'))
  if py_cache[dir] then return py_cache[dir] end
  local root = vim.fs.root(dir, { 'uv.lock', 'pyproject.toml', '.venv', 'venv', 'setup.py', '.git' })
  local cmd
  if root and vim.fn.executable('uv') == 1 and (uv.fs_stat(root .. '/uv.lock') or uv.fs_stat(root .. '/pyproject.toml')) then
    cmd = { 'uv', 'run', '--project', root, 'python' }
  else
    local py = require('config.lsp').python(root)
    cmd = { py or vim.g.python_exe, env = py and vim.fn.fnamemodify(py, ':h:h:t') or nil }
  end
  cmd.root = root
  py_cache[dir] = cmd
  return cmd
end

local function run_python()
  local src = vim.api.nvim_buf_get_name(0)
  if src == '' then return notify('Save the file first', vim.log.levels.WARN) end
  vim.cmd('silent! wall')
  local cmd = vim.list_slice(M.python_cmd(src))
  cmd[#cmd + 1] = src
  vim.list_extend(cmd, vim.split(M.args, '%s+', { trimempty = true }))
  run_in_terminal(cmd, M.python_cmd(src).root or vim.fs.dirname(src))
end

-- Cargo -------------------------------------------------------------------------

local function cargo_build(on_done)
  vim.cmd('silent! wall')
  notify('cargo build…')
  local start = uv.hrtime()
  -- json lines on stdout (to find the binary), readable short diagnostics on stderr
  vim.system({ 'cargo', 'build', '--message-format=json-diagnostic-short' }, { cwd = uv.cwd(), text = true },
    vim.schedule_wrap(function(res)
      local text, exe = {}, nil
      for line in (res.stdout or ''):gmatch('[^\n]+') do
        local ok, msg = pcall(vim.json.decode, line)
        if ok and type(msg) == 'table' then
          if msg.reason == 'compiler-message' and msg.message and msg.message.rendered then
            text[#text + 1] = msg.message.rendered
          elseif msg.reason == 'compiler-artifact' and type(msg.executable) == 'string'
            and vim.tbl_contains(msg.target and msg.target.kind or {}, 'bin') then
            exe = exe or msg.executable
          end
        end
      end
      local problems = set_quickfix('cargo build', table.concat(text, '\n') .. '\n' .. (res.stderr or ''))
      if res.code ~= 0 then
        notify(('cargo build failed: %d problem(s), see the quickfix list'):format(problems), vim.log.levels.ERROR)
        vim.cmd('botright copen')
        return
      end
      notify(('cargo build finished in %.1f s%s'):format((uv.hrtime() - start) / 1e9,
        problems > 0 and (', %d warning(s): ]q / [q'):format(problems) or ''), problems > 0 and vim.log.levels.WARN or nil)
      if on_done then on_done(exe) end
    end))
end

-- What F7 / Ctrl+F5 / F5 do -----------------------------------------------------

function M.build()
  if is_python() then
    notify('Python: nothing to build. Ctrl+F5 runs this file, F5 debugs it')
  elseif is_cmake() then
    vim.cmd('CMakeBuild')
  elseif is_cargo() then
    cargo_build()
  elseif is_make() then
    make()
  else
    M.compile_file(M.profile)
  end
end

function M.run()
  if is_python() then
    run_python()
  elseif is_cmake() then
    vim.cmd('CMakeRun')
  elseif is_cargo() then
    vim.cmd('silent! wall')
    local cmd = { 'cargo', 'run' }
    if M.args ~= '' then vim.list_extend(cmd, { '--' }); vim.list_extend(cmd, vim.split(M.args, '%s+', { trimempty = true })) end
    run_in_terminal(cmd, uv.cwd())
  elseif is_make() then
    ask_program(function(prog) make(function() run_in_terminal({ SH, '-c', prog }, uv.cwd()) end) end)
  else
    M.run_file()
  end
end

function M.debug()
  local dap = require('dap')
  if dap.session() then
    dap.continue()
  elseif is_python() then
    dap.continue() -- debugpy: this file / pick a configuration (lua/plugins/debug.lua)
  elseif is_cmake() then
    vim.cmd('CMakeDebug')
  elseif is_cargo() then
    cargo_build(function(exe)
      if not exe then return notify('cargo built no binary to debug', vim.log.levels.WARN) end
      dap.run({
        type = vim.g.is_win and 'codelldb' or 'gdb', request = 'launch', name = 'Debug ' .. vim.fs.basename(exe), program = exe,
        args = vim.split(M.args, '%s+', { trimempty = true }), cwd = uv.cwd(), stopAtBeginningOfMainSubprogram = false,
      })
    end)
  elseif is_make() then
    ask_program(function(prog)
      local parts = vim.split(prog, '%s+', { trimempty = true }) -- "./app --flag" -> program + args
      make(function()
        dap.run({
          type = vim.g.is_win and 'codelldb' or 'gdb', request = 'launch', name = 'Debug ' .. parts[1],
          program = vim.fs.abspath(parts[1]), args = vim.list_slice(parts, 2),
          cwd = uv.cwd(), stopAtBeginningOfMainSubprogram = false,
        })
      end)
    end)
  elseif vim.bo.filetype == 'c' or vim.bo.filetype == 'cpp' then
    M.debug_file()
  else
    dap.continue() -- other languages: pick one of their debug configurations
  end
end

return M
