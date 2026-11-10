-- Small automatic behaviours
local group = vim.api.nvim_create_augroup('config', { clear = true })
local function au(event, opts)
  opts.group = group
  vim.api.nvim_create_autocmd(event, opts)
end

-- Flash the yanked text
au('TextYankPost', { callback = function() vim.hl.on_yank({ timeout = 200 }) end })

-- Reopen a file where you left it
au('BufReadPost', {
  callback = function(ev)
    if vim.tbl_contains({ 'gitcommit', 'gitrebase' }, vim.bo[ev.buf].filetype) then return end
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Keep splits equal when the terminal window is resized
au('VimResized', { command = 'tabdo wincmd =' })

-- Reload files changed on disk (git checkout, a build step, another editor)
au({ 'FocusGained', 'TermClose', 'TermLeave' }, {
  callback = function()
    if vim.o.buftype ~= 'nofile' then vim.cmd('silent! checktime') end
  end,
})

-- q closes helper windows
au('FileType', {
  pattern = { 'help', 'man', 'qf', 'checkhealth', 'lspinfo', 'query', 'git', 'gitsigns-blame', 'dap-float', 'notify' },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = ev.buf, silent = true, desc = 'Close window' })
  end,
})

-- Prose: wrap at words and check spelling
au('FileType', {
  pattern = { 'markdown', 'text', 'gitcommit', 'tex' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- C / C++: gc comments with // (C's ftplugin would use /* */)
au('FileType', {
  pattern = { 'c', 'cpp', 'cuda' },
  callback = function() vim.bo.commentstring = '// %s' end,
})

-- Create missing parent folders when saving a new file
au('BufWritePre', {
  callback = function(ev)
    if ev.match:match('^%w%w+:[\\/][\\/]') then return end -- URLs (oil://, scp://)
    vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ':p:h'), 'p')
  end,
})

-- Terminal buffers: no line numbers or signs
au('TermOpen', {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
    vim.opt_local.cursorline = false
  end,
})
