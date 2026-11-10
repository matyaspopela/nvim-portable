-- ============================================================================
--  Look at what the compiler made of your code — locally, Compiler-Explorer
--  style. Uses the file's real flags from compile_commands.json (CMake
--  projects) or the single-file release flags (lua/ide/run.lua).
--
--  <leader>mA  :Asm [flags]   assembly of this file in a split on the right.
--              Lines produced by the source line under the cursor are
--              highlighted (and the other way round); <CR> in the assembly
--              jumps to the source. Saving the file recompiles it.
--              Extra flags win:  :Asm -O3 -march=native   :Asm -O0
--  <leader>mv  :OptRemarks [flags]   what the optimiser did: loops vectorised
--              (info), not vectorised + why (warning), inlining decisions —
--              shown inline as diagnostics, listed in <leader>xX.
--              Run again to refresh; <leader>mV clears them.
-- ============================================================================
local M = {}
local uv = vim.uv

local ns_match = vim.api.nvim_create_namespace('ide_asm_match')
local ns_label = vim.api.nvim_create_namespace('ide_asm_label')
local ns_remarks = vim.api.nvim_create_namespace('ide_opt_remarks')

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = 'Compiler', id = 'ide_asm' }) end

--- Split a shell command line ("g++ -DX=\"a b\" -c f.cpp") into arguments.
local function shell_split(s)
  local args, cur, i, quote, has = {}, {}, 1, nil, false
  while i <= #s do
    local ch = s:sub(i, i)
    if quote then
      if ch == quote then quote = nil
      elseif ch == '\\' and quote == '"' and i < #s then i = i + 1; cur[#cur + 1] = s:sub(i, i)
      else cur[#cur + 1] = ch end
    elseif ch == '"' or ch == "'" then quote, has = ch, true
    elseif ch == '\\' and i < #s then i = i + 1; cur[#cur + 1] = s:sub(i, i); has = true
    elseif ch:match('%s') then
      if #cur > 0 or has then args[#args + 1] = table.concat(cur) end
      cur, has = {}, false
    else cur[#cur + 1] = ch; has = true end
    i = i + 1
  end
  if #cur > 0 or has then args[#args + 1] = table.concat(cur) end
  return args
end

local function realpath(p) return uv.fs_realpath(p) or vim.fs.normalize(p) end

--- The compiler invocation for `src`: (args without output / dependency
--- flags, working directory, where the flags came from).
local function invocation(src, ft)
  local db = vim.fs.find('compile_commands.json', { upward = true, path = vim.fs.dirname(src) })[1]
  if db then
    local ok, entries = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(db), '\n')) end)
    local want = realpath(src)
    for _, e in ipairs(ok and entries or {}) do
      local file = e.file:sub(1, 1) == '/' and e.file or (e.directory .. '/' .. e.file)
      if realpath(file) == want then
        local raw = e.arguments or shell_split(e.command)
        local args, skip = {}, false
        for idx, a in ipairs(raw) do
          if skip then
            skip = false
          elseif idx == 1 and vim.fs.basename(a):match('ccache') then -- compiler launcher
          elseif a == '-o' or a == '-MF' or a == '-MT' or a == '-MQ' then
            skip = true
          elseif not (a == '-c' or a == '-MD' or a == '-MMD' or a:match('^%-o.') or a:match('^%-MF.')) then
            args[#args + 1] = a
          end
        end
        return args, e.directory, vim.fn.fnamemodify(db, ':~:.')
      end
    end
  end
  -- no compile database entry (single file, or a header): the single-file release flags
  local run = require('ide.run')
  local args = vim.iter({ { ft == 'c' and 'gcc' or 'g++' }, run.flags[ft], run.flags.common, run.flags.release, { src } })
    :flatten():totable()
  return args, vim.fs.dirname(src), 'single-file release flags'
end

local function opt_level(args)
  local level
  for _, a in ipairs(args) do
    if a:match('^%-O') then level = a end
  end
  return level
end

local function source_file()
  local buf = vim.api.nvim_get_current_buf()
  local ft, src = vim.bo[buf].filetype, vim.api.nvim_buf_get_name(buf)
  if not vim.tbl_contains({ 'c', 'cpp', 'cuda' }, ft) or src == '' then
    notify('Open a saved C / C++ file first', vim.log.levels.WARN)
    return
  end
  if vim.bo[buf].modified then vim.cmd('silent write') end
  return buf, src, ft == 'c' and 'c' or 'cpp'
end

-- Assembly ---------------------------------------------------------------------

local KEEP_DATA = {
  string = true, ascii = true, asciz = true, byte = true, short = true, hword = true, word = true,
  long = true, int = true, quad = true, xword = true, dword = true, zero = true, float = true, double = true,
}

--- Compiler output -> readable listing. Returns lines, asm line -> source
--- line, source line -> { asm lines }.
local function filter(asm, src, cwd)
  local raw = vim.split(asm, '\n', { plain = true })
  local want = realpath(src)
  local main_files = {} -- .file numbers that are `src`
  local referenced = {} -- .L labels some instruction uses

  local function is_main(dir, name)
    local path = name:sub(1, 1) == '/' and name or ((dir ~= '' and dir or cwd) .. '/' .. name)
    return realpath(path) == want
  end
  for _, line in ipairs(raw) do
    -- gcc:  .file 1 "main.cpp"     clang (DWARF 5):  .file 1 "/dir" "main.cpp" md5 0x…
    local n, a, b = line:match('^%s*%.file%s+(%d+)%s+"([^"]*)"%s*"?([^"]*)"?')
    if n then
      local dir, name = b ~= '' and a or '', b ~= '' and b or a
      if is_main(dir, name) then main_files[n] = true end
    elseif not line:match('^%s*%.') and not line:match('^[%w_.$]+:') then
      for label in line:gmatch('%.L[%w_$.]+') do referenced[label] = true end
    elseif KEEP_DATA[line:match('^%s*%.([%w_]+)') or ''] then
      for label in line:gmatch('%.L[%w_$.]+') do referenced[label] = true end -- jump tables, .word .LBB0_3-…
    end
  end

  local out, to_src, from_src = {}, {}, {}
  local skipping, cur_line = false, nil
  for _, line in ipairs(raw) do
    local directive = line:match('^%s*%.([%w_]+)')
    local label = line:match('^([%w_.$]+):')
    if directive == 'section' then
      local name = line:match('^%s*%.section%s+([^%s,]+)') or ''
      skipping = not (name:match('^%.text') or name:match('^%.rodata') or name:match('^%.data') or name:match('^%.bss'))
    elseif directive == 'text' or directive == 'data' or directive == 'bss' then
      skipping = false
    elseif skipping then -- debug info, notes, …
    elseif directive == 'loc' then
      local n, l = line:match('^%s*%.loc%s+(%d+)%s+(%d+)')
      cur_line = (n and main_files[n] and tonumber(l) > 0) and tonumber(l) or nil
    elseif label then
      if not label:match('^%.L') or referenced[label] then
        out[#out + 1] = line
        cur_line = nil
      end
    elseif directive then
      if KEEP_DATA[directive] then out[#out + 1] = line end
    elseif line:match('%S') and not line:match('^%s*[#@;/]') then -- an instruction
      out[#out + 1] = (line:gsub('^%s+', '  ', 1))
      if cur_line then
        to_src[#out] = cur_line
        from_src[cur_line] = from_src[cur_line] or {}
        table.insert(from_src[cur_line], #out)
      end
    end
  end
  return out, to_src, from_src
end

local view = {} -- the open assembly view: src_buf, buf, win, to_src, from_src, extra

local function view_open()
  return view.buf and vim.api.nvim_buf_is_valid(view.buf) and view.win and vim.api.nvim_win_is_valid(view.win)
end

--- Highlight the assembly of the source line under the cursor (and keep it in view).
local function sync_from_source()
  if not view_open() then return end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_clear_namespace(view.buf, ns_match, 0, -1)
  local lines = view.from_src[line] or {}
  for _, l in ipairs(lines) do
    vim.api.nvim_buf_set_extmark(view.buf, ns_match, l - 1, 0, { line_hl_group = 'IdeAsmMatch', priority = 200 })
  end
  if lines[1] then
    vim.api.nvim_win_call(view.win, function()
      local top, bot = vim.fn.line('w0'), vim.fn.line('w$')
      if lines[1] < top or lines[1] > bot then
        vim.api.nvim_win_set_cursor(view.win, { lines[1], 0 })
        vim.cmd('normal! zz')
      end
    end)
  end
end

--- From the assembly: highlight the source line it came from.
local function sync_from_asm()
  if not (view.src_buf and vim.api.nvim_buf_is_valid(view.src_buf)) then return end
  vim.api.nvim_buf_clear_namespace(view.src_buf, ns_match, 0, -1)
  local src_line = view.to_src[vim.api.nvim_win_get_cursor(0)[1]]
  if not src_line then return end
  vim.api.nvim_buf_set_extmark(view.src_buf, ns_match, src_line - 1, 0, { line_hl_group = 'IdeAsmMatch', priority = 200 })
  for _, win in ipairs(vim.fn.win_findbuf(view.src_buf)) do
    vim.api.nvim_win_call(win, function()
      if src_line < vim.fn.line('w0') or src_line > vim.fn.line('w$') then
        vim.api.nvim_win_set_cursor(win, { src_line, 0 })
        vim.cmd('normal! zz')
      end
    end)
  end
end

local function show(lines, to_src, from_src, title)
  local src_win = vim.api.nvim_get_current_win()
  if not (view.buf and vim.api.nvim_buf_is_valid(view.buf)) then
    view.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[view.buf].filetype = 'asm'
    vim.bo[view.buf].bufhidden = 'hide'
    pcall(vim.api.nvim_buf_set_name, view.buf, 'asm://' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(view.src_buf), ':t'))
    vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = view.buf, desc = 'Close assembly' })
    vim.keymap.set('n', '<CR>', function()
      local l = view.to_src[vim.api.nvim_win_get_cursor(0)[1]]
      local wins = vim.fn.win_findbuf(view.src_buf)
      if l and wins[1] then
        vim.api.nvim_set_current_win(wins[1])
        vim.api.nvim_win_set_cursor(wins[1], { l, 0 })
      end
    end, { buffer = view.buf, desc = 'Go to source line' })
    vim.api.nvim_create_autocmd('CursorMoved', { buffer = view.buf, callback = sync_from_asm })
    vim.api.nvim_create_autocmd('BufLeave', {
      buffer = view.buf,
      callback = function()
        if view.src_buf and vim.api.nvim_buf_is_valid(view.src_buf) then
          vim.api.nvim_buf_clear_namespace(view.src_buf, ns_match, 0, -1)
        end
      end,
    })
  end
  if not view_open() then
    vim.cmd('botright vsplit')
    view.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(view.win, view.buf)
    vim.api.nvim_win_set_width(view.win, math.max(60, math.floor(vim.o.columns * 0.42)))
    for opt, val in pairs({ number = false, relativenumber = false, signcolumn = 'no', wrap = false, cursorline = true, list = false, foldenable = false }) do
      vim.wo[view.win][opt] = val
    end
    vim.api.nvim_set_current_win(src_win)
  end
  pcall(vim.api.nvim_buf_set_name, view.buf, 'asm://' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(view.src_buf), ':t'))
  vim.api.nvim_buf_clear_namespace(view.buf, ns_label, 0, -1)
  vim.bo[view.buf].modifiable = true
  vim.api.nvim_buf_set_lines(view.buf, 0, -1, false, lines)
  vim.bo[view.buf].modifiable = false
  -- function labels stand out
  for i, l in ipairs(lines) do
    if l:match('^[%w_.$][^:]*:') then
      vim.api.nvim_buf_set_extmark(view.buf, ns_label, i - 1, 0, { end_col = #l, hl_group = 'IdeAsmLabel', priority = 150 })
    end
  end
  vim.wo[view.win].winbar = ' ' .. title:gsub('%%', '%%%%')
  view.to_src, view.from_src = to_src, from_src
  sync_from_source()
end

local function demangle(lines, done)
  local tool = vim.fn.executable('c++filt') == 1 and 'c++filt' or require('config.lsp').llvm('llvm-cxxfilt')
  if vim.fn.executable(tool) ~= 1 then return done(lines) end
  vim.system({ tool }, { stdin = table.concat(lines, '\n'), text = true }, vim.schedule_wrap(function(res)
    done(res.code == 0 and vim.split(res.stdout:gsub('\n$', ''), '\n', { plain = true }) or lines)
  end))
end

--- Compile the current file to assembly and show it. `extra`: flags appended.
function M.asm(extra)
  local buf, src, ft = source_file()
  if not buf then return end
  if extra then view.extra = extra end
  local args, cwd, origin = invocation(src, ft)
  vim.list_extend(args, { '-S', '-o', '-', '-g1', '-fno-asynchronous-unwind-tables' })
  vim.list_extend(args, shell_split(view.extra or ''))
  view.src_buf = buf
  local start = uv.hrtime()
  vim.system(args, { cwd = cwd, text = true }, vim.schedule_wrap(function(res)
    if res.code ~= 0 then
      notify('Compile failed:\n' .. (res.stderr or ''):sub(1, 1500), vim.log.levels.ERROR)
      return
    end
    local lines, to_src, from_src = filter(res.stdout, src, cwd)
    demangle(lines, function(clean)
      local title = ('%s %s · %d lines · %.1f s · %s'):format(vim.fs.basename(args[1]), opt_level(args) or '-O0',
        #clean, (uv.hrtime() - start) / 1e9, origin)
      show(clean, to_src, from_src, title)
    end)
  end))
end

-- the source buffer drives the view: cursor -> highlight, save -> recompile
local group = vim.api.nvim_create_augroup('ide_asm', { clear = true })
vim.api.nvim_create_autocmd('CursorMoved', {
  group = group,
  callback = function(ev) if ev.buf == view.src_buf then sync_from_source() end end,
})
vim.api.nvim_create_autocmd('BufWritePost', {
  group = group,
  callback = function(ev)
    if ev.buf == view.src_buf and view_open() and vim.api.nvim_get_current_buf() == ev.buf then M.asm() end
  end,
})

-- Optimisation remarks ---------------------------------------------------------

function M.remarks(extra)
  local buf, src, ft = source_file()
  if not buf then return end
  local args, cwd = invocation(src, ft)
  local level = opt_level(args)
  local added = ''
  if not level or level == '-O0' then
    args[#args + 1] = '-O2' -- remarks only exist when the optimiser runs
    added = ' (build has ' .. (level or 'no -O') .. ': used -O2)'
  end
  local clang = vim.fs.basename(args[1]):match('clang') ~= nil
  if clang then
    vim.list_extend(args, {
      '-Rpass=loop-vectorize|slp-vectorizer|loop-unroll',
      '-Rpass-missed=loop-vectorize|inline',
      '-Rpass-analysis=loop-vectorize',
    })
  else
    vim.list_extend(args, { '-fopt-info-vec-optimized', '-fopt-info-vec-missed', '-fopt-info-loop-optimized' })
  end
  vim.list_extend(args, { '-S', '-o', vim.fn.has('win32') == 1 and 'NUL' or '/dev/null' })
  vim.list_extend(args, shell_split(extra or ''))
  notify('Collecting optimisation remarks…' .. added)
  vim.system(args, { cwd = cwd, text = true }, vim.schedule_wrap(function(res)
    local want, diags, seen = realpath(src), {}, {}
    for line in (res.stderr or ''):gmatch('[^\n]+') do
      local file, l, col, kind, msg = line:match('^(.-):(%d+):(%d+): (%a+): (.*)$')
      if file and realpath(file:sub(1, 1) == '/' and file or (cwd .. '/' .. file)) == want then
        local sev
        if kind == 'remark' then
          sev = msg:match('%[%-Rpass%-missed') and 'WARN' or msg:match('%[%-Rpass%-analysis') and 'HINT' or 'INFO'
          msg = msg:gsub('%s*%[%-R[^%]]+%]$', '')
        elseif kind == 'optimized' then sev = 'INFO'
        elseif kind == 'missed' then sev = 'WARN'
        elseif kind == 'note' then sev = 'HINT'
        end
        msg = vim.trim(msg)
        local key = l .. ':' .. msg
        if sev and not seen[key] then
          seen[key] = true
          diags[#diags + 1] = {
            lnum = tonumber(l) - 1, col = math.max(tonumber(col) - 1, 0), message = msg,
            severity = vim.diagnostic.severity[sev], source = 'optimizer',
          }
        end
      end
    end
    if res.code ~= 0 and #diags == 0 then
      notify('Compile failed:\n' .. (res.stderr or ''):sub(1, 1500), vim.log.levels.ERROR)
      return
    end
    vim.diagnostic.set(ns_remarks, buf, diags, { virtual_text = { current_line = true, prefix = '⚡' } })
    local vec = 0
    for _, d in ipairs(diags) do
      if d.severity == vim.diagnostic.severity.INFO and d.message:lower():find('vectoriz') then vec = vec + 1 end
    end
    notify(('%d remark(s), %d vectorised%s — <leader>xX lists them, <leader>mV clears'):format(#diags, vec, added))
  end))
end

function M.clear_remarks() vim.diagnostic.reset(ns_remarks) end

return M
