-- setup-terminal.cmd [uninstall]
-- Makes Windows Terminal look right for this portable Neovim, for your user
-- only (no admin):
--   1. installs Cascadia Code NF (the icon font) into your user font folder,
--      the same thing as right-click > "Install" on the .ttf files
--   2. adds a Windows Terminal "fragment": the Flexoki Dark / Light colour
--      schemes and two profiles, "Neovim (portable)" and "Dev shell (g++)".
--      Your own settings.json is not touched.
--   3. copies config\clangd\config.yaml (clang-tidy checks, inlay hints) to
--      %LOCALAPPDATA%\clangd, the only place clangd on Windows reads it from,
--      unless you already have a config.yaml there.
-- `setup-terminal.cmd uninstall` removes all of it again (and clangd's
-- %LOCALAPPDATA%\clangd\index cache, if the config there is ours).
local root = vim.fs.normalize(vim.fs.dirname(vim.fs.dirname(vim.fs.abspath(_G.arg[0]))))
local uninstall = _G.arg[1] == 'uninstall'
local localappdata = vim.fs.normalize(assert(vim.env.LOCALAPPDATA, 'LOCALAPPDATA is not set'))
local win = function(p) return (p:gsub('/', '\\')) end

local fonts = {
  ['CascadiaCodeNF.ttf'] = 'Cascadia Code NF Regular (TrueType)',
  ['CascadiaCodeNFItalic.ttf'] = 'Cascadia Code NF Italic (TrueType)',
}
local font_dir = localappdata .. '/Microsoft/Windows/Fonts'
local reg_key = [[HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts]]
local fragment_dir = localappdata .. '/Microsoft/Windows Terminal/Fragments/nvim-portable'
local clangd_dir = localappdata .. '/clangd'
local clangd_marker = 'nvim-portable' -- in the first line of the config.yaml we install

local function clangd_config_is_ours()
  local f = io.open(clangd_dir .. '/config.yaml', 'r')
  if not f then return false end
  local first = f:read('*l') or ''
  f:close()
  return first:find(clangd_marker, 1, true) ~= nil
end

local function reg(args)
  local r = vim.system(vim.list_extend({ 'reg.exe' }, args), { text = true }):wait()
  return r.code == 0, vim.trim((r.stdout or '') .. (r.stderr or ''))
end

if uninstall then
  for file, name in pairs(fonts) do
    reg({ 'delete', reg_key, '/v', name, '/f' })
    local ok = os.remove(font_dir .. '/' .. file)
    print((ok and 'removed font ' or 'font not removed (in use until you sign out?) ') .. file)
  end
  vim.fs.rm(fragment_dir, { recursive = true, force = true })
  print('removed the Windows Terminal profiles (restart Windows Terminal)')
  if clangd_config_is_ours() then
    os.remove(clangd_dir .. '/config.yaml')
    vim.fs.rm(clangd_dir .. '/index', { recursive = true, force = true })
    if #vim.fn.readdir(clangd_dir) == 0 then vim.fs.rm(clangd_dir, { recursive = true, force = true }) end
    print('removed the clangd config and its index cache')
  end
  return
end

-- 3. clangd config ---------------------------------------------------------------
if vim.uv.fs_stat(clangd_dir .. '/config.yaml') and not clangd_config_is_ours() then
  print('clangd: you already have ' .. win(clangd_dir) .. '\\config.yaml, left as it is')
else
  vim.fn.mkdir(clangd_dir, 'p')
  vim.uv.fs_copyfile(root .. '/config/clangd/config.yaml', clangd_dir .. '/config.yaml')
  print('clangd config installed (clang-tidy checks, inlay hints)')
end

-- 1. Font ---------------------------------------------------------------------
vim.fn.mkdir(font_dir, 'p')
for file, name in pairs(fonts) do
  local dest = font_dir .. '/' .. file
  if not vim.uv.fs_stat(dest) then assert(vim.uv.fs_copyfile(root .. '/fonts/' .. file, dest)) end
  local ok, msg = reg({ 'add', reg_key, '/v', name, '/t', 'REG_SZ', '/d', win(dest), '/f' })
  print(ok and ('font installed: ' .. file) or ('font: ' .. msg))
end

-- 2. Windows Terminal fragment ------------------------------------------------
local function scheme(name, c)
  return {
    name = name, background = c[1], foreground = c[2], cursorColor = c[3], selectionBackground = c[4],
    black = c[5], red = c[6], green = c[7], yellow = c[8], blue = c[9], purple = c[10], cyan = c[11], white = c[12],
    brightBlack = c[13], brightRed = c[14], brightGreen = c[15], brightYellow = c[16], brightBlue = c[17],
    brightPurple = c[18], brightCyan = c[19], brightWhite = c[20],
  }
end
-- the same colours as Neovim's :terminal (lua/flexoki) and extras/windows-terminal-flexoki.json
local dark = scheme('Flexoki Dark', {
  '#100F0F', '#CECDC3', '#FFFCF0', '#343331',
  '#343331', '#D14D41', '#879A39', '#D0A215', '#4385BE', '#CE5D97', '#3AA99F', '#878580',
  '#575653', '#E8705F', '#A0AF54', '#DFB431', '#66A0C8', '#E47DA8', '#5ABDAC', '#CECDC3',
})
local light = scheme('Flexoki Light', {
  '#FFFCF0', '#100F0F', '#100F0F', '#DAD8CE',
  '#100F0F', '#AF3029', '#66800B', '#AD8301', '#205EA6', '#A02F6F', '#24837B', '#CECDC3',
  '#6F6E69', '#D14D41', '#879A39', '#D0A215', '#4385BE', '#CE5D97', '#3AA99F', '#F2F0E5',
})
local common = {
  colorScheme = 'Flexoki Dark',
  font = { face = 'Cascadia Code NF', size = 12 },
  padding = '8',
  startingDirectory = '%USERPROFILE%',
  antialiasingMode = 'cleartype',
}
local fragment = {
  schemes = { dark, light },
  profiles = {
    vim.tbl_extend('force', common, {
      name = 'Neovim (portable)',
      commandline = ('cmd.exe /c "%s"'):format(win(root .. '/nvim.cmd')),
      icon = win(root .. '/nvim/bin/nvim.exe'),
    }),
    vim.tbl_extend('force', common, {
      name = 'Dev shell (g++)',
      commandline = ('cmd.exe /k "%s"'):format(win(root .. '/env.cmd')),
      icon = win(root .. '/w64devkit/w64devkit.exe'),
    }),
  },
}
vim.fn.mkdir(fragment_dir, 'p')
local f = assert(io.open(fragment_dir .. '/nvim-portable.json', 'w'))
f:write(vim.json.encode(fragment, { indent = '  ' }))
f:close()
print('Windows Terminal: added the profiles "Neovim (portable)" and "Dev shell (g++)"')
print('Restart Windows Terminal; the new profiles are in the dropdown (v) next to the + tab button.')
print('Tip: Settings > Startup > Default profile = "Neovim (portable)" opens Neovim in every new window.')
