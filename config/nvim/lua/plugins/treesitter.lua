-- Treesitter: real syntax trees -> accurate highlighting, folds, text objects.
-- Parsers are compiled once on this machine (tree-sitter CLI + gcc, both installed).
--   :TSUpdate          update parsers          :TSInstall <lang>  add a language
--   :InspectTree       the tree of this file   :Inspect           highlight group under the cursor
local parsers = {
  -- C++ work
  'c', 'cpp', 'cmake', 'make', 'ninja', 'doxygen', 'cuda', 'asm', 'disassembly', 'objdump', 'llvm',
  'linkerscript', 'printf', 'regex', 'rust', 'proto', 'nasm',
  -- everything around it
  'bash', 'diff', 'dockerfile', 'git_config', 'git_rebase', 'gitcommit', 'gitignore', 'json', 'lua',
  'luadoc', 'markdown', 'markdown_inline', 'python', 'query', 'sql', 'toml', 'vim', 'vimdoc', 'yaml',
  'html', 'xml', 'gitattributes', 'requirements', 'ini',
}
vim.g.treesitter_parsers = parsers -- install.sh waits for these on a fresh machine

-- SQL in C++ raw strings: queries/cpp/injections.scm asks this whether a plain
-- R"( ... )" string holds SQL. It looks for the shape of a statement, so prose
-- like "Update available" is not mistaken for SQL. (R"sql( ... )sql" needs no
-- check: the delimiter names the language.)
local sql_starts = {
  '^insert%s+into%f[%W]', '^insert%s+or%s+%w+%s+into%f[%W]', '^replace%s+into%f[%W]',
  '^update%s+%S+%s+set%f[%W]', '^delete%s+from%f[%W]', '^with%s+%S+%s+as%f[%W]',
  '^with%s+recursive%s', '^alter%s+table%f[%W]', '^pragma%s+%w', '^select%s+[%d*\'(]',
  '^create%s+table%f[%W]', '^create%s+view%f[%W]', '^create%s+index%f[%W]', '^create%s+unique%s+index%f[%W]',
  '^create%s+or%s+replace%s', '^create%s+temp%a*%s+%a', '^create%s+virtual%s+table%f[%W]', '^create%s+trigger%f[%W]',
  '^drop%s+table%f[%W]', '^drop%s+index%f[%W]', '^drop%s+view%f[%W]',
  '^explain%s+select%f[%W]', '^explain%s+query%s+plan%f[%W]',
}
local function looks_like_sql(text)
  local s = text:lower()
  repeat -- skip leading blanks and "-- comment" lines
    local before = s
    s = s:gsub('^%s+', ''):gsub('^%-%-[^\n]*', '')
  until s == before
  if s:find('^select%s') and s:find('%f[%w]from%f[%W]') then return true end
  for _, p in ipairs(sql_starts) do
    if s:find(p) then return true end
  end
  return false
end
vim.treesitter.query.add_predicate('sql-raw?', function(match, _, source, pred)
  local node = match[pred[2]]
  node = type(node) == 'table' and node[1] or node
  return node ~= nil and looks_like_sql(vim.treesitter.get_node_text(node, source))
end, { force = true })

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false, -- must not be lazy-loaded (its own rule)
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').install(parsers) -- no-op once installed
      local group = vim.api.nvim_create_augroup('treesitter_start', { clear = true })
      vim.api.nvim_create_autocmd('FileType', {
        group = group,
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf) -- highlight if a parser exists for this filetype
        end,
      })

      -- Treesitter compiles a language's queries the first time it's used:
      -- ~0.25 s for C++ on this laptop, once per session. When Neovim starts in
      -- a C/C++ project (or a folder of C/C++ files), do that the first time
      -- you're idle (e.g. on the start screen), so the first file opens instantly.
      local markers = { 'CMakeLists.txt', 'compile_commands.json', '.clangd', 'Makefile', 'meson.build' }
      vim.api.nvim_create_autocmd('CursorHold', {
        group = group,
        once = true,
        callback = function()
          local cpp = vim.fs.root(0, markers) or #vim.fn.glob('*.{c,cc,cpp,cxx,h,hh,hpp}', false, true) > 0
          if not cpp then return end
          for _, query in ipairs({ 'highlights', 'injections', 'folds' }) do
            pcall(vim.treesitter.query.get, 'cpp', query)
          end
        end,
      })
    end,
  },

  { -- ]f [f next / previous function, ]c [c class, ]a [a argument (counts work: 3]f)
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    event = 'VeryLazy',
    config = function()
      require('nvim-treesitter-textobjects').setup({ move = { set_jumps = true } })
      local move = require('nvim-treesitter-textobjects.move')
      local moves = {
        f = { '@function.outer', 'function' },
        c = { '@class.outer', 'class' },
        a = { '@parameter.inner', 'argument' },
      }
      for key, m in pairs(moves) do
        for dir, fn in pairs({ [']'] = move.goto_next_start, ['['] = move.goto_previous_start }) do
          vim.keymap.set({ 'n', 'x', 'o' }, dir .. key, function()
            -- in a diff, ]c / [c keep their built-in meaning: next / previous change
            if vim.wo.diff and key == 'c' then return vim.cmd('normal! ' .. vim.v.count1 .. dir .. 'c') end
            fn(m[1], 'textobjects')
          end, { desc = (dir == ']' and 'Next ' or 'Previous ') .. m[2] })
        end
      end
    end,
  },

  { -- sticky header: the function / class / loop you're in stays visible at the top
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = { max_lines = 3, multiline_threshold = 1, trim_scope = 'inner', mode = 'cursor' },
    keys = {
      { '[x', function() require('treesitter-context').go_to_context(vim.v.count1) end, desc = 'Jump to context (header)' },
      { '<leader>uc', function() require('treesitter-context').toggle() end, desc = 'Toggle sticky header' },
    },
  },
}
