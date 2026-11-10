-- ============================================================================
--  Tests (neotest): run, debug and see results next to the code.
--
--    Python   pytest, in the project's .venv / $VIRTUAL_ENV
--    C / C++  CTest: whatever the CMake project registers (GoogleTest, Catch2,
--             doctest, plain add_test). Configure + build first (F7).
--
--  <leader>tt  nearest test        <leader>tf  this file      <leader>ta  whole project
--  <leader>td  debug nearest test  <leader>tl  run last again <leader>tS  stop
--  <leader>ts  test tree (summary) <leader>to  output of the test under the cursor
--  <leader>tO  output panel        <leader>tw  re-run this file on save (watch)
--  ✓ / ✗ show in the sign column; failures also as diagnostics on the line.
-- ============================================================================
local function nt() return require('neotest') end

return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'nvim-neotest/neotest-python',
    'orjangj/neotest-ctest',
  },
  cmd = 'Neotest',
  keys = {
    { '<leader>tt', function() nt().run.run() end, desc = 'Run nearest test' },
    { '<leader>tf', function() nt().run.run(vim.fn.expand('%')) end, desc = 'Run tests in this file' },
    { '<leader>ta', function() nt().run.run(vim.uv.cwd()) end, desc = 'Run all tests in the project' },
    { '<leader>td', function() nt().run.run({ strategy = 'dap' }) end, desc = 'Debug nearest test' },
    { '<leader>tl', function() nt().run.run_last() end, desc = 'Run last test again' },
    { '<leader>tS', function() nt().run.stop() end, desc = 'Stop tests' },
    { '<leader>ts', function() nt().summary.toggle() end, desc = 'Test tree (summary)' },
    { '<leader>to', function() nt().output.open({ enter = true, auto_close = true }) end, desc = 'Test output' },
    { '<leader>tO', function() nt().output_panel.toggle() end, desc = 'Test output panel' },
    { '<leader>tw', function() nt().watch.toggle(vim.fn.expand('%')) end, desc = 'Watch this file (re-run on save)' },
    { ']n', function() nt().jump.next({ status = 'failed' }) end, desc = 'Next failed test' },
    { '[n', function() nt().jump.prev({ status = 'failed' }) end, desc = 'Previous failed test' },
  },
  opts = function()
    return {
      adapters = {
        require('neotest-python')({
          runner = 'pytest',
          dap = { justMyCode = false },
          python = function(root)
            return require('config.lsp').python(root) or vim.g.python_exe
          end,
        }),
        require('neotest-ctest').setup({}),
      },
      status = { virtual_text = false, signs = true },
      output = { open_on_run = false },
      quickfix = { enabled = false },
      floating = { border = 'rounded', max_width = 0.8, max_height = 0.7 },
      summary = { animated = false },
      icons = {
        passed = '\u{f00c}', failed = '\u{f00d}', running = '\u{f110}', skipped = '\u{f05e}',
        unknown = '\u{f128}', watching = '\u{f06e}', running_animated = { '\u{f110}' },
        expanded = '▾', collapsed = '▸', child_prefix = ' ', child_indent = ' ',
        final_child_prefix = ' ', final_child_indent = ' ', non_collapsible = ' ',
      },
    }
  end,
  config = function(_, opts)
    -- failure messages: tidy one-liners at the line that failed
    local ns = vim.api.nvim_create_namespace('neotest')
    vim.diagnostic.config({
      virtual_text = {
        format = function(d) return d.message:gsub('\n', ' '):gsub('\t', ' '):gsub('%s+', ' '):gsub('^%s+', '') end,
      },
    }, ns)
    require('neotest').setup(opts)
  end,
}
