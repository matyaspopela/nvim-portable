-- ============================================================================
--  Flexoki palette: https://stephango.com/flexoki  (Steph Ango, MIT)
--
--  Every value here is copied from the canonical palette in
--  github.com/kepano/flexoki (README "Colors" + "Extended palette"). Nothing is
--  approximated or blended; the theme only ever picks one of these.
--
--  Roles (stephango.com/flexoki, "Base color" / "Accent colors"):
--    bg, bg-2        primary / secondary background
--    ui, ui-2, ui-3  interface: normal (borders) / hover / active
--    tx-3, tx-2, tx  text: faint / muted / normal
--    re … ma         accents. Dark themes use the 400 values for syntax,
--                    light themes the 600 values; re2 … ma2 is the other one.
-- ============================================================================
local M = {}

M.base = {
  black = '#100F0F',
  [950] = '#1C1B1A', [900] = '#282726', [850] = '#343331', [800] = '#403E3C',
  [700] = '#575653', [600] = '#6F6E69', [500] = '#878580', [400] = '#9F9D96',
  [300] = '#B7B5AC', [200] = '#CECDC3', [150] = '#DAD8CE', [100] = '#E6E4D9',
  [50] = '#F2F0E5',
  paper = '#FFFCF0',
}

-- extended palette, 50 … 950
M.red = {
  [50] = '#FFE1D5', [100] = '#FFCABB', [150] = '#FDB2A2', [200] = '#F89A8A', [300] = '#E8705F',
  [400] = '#D14D41', [500] = '#C03E35', [600] = '#AF3029', [700] = '#942822', [800] = '#6C201C',
  [850] = '#551B18', [900] = '#3E1715', [950] = '#261312',
}
M.orange = {
  [50] = '#FFE7CE', [100] = '#FED3AF', [150] = '#FCC192', [200] = '#F9AE77', [300] = '#EC8B49',
  [400] = '#DA702C', [500] = '#CB6120', [600] = '#BC5215', [700] = '#9D4310', [800] = '#71320D',
  [850] = '#59290D', [900] = '#40200D', [950] = '#27180E',
}
M.yellow = {
  [50] = '#FAEEC6', [100] = '#F6E2A0', [150] = '#F1D67E', [200] = '#ECCB60', [300] = '#DFB431',
  [400] = '#D0A215', [500] = '#BE9207', [600] = '#AD8301', [700] = '#8E6B01', [800] = '#664D01',
  [850] = '#503D02', [900] = '#3A2D04', [950] = '#241E08',
}
M.green = {
  [50] = '#EDEECF', [100] = '#DDE2B2', [150] = '#CDD597', [200] = '#BEC97E', [300] = '#A0AF54',
  [400] = '#879A39', [500] = '#768D21', [600] = '#66800B', [700] = '#536907', [800] = '#3D4C07',
  [850] = '#313D07', [900] = '#252D09', [950] = '#1A1E0C',
}
M.cyan = {
  [50] = '#DDF1E4', [100] = '#BFE8D9', [150] = '#A2DECE', [200] = '#87D3C3', [300] = '#5ABDAC',
  [400] = '#3AA99F', [500] = '#2F968D', [600] = '#24837B', [700] = '#1C6C66', [800] = '#164F4A',
  [850] = '#143F3C', [900] = '#122F2C', [950] = '#101F1D',
}
M.blue = {
  [50] = '#E1ECEB', [100] = '#C6DDE8', [150] = '#ABCFE2', [200] = '#92BFDB', [300] = '#66A0C8',
  [400] = '#4385BE', [500] = '#3171B2', [600] = '#205EA6', [700] = '#1A4F8C', [800] = '#163B66',
  [850] = '#133051', [900] = '#12253B', [950] = '#101A24',
}
M.purple = {
  [50] = '#F0EAEC', [100] = '#E2D9E9', [150] = '#D3CAE6', [200] = '#C4B9E0', [300] = '#A699D0',
  [400] = '#8B7EC8', [500] = '#735EB5', [600] = '#5E409D', [700] = '#4F3685', [800] = '#3C2A62',
  [850] = '#31234E', [900] = '#261C39', [950] = '#1A1623',
}
M.magenta = {
  [50] = '#FEE4E5', [100] = '#FCCFDA', [150] = '#F9B9CF', [200] = '#F4A4C2', [300] = '#E47DA8',
  [400] = '#CE5D97', [500] = '#B74583', [600] = '#A02F6F', [700] = '#87285E', [800] = '#641F46',
  [850] = '#4F1B39', [900] = '#39172B', [950] = '#24131D',
}

local accents = { re = 'red', ['or'] = 'orange', ye = 'yellow', gr = 'green', cy = 'cyan', bl = 'blue', pu = 'purple', ma = 'magenta' }

--- The role table for 'dark' or 'light'.
---   c.bg c.bg2 c.ui c.ui2 c.ui3 c.tx3 c.tx2 c.tx      base roles
---   c.re c.or c.ye c.gr c.cy c.bl c.pu c.ma           syntax accents (400 dark / 600 light)
---   c.re2 …                                           the other main value (600 dark / 400 light)
---   c.tint.<accent>  faint background wash  (950 dark / 50 light)
---   c.wash.<accent>  stronger background    (900 dark / 100 light)
---   c.deep.<accent>  strong background      (850 dark / 150 light)
---   c.dim.<accent>   muted foreground       (700 dark / 300 light)
function M.roles(variant)
  local b, dark = M.base, variant ~= 'light'
  local c = dark and {
    bg = b.black, bg2 = b[950], ui = b[900], ui2 = b[850], ui3 = b[800],
    tx3 = b[700], tx2 = b[500], tx = b[200],
    caret = b.paper, -- Sublime port by kepano: caret = paper in dark, black in light
  } or {
    bg = b.paper, bg2 = b[50], ui = b[100], ui2 = b[150], ui3 = b[200],
    tx3 = b[300], tx2 = b[600], tx = b.black,
    caret = b.black,
  }
  c.variant = dark and 'dark' or 'light'
  c.tint, c.wash, c.deep, c.dim = {}, {}, {}, {}
  for short, name in pairs(accents) do
    local scale = M[name]
    c[short] = dark and scale[400] or scale[600]
    c[short .. '2'] = dark and scale[600] or scale[400]
    c.tint[short] = dark and scale[950] or scale[50]
    c.wash[short] = dark and scale[900] or scale[100]
    c.deep[short] = dark and scale[850] or scale[150]
    c.dim[short] = dark and scale[700] or scale[300]
  end
  return c
end

return M
