-- ============================================================================
--  Flexoki for Neovim: https://stephango.com/flexoki
--
--  Built from the canonical palette (lua/flexoki/palette.lua). Syntax roles
--  follow kepano's own Flexoki ports (Sublime Text scheme + the reference
--  screenshot in github.com/kepano/flexoki):
--
--    keywords, control flow          green        imports, #include, #define   red
--    class / struct / const, int     blue         type, class & function names orange
--    variables, members, params      blue         strings                      cyan
--    numbers                         purple       true, nullptr, constants     yellow
--    this / self                     magenta      escapes  \n                  red
--    library (std::, print, len)     green        punctuation, operators       muted
--    modifiers (static, async)       normal text  comments                     faint
--
--  Light / dark:  <leader>ub,  :Flexoki toggle | dark | light   (remembered)
--  The terminal's own background (Windows Terminal padding) follows along.
-- ============================================================================
local M = {}

local palette = require('flexoki.palette')
local state_file = vim.fn.stdpath('state') .. '/flexoki-background'

---@param c table role table from palette.roles()
---@return table<string, vim.api.keyset.highlight>
function M.groups(c)
  local none = 'NONE'
  local g = {}

  -- Editor ---------------------------------------------------------------------
  g.Normal = { fg = c.tx, bg = c.bg }
  g.NormalNC = { link = 'Normal' }
  g.NormalFloat = { fg = c.tx, bg = c.bg } -- floats share the editor background; the border carries them
  g.FloatBorder = { fg = c.ui3, bg = c.bg }
  g.FloatTitle = { fg = c.tx, bg = c.bg, bold = true }
  g.FloatFooter = { fg = c.tx3, bg = c.bg }
  g.FloatShadow = { bg = palette.base.black, blend = 80 }
  g.FloatShadowThrough = { bg = palette.base.black, blend = 100 }

  g.Cursor = { fg = c.bg, bg = c.caret }
  g.lCursor = { link = 'Cursor' }
  g.CursorIM = { link = 'Cursor' }
  g.TermCursor = { fg = c.bg, bg = c.caret }
  g.CursorLine = { bg = c.bg2 } -- Sublime: line_highlight = bg-2
  g.CursorColumn = { bg = c.bg2 }
  g.ColorColumn = { bg = c.bg2 }
  g.LineNr = { fg = c.tx3 }
  g.LineNrAbove = { link = 'LineNr' }
  g.LineNrBelow = { link = 'LineNr' }
  g.CursorLineNr = { fg = c.tx }
  g.CursorLineSign = { bg = none }
  g.CursorLineFold = { fg = c.tx2 }
  g.SignColumn = { bg = none }
  g.FoldColumn = { fg = c.tx3, bg = none }
  g.Folded = { fg = c.tx2, bg = c.bg2 }
  g.WinSeparator = { fg = c.ui, bg = none }
  g.VertSplit = { link = 'WinSeparator' }
  g.EndOfBuffer = { fg = c.bg }
  g.NonText = { fg = c.tx3 }
  g.Whitespace = { fg = c.ui3 }
  g.SpecialKey = { fg = c.tx3 }
  g.Conceal = { fg = c.tx2 }

  g.Visual = { bg = c.ui2 }
  g.VisualNOS = { bg = c.ui2 }
  g.Search = { fg = c.tx, bg = c.wash.ye }
  g.CurSearch = { fg = c.bg, bg = c.ye }
  g.IncSearch = { link = 'CurSearch' }
  g.Substitute = { fg = c.bg, bg = c.re }
  g.MatchParen = { fg = c.gr, bold = true, underline = true } -- Sublime: brackets = green, underline
  g.QuickFixLine = { bg = c.ui, bold = true }

  g.Pmenu = { fg = c.tx, bg = c.bg }
  g.PmenuSel = { bg = c.ui2 }
  g.PmenuKind = { fg = c.tx2 }
  g.PmenuKindSel = { fg = c.tx2, bg = c.ui2 }
  g.PmenuExtra = { fg = c.tx3 }
  g.PmenuExtraSel = { fg = c.tx2, bg = c.ui2 }
  g.PmenuMatch = { fg = c['or'], bold = true }
  g.PmenuMatchSel = { fg = c['or'], bg = c.ui2, bold = true }
  g.PmenuSbar = { bg = c.bg }
  g.PmenuThumb = { bg = c.ui2 }
  g.PmenuBorder = { link = 'FloatBorder' }
  g.WildMenu = { link = 'PmenuSel' }
  g.ComplMatchIns = { fg = c.tx3 }
  g.SnippetTabstop = { bg = c.ui }

  g.StatusLine = { fg = c.tx2, bg = c.bg } -- lualine's bubbles float on the editor background
  g.StatusLineNC = { fg = c.tx3, bg = c.bg }
  g.StatusLineTerm = { link = 'StatusLine' }
  g.StatusLineTermNC = { link = 'StatusLineNC' }
  g.TabLine = { fg = c.tx3, bg = c.bg }
  g.TabLineSel = { fg = c.tx, bg = c.bg }
  g.TabLineFill = { bg = c.bg }
  g.WinBar = { fg = c.tx2, bg = c.bg }
  g.WinBarNC = { fg = c.tx3, bg = c.bg }

  g.Title = { fg = c['or'], bold = true }
  g.Directory = { fg = c.bl }
  g.Question = { fg = c.gr }
  g.MoreMsg = { fg = c.gr }
  g.ModeMsg = { fg = c.tx2 }
  g.MsgArea = { fg = c.tx }
  g.MsgSeparator = { fg = c.ui, bg = c.bg }
  g.ErrorMsg = { fg = c.re }
  g.WarningMsg = { fg = c.ye }
  g.OkMsg = { fg = c.gr }
  g.StderrMsg = { fg = c.re }
  g.StdoutMsg = { fg = c.tx }

  g.SpellBad = { undercurl = true, sp = c.re }
  g.SpellCap = { undercurl = true, sp = c.ye }
  g.SpellLocal = { undercurl = true, sp = c.cy }
  g.SpellRare = { undercurl = true, sp = c.pu }

  -- Diffs: faint washes from the extended palette, so the code stays readable.
  -- Changes are yellow in Flexoki (Sublime: line_diff_modified = yellow).
  g.DiffAdd = { bg = c.wash.gr }
  g.DiffChange = { bg = c.tint.ye }
  g.DiffText = { bg = c.deep.ye }
  g.DiffDelete = { fg = c.dim.re, bg = c.tint.re }
  g.DiffTextAdd = { bg = c.deep.gr }
  g.Added = { fg = c.gr }
  g.Changed = { fg = c.ye }
  g.Removed = { fg = c.re }
  g.diffAdded = { link = 'Added' }
  g.diffChanged = { link = 'Changed' }
  g.diffRemoved = { link = 'Removed' }
  g.diffFile = { fg = c.bl, bold = true }
  g.diffLine = { fg = c.pu }
  g.diffIndexLine = { fg = c.tx3 }

  -- Diagnostics -----------------------------------------------------------------
  local diag = { Error = c.re, Warn = c.ye, Info = c.bl, Hint = c.cy, Ok = c.gr }
  for name, color in pairs(diag) do
    g['Diagnostic' .. name] = { fg = color }
    g['DiagnosticSign' .. name] = { fg = color, bg = none }
    g['DiagnosticVirtualText' .. name] = { fg = color }
    g['DiagnosticVirtualLines' .. name] = { fg = color }
    g['DiagnosticFloating' .. name] = { fg = color }
    g['DiagnosticUnderline' .. name] = { undercurl = true, sp = color }
  end
  g.DiagnosticUnnecessary = { fg = c.tx3 } -- unused variables / includes fade out
  g.DiagnosticDeprecated = { strikethrough = true, sp = c.tx2 }

  g.LspReferenceText = { bg = c.ui }
  g.LspReferenceRead = { bg = c.ui }
  g.LspReferenceWrite = { bg = c.ui, underline = true, sp = c.tx3 }
  g.LspReferenceTarget = { link = 'LspReferenceText' }
  g.LspSignatureActiveParameter = { fg = c['or'], bold = true }
  g.LspInlayHint = { fg = c.tx3, italic = true }
  g.LspCodeLens = { fg = c.tx3 }
  g.LspCodeLensSeparator = { fg = c.ui3 }
  g.LspInfoBorder = { link = 'FloatBorder' }

  -- Syntax (legacy groups: every language without Treesitter) -------------------
  g.Comment = { fg = c.tx3 }
  g.Constant = { fg = c.ye }
  g.String = { fg = c.cy }
  g.Character = { fg = c.cy }
  g.Number = { fg = c.pu }
  g.Float = { link = 'Number' }
  g.Boolean = { fg = c.ye }
  g.Identifier = { fg = c.bl }
  g.Function = { fg = c['or'] }
  g.Statement = { fg = c.gr }
  g.Conditional = { fg = c.gr }
  g.Repeat = { fg = c.gr }
  g.Label = { fg = c['or'] }
  g.Operator = { fg = c.tx2 }
  g.Keyword = { fg = c.gr }
  g.Exception = { fg = c.gr }
  g.PreProc = { fg = c.re }
  g.Include = { fg = c.re }
  g.Define = { fg = c.re }
  g.Macro = { fg = c['or'] }
  g.PreCondit = { fg = c.re }
  g.Type = { fg = c['or'] }
  g.StorageClass = { fg = c.tx }
  g.Structure = { fg = c.bl }
  g.Typedef = { fg = c.bl }
  g.Special = { fg = c.ye }
  g.SpecialChar = { fg = c.re }
  g.Tag = { fg = c.bl }
  g.Delimiter = { fg = c.tx2 }
  g.SpecialComment = { fg = c.tx2 }
  g.Debug = { fg = c.ma }
  g.Underlined = { underline = true }
  g.Bold = { bold = true }
  g.Italic = { italic = true }
  g.Ignore = { fg = c.tx3 }
  g.Error = { fg = c.re }
  g.Todo = { fg = c.ma, bold = true }

  -- Treesitter --------------------------------------------------------------------
  g['@variable'] = { fg = c.bl }
  g['@variable.builtin'] = { fg = c.ma } -- this, self
  g['@variable.parameter'] = { fg = c.bl }
  g['@variable.parameter.builtin'] = { fg = c.ma }
  g['@variable.member'] = { fg = c.bl }
  g['@property'] = { fg = c.bl }

  g['@constant'] = { fg = c.ye }
  g['@constant.builtin'] = { fg = c.ye } -- nullptr, None
  g['@constant.macro'] = { fg = c['or'] } -- #define NAME
  g['@boolean'] = { fg = c.ye }
  g['@number'] = { fg = c.pu }
  g['@number.float'] = { fg = c.pu }

  g['@module'] = { fg = c.tx2 } -- std:: / namespace qualifiers stay quiet
  g['@module.builtin'] = { fg = c.gr }
  g['@label'] = { fg = c['or'] }

  g['@string'] = { fg = c.cy }
  g['@string.documentation'] = { fg = c.tx3 } -- docstrings read as comments
  g['@string.regexp'] = { fg = c.cy }
  g['@string.escape'] = { fg = c.re }
  g['@string.special'] = { fg = c.cy }
  g['@string.special.symbol'] = { fg = c.cy }
  g['@string.special.path'] = { fg = c.cy }
  g['@string.special.url'] = { fg = c.cy, underline = true }
  g['@character'] = { fg = c.cy }
  g['@character.special'] = { fg = c.re }

  g['@type'] = { fg = c['or'] }
  g['@type.builtin'] = { fg = c.bl } -- int, void, auto, char (storage.type)
  g['@type.definition'] = { fg = c['or'] }
  g['@type.qualifier'] = { fg = c.tx }
  g['@type.builtin.python'] = { fg = c.gr } -- int, str, list: Python's library classes
  g['@attribute'] = { fg = c['or'] } -- @decorator, [[nodiscard]]
  g['@attribute.builtin'] = { fg = c['or'] }

  g['@function'] = { fg = c['or'] }
  g['@function.call'] = { fg = c['or'] }
  g['@function.method'] = { fg = c['or'] }
  g['@function.method.call'] = { fg = c['or'] }
  g['@function.builtin'] = { fg = c.gr } -- print, len, sizeof-likes
  g['@function.macro'] = { fg = c['or'] }
  g['@constructor'] = { fg = c['or'] }
  g['@operator'] = { fg = c.tx2 }

  g['@keyword'] = { fg = c.gr }
  g['@keyword.coroutine'] = { fg = c.gr }
  g['@keyword.function'] = { fg = c.bl } -- def, fn, function (storage.type)
  g['@keyword.type'] = { fg = c.bl } -- class, struct, enum, typename
  g['@keyword.modifier'] = { fg = c.tx } -- const, static, constexpr, async (storage.modifier)
  g['@keyword.operator'] = { fg = c.gr }
  g['@keyword.import'] = { fg = c.re } -- #include, import, from, use
  g['@keyword.repeat'] = { fg = c.gr }
  g['@keyword.return'] = { fg = c.gr }
  g['@keyword.debug'] = { fg = c.ma }
  g['@keyword.exception'] = { fg = c.gr }
  g['@keyword.conditional'] = { fg = c.gr }
  g['@keyword.conditional.ternary'] = { fg = c.tx2 }
  g['@keyword.directive'] = { fg = c.re } -- #if, #pragma, shebang
  g['@keyword.directive.define'] = { fg = c.re }

  g['@punctuation'] = { fg = c.tx2 }
  g['@punctuation.delimiter'] = { fg = c.tx2 }
  g['@punctuation.bracket'] = { fg = c.tx2 }
  g['@punctuation.special'] = { fg = c.tx2 }

  g['@comment'] = { fg = c.tx3 }
  g['@comment.documentation'] = { fg = c.tx3 }
  g['@comment.error'] = { fg = c.re, bold = true }
  g['@comment.warning'] = { fg = c.ye, bold = true }
  g['@comment.todo'] = { fg = c.pu, bold = true }
  g['@comment.note'] = { fg = c.bl, bold = true }

  g['@tag'] = { fg = c.bl }
  g['@tag.builtin'] = { fg = c.bl }
  g['@tag.attribute'] = { fg = c['or'] }
  g['@tag.delimiter'] = { fg = c.tx2 }

  -- markup (Markdown, help, LSP hover docs)
  g['@markup'] = { fg = c.tx }
  g['@markup.strong'] = { bold = true }
  g['@markup.italic'] = { italic = true }
  g['@markup.strikethrough'] = { strikethrough = true }
  g['@markup.underline'] = { underline = true }
  g['@markup.heading'] = { fg = c['or'], bold = true } -- entity.name.section
  for i = 1, 6 do g['@markup.heading.' .. i] = { link = '@markup.heading' } end
  g['@markup.quote'] = { fg = c.tx2, italic = true }
  g['@markup.math'] = { fg = c.ye }
  g['@markup.link'] = { fg = c.bl }
  g['@markup.link.label'] = { fg = c.bl }
  g['@markup.link.url'] = { fg = c.cy, underline = true }
  g['@markup.raw'] = { fg = c.cy }
  g['@markup.raw.block'] = { fg = c.tx }
  g['@markup.list'] = { fg = c.tx2 }
  g['@markup.list.checked'] = { fg = c.gr }
  g['@markup.list.unchecked'] = { fg = c.tx2 }
  g['@diff.plus'] = { fg = c.gr }
  g['@diff.minus'] = { fg = c.re }
  g['@diff.delta'] = { fg = c.ye }

  -- LSP semantic tokens (clangd, basedpyright, lua_ls, rust-analyzer) ----------
  -- They refine Treesitter: what *is* a macro / type / library symbol.
  local sem = {
    class = '@type', comment = '@comment', decorator = '@attribute', enum = '@type',
    enumMember = '@constant', event = '@type', ['function'] = '@function', interface = '@type',
    keyword = '@keyword', macro = '@constant.macro', method = '@function.method',
    modifier = '@type.qualifier', namespace = '@module', number = '@number', operator = '@operator',
    parameter = '@variable.parameter', property = '@property', regexp = '@string.regexp',
    string = '@string', struct = '@type', type = '@type', typeParameter = '@type.definition',
    variable = '@variable', concept = '@type', label = '@label', bracket = '@punctuation.bracket',
    selfParameter = '@variable.builtin', clsParameter = '@variable.builtin',
    selfKeyword = '@variable.builtin', builtinConstant = '@constant.builtin',
    builtinType = '@type.builtin', lifetime = '@label', formatSpecifier = '@string.escape',
  }
  for token, target in pairs(sem) do g['@lsp.type.' .. token] = { link = target } end
  -- library symbols are green, like `console` / `window` in the reference
  -- screenshot (Sublime: support.* = green): std::vector, std::move, print, len
  for _, token in ipairs({ 'class', 'struct', 'type', 'function', 'method', 'variable', 'enum', 'interface', 'concept' }) do
    g['@lsp.typemod.' .. token .. '.defaultLibrary'] = { fg = c.gr }
    g['@lsp.typemod.' .. token .. '.builtin'] = { fg = c.gr }
  end
  g['@lsp.typemod.variable.defaultLibrary'] = { fg = c.gr }
  g['@lsp.mod.deprecated'] = { strikethrough = true }
  -- clangd: an argument passed by non-const reference / pointer is italic, so
  -- you see at the call site which arguments the function may modify
  g['@lsp.mod.usedAsMutableReference'] = { italic = true }
  g['@lsp.mod.usedAsMutablePointer'] = { italic = true }
  g['@lsp.type.unknown'] = {} -- clangd: dependent names in templates keep Treesitter's colour

  -- Plugins ----------------------------------------------------------------------

  -- snacks: start screen
  g.SnacksDashboardHeader = { fg = c.tx, bold = true }
  g.SnacksDashboardIcon = { fg = c['or'] }
  g.SnacksDashboardKey = { fg = c.ye }
  g.SnacksDashboardDesc = { fg = c.tx2 }
  g.SnacksDashboardTitle = { fg = c.tx2, bold = true }
  g.SnacksDashboardFooter = { fg = c.tx3 }
  g.SnacksDashboardSpecial = { fg = c['or'] }
  g.SnacksDashboardDir = { fg = c.tx3 }
  g.SnacksDashboardFile = { fg = c.tx2 }
  -- snacks: notifications: one soft outline; colour only on icon + title
  local levels = { Error = c.re, Warn = c.ye, Info = c.gr, Debug = c.tx3, Trace = c.tx3 }
  for level, color in pairs(levels) do
    g['SnacksNotifier' .. level] = { fg = c.tx, bg = c.bg }
    g['SnacksNotifierBorder' .. level] = { fg = c.ui3, bg = c.bg }
    g['SnacksNotifierIcon' .. level] = { fg = color }
    g['SnacksNotifierTitle' .. level] = { fg = color, bold = true }
    g['SnacksNotifierFooter' .. level] = { fg = c.tx3 }
  end
  g.SnacksNotifierHistory = { link = 'NormalFloat' }
  g.SnacksNotifierHistoryTitle = { fg = c.tx, bold = true }
  g.SnacksNotifierHistoryDateTime = { fg = c.tx3 }
  -- snacks: picker / explorer
  g.SnacksPicker = { link = 'NormalFloat' }
  g.SnacksPickerBorder = { link = 'FloatBorder' }
  g.SnacksPickerTitle = { fg = c.tx, bg = c.bg, bold = true }
  g.SnacksPickerPrompt = { fg = c['or'] }
  g.SnacksPickerMatch = { fg = c['or'], bold = true }
  g.SnacksPickerListCursorLine = { bg = c.ui2 }
  g.SnacksPickerPreviewCursorLine = { bg = c.bg2 }
  g.SnacksPickerDir = { fg = c.tx3 }
  g.SnacksPickerPathHidden = { fg = c.tx3 }
  g.SnacksPickerPathIgnored = { fg = c.tx3 }
  g.SnacksPickerTree = { fg = c.ui3 }
  g.SnacksPickerTotals = { fg = c.tx3 }
  g.SnacksPickerRow = { fg = c.tx3 }
  g.SnacksPickerCol = { fg = c.tx3 }
  g.SnacksPickerComment = { fg = c.tx3 }
  g.SnacksPickerSelected = { fg = c.ma }
  g.SnacksPickerUnselected = { fg = c.ui3 }
  g.SnacksPickerToggle = { fg = c.bg, bg = c.bl }
  g.SnacksPickerSpecial = { fg = c.ma }
  g.SnacksPickerLabel = { fg = c.ma, bold = true }
  g.SnacksPickerGitStatusAdded = { fg = c.gr }
  g.SnacksPickerGitStatusModified = { fg = c.ye }
  g.SnacksPickerGitStatusDeleted = { fg = c.re }
  g.SnacksPickerGitStatusRenamed = { fg = c.bl }
  g.SnacksPickerGitStatusCopied = { fg = c.bl }
  g.SnacksPickerGitStatusUntracked = { fg = c.tx2 }
  g.SnacksPickerGitStatusIgnored = { fg = c.tx3 }
  g.SnacksPickerGitStatusStaged = { fg = c.gr }
  g.SnacksPickerGitStatusUnmerged = { fg = c.re, bold = true }
  -- snacks: misc
  g.SnacksIndent = { fg = c.ui }
  g.SnacksIndentScope = { fg = c.ui3 }
  g.SnacksInputIcon = { fg = c['or'] }
  g.SnacksInputTitle = { fg = c.tx, bold = true }
  g.SnacksInputBorder = { link = 'FloatBorder' }
  g.SnacksBackdrop = { bg = c.bg }
  g.SnacksZenIcon = { fg = c.tx3 }

  -- blink.cmp
  g.BlinkCmpMenu = { link = 'Pmenu' }
  g.BlinkCmpMenuBorder = { link = 'FloatBorder' }
  g.BlinkCmpMenuSelection = { link = 'PmenuSel' }
  g.BlinkCmpScrollBarThumb = { bg = c.ui2 }
  g.BlinkCmpScrollBarGutter = { bg = c.bg }
  g.BlinkCmpLabel = { fg = c.tx }
  g.BlinkCmpLabelMatch = { fg = c['or'], bold = true }
  g.BlinkCmpLabelDeprecated = { fg = c.tx3, strikethrough = true }
  g.BlinkCmpLabelDetail = { fg = c.tx3 }
  g.BlinkCmpLabelDescription = { fg = c.tx3 }
  g.BlinkCmpSource = { fg = c.tx3 }
  g.BlinkCmpGhostText = { fg = c.tx3 }
  g.BlinkCmpDoc = { link = 'NormalFloat' }
  g.BlinkCmpDocBorder = { link = 'FloatBorder' }
  g.BlinkCmpDocSeparator = { fg = c.ui2 }
  g.BlinkCmpDocCursorLine = { bg = c.ui }
  g.BlinkCmpSignatureHelp = { link = 'NormalFloat' }
  g.BlinkCmpSignatureHelpBorder = { link = 'FloatBorder' }
  g.BlinkCmpSignatureHelpActiveParameter = { link = 'LspSignatureActiveParameter' }
  g.BlinkCmpKind = { fg = c.tx2 }
  local kinds = {
    Text = c.tx2, Method = c['or'], Function = c['or'], Constructor = c['or'], Field = c.bl,
    Variable = c.bl, Property = c.bl, Class = c['or'], Interface = c['or'], Struct = c['or'],
    Module = c.tx2, Unit = c.pu, Value = c.pu, Enum = c['or'], EnumMember = c.ye, Keyword = c.gr,
    Constant = c.ye, Snippet = c.ma, Color = c.ma, File = c.tx2, Reference = c.bl, Folder = c.bl,
    Event = c.ye, Operator = c.tx2, TypeParameter = c['or'],
  }
  for kind, color in pairs(kinds) do g['BlinkCmpKind' .. kind] = { fg = color } end

  -- bufferline: plain names, current bright, others faint. (bufferline is
  -- "themable": these win over the colours it would derive.)
  local bl = { fg = c.tx3, bg = c.bg }
  local sel = { fg = c.tx, bg = c.bg, bold = false, italic = false }
  local hidden = { fg = c.bg, bg = c.bg }
  for name, spec in pairs({
    Fill = { bg = c.bg }, Background = bl, BufferVisible = bl, BufferSelected = sel,
    Modified = bl, ModifiedVisible = bl, ModifiedSelected = { fg = c.ye, bg = c.bg },
    Duplicate = vim.tbl_extend('force', bl, { italic = false }),
    DuplicateVisible = vim.tbl_extend('force', bl, { italic = false }),
    DuplicateSelected = { fg = c.tx2, bg = c.bg, italic = false },
    Pick = { fg = c.ma, bg = c.bg, bold = true }, PickVisible = { fg = c.ma, bg = c.bg, bold = true },
    PickSelected = { fg = c.ma, bg = c.bg, bold = true },
    Separator = hidden, SeparatorVisible = hidden, SeparatorSelected = hidden,
    IndicatorSelected = hidden, IndicatorVisible = hidden, OffsetSeparator = hidden,
    TruncMarker = bl, Tab = bl, TabSelected = sel, TabSeparator = hidden, TabSeparatorSelected = hidden,
    NumbersVisible = bl, Numbers = bl, NumbersSelected = sel,
  }) do
    g['BufferLine' .. name] = spec
  end

  -- which-key
  g.WhichKey = { fg = c['or'] }
  g.WhichKeyGroup = { fg = c.bl }
  g.WhichKeyDesc = { fg = c.tx }
  g.WhichKeySeparator = { fg = c.tx3 }
  g.WhichKeyValue = { fg = c.tx3 }
  g.WhichKeyNormal = { link = 'NormalFloat' }
  g.WhichKeyBorder = { link = 'FloatBorder' }
  g.WhichKeyTitle = { link = 'FloatTitle' }

  -- flash
  g.FlashBackdrop = { fg = c.tx3 }
  g.FlashMatch = { fg = c.tx, bg = c.ui2 }
  g.FlashCurrent = { fg = c.bg, bg = c.ye }
  g.FlashLabel = { fg = c.bg, bg = c.ma, bold = true }
  g.FlashPrompt = { link = 'NormalFloat' }

  -- mini.icons (file icons everywhere)
  for name, color in pairs({ Azure = c.cy, Blue = c.bl, Cyan = c.cy, Green = c.gr, Grey = c.tx2, Orange = c['or'], Purple = c.pu, Red = c.re, Yellow = c.ye }) do
    g['MiniIcons' .. name] = { fg = color }
  end

  -- gitsigns: staged changes use the dimmer 700 / 300 values
  g.GitSignsAdd = { fg = c.gr }
  g.GitSignsChange = { fg = c.ye }
  g.GitSignsDelete = { fg = c.re }
  g.GitSignsTopdelete = { fg = c.re }
  g.GitSignsChangedelete = { fg = c.ye }
  g.GitSignsUntracked = { fg = c.tx3 }
  g.GitSignsStagedAdd = { fg = c.dim.gr }
  g.GitSignsStagedChange = { fg = c.dim.ye }
  g.GitSignsStagedDelete = { fg = c.dim.re }
  g.GitSignsStagedTopdelete = { fg = c.dim.re }
  g.GitSignsStagedChangedelete = { fg = c.dim.ye }
  g.GitSignsCurrentLineBlame = { fg = c.tx3 }
  g.GitSignsAddInline = { bg = c.deep.gr }
  g.GitSignsChangeInline = { bg = c.deep.ye }
  g.GitSignsDeleteInline = { bg = c.deep.re }
  g.GitSignsAddPreview = { link = 'DiffAdd' }
  g.GitSignsDeletePreview = { link = 'DiffDelete' }
  g.GitSignsDeleteVirtLn = { fg = c.tx2, bg = c.tint.re }
  g.GitSignsDeleteVirtLnInLine = { bg = c.deep.re }

  -- diffview
  g.DiffviewFilePanelTitle = { fg = c.tx, bold = true }
  g.DiffviewFilePanelCounter = { fg = c.tx3 }
  g.DiffviewFilePanelFileName = { fg = c.tx }
  g.DiffviewFilePanelPath = { fg = c.tx3 }
  g.DiffviewFilePanelRootPath = { fg = c.tx2, bold = true }
  g.DiffviewFilePanelInsertions = { fg = c.gr }
  g.DiffviewFilePanelDeletions = { fg = c.re }
  g.DiffviewFilePanelSelected = { fg = c.ye }
  g.DiffviewFolderSign = { fg = c.tx3 }
  g.DiffviewStatusAdded = { fg = c.gr }
  g.DiffviewStatusUntracked = { fg = c.tx2 }
  g.DiffviewStatusModified = { fg = c.ye }
  g.DiffviewStatusRenamed = { fg = c.bl }
  g.DiffviewStatusCopied = { fg = c.bl }
  g.DiffviewStatusDeleted = { fg = c.re }
  g.DiffviewStatusUnmerged = { fg = c.re, bold = true }
  g.DiffviewDiffDeleteDim = { fg = c.ui2 }
  g.DiffviewDiffAddAsDelete = { bg = c.tint.re }

  -- trouble
  g.TroubleNormal = { link = 'Normal' }
  g.TroubleNormalNC = { link = 'Normal' }
  g.TroubleText = { fg = c.tx }
  g.TroubleCount = { fg = c.ma }
  g.TroublePos = { fg = c.tx3 }
  g.TroubleSource = { fg = c.tx3 }
  g.TroubleCode = { fg = c.tx3 }
  g.TroubleDirectory = { fg = c.bl }
  g.TroubleFilename = { fg = c.tx }
  g.TroubleIndent = { fg = c.ui3 }
  g.TroubleIconDirectory = { fg = c.bl }

  -- treesitter-context: same background, a faint line under it
  g.TreesitterContext = { bg = c.bg }
  g.TreesitterContextLineNumber = { fg = c.tx3, bg = c.bg }
  g.TreesitterContextBottom = { underline = true, sp = c.ui2 }
  g.TreesitterContextLineNumberBottom = { fg = c.tx3, underline = true, sp = c.ui2 }

  -- debugger
  g.DapBreakpoint = { fg = c.re }
  g.DapBreakpointCondition = { fg = c.ye }
  g.DapLogPoint = { fg = c.bl }
  g.DapBreakpointRejected = { fg = c.tx3 }
  g.DapStopped = { fg = c.ye }
  g.DapStoppedLine = { bg = c.tint.ye }
  g.NvimDapVirtualText = { fg = c.tx2, italic = true }
  g.NvimDapVirtualTextChanged = { fg = c.ye, italic = true }
  g.NvimDapVirtualTextError = { fg = c.re, italic = true }
  g.NvimDapVirtualTextInfo = { fg = c.bl, italic = true }
  local dapui = {
    Scope = { fg = c.bl, bold = true }, Type = { fg = c['or'] }, Variable = { fg = c.tx },
    Value = { fg = c.cy }, ModifiedValue = { fg = c.ye, bold = true }, Decoration = { fg = c.tx3 },
    Thread = { fg = c.gr }, StoppedThread = { fg = c.bl }, Source = { fg = c.pu },
    LineNumber = { fg = c.tx3 }, FloatBorder = { fg = c.ui3 }, WatchesEmpty = { fg = c.tx3 },
    WatchesValue = { fg = c.cy }, WatchesError = { fg = c.re }, BreakpointsPath = { fg = c.bl },
    BreakpointsInfo = { fg = c.gr }, BreakpointsCurrentLine = { fg = c.gr, bold = true },
    BreakpointsLine = { fg = c.tx3 }, BreakpointsDisabledLine = { fg = c.ui3 },
    CurrentFrameName = { fg = c.gr, bold = true }, Frame = { fg = c.tx }, WinSelect = { fg = c['or'], bold = true },
    EndofBuffer = { fg = c.bg }, Normal = { fg = c.tx, bg = c.bg },
  }
  for name, spec in pairs(dapui) do g['DapUI' .. name] = spec end
  -- debugger toolbar (in the console's window bar)
  for name, color in pairs({
    PlayPause = c.gr, Restart = c.gr, Stop = c.re, Unavailable = c.ui3,
    StepOver = c.bl, StepInto = c.bl, StepBack = c.bl, StepOut = c.bl,
  }) do
    g['DapUI' .. name] = { fg = color, bg = c.bg }
    g['DapUI' .. name .. 'NC'] = { fg = color, bg = c.bg }
  end

  -- neotest
  g.NeotestPassed = { fg = c.gr }
  g.NeotestFailed = { fg = c.re }
  g.NeotestRunning = { fg = c.ye }
  g.NeotestSkipped = { fg = c.tx3 }
  g.NeotestUnknown = { fg = c.tx2 }
  g.NeotestWatching = { fg = c.ye }
  g.NeotestTest = { fg = c.tx }
  g.NeotestNamespace = { fg = c['or'] }
  g.NeotestFile = { fg = c.tx }
  g.NeotestDir = { fg = c.bl }
  g.NeotestFocused = { bold = true, underline = true }
  g.NeotestAdapterName = { fg = c.tx2, bold = true }
  g.NeotestIndent = { fg = c.ui3 }
  g.NeotestExpandMarker = { fg = c.ui3 }
  g.NeotestWinSelect = { fg = c['or'], bold = true }
  g.NeotestMarked = { fg = c.ma, bold = true }
  g.NeotestTarget = { fg = c.re }

  -- lazy.nvim, Mason
  g.LazyNormal = { link = 'NormalFloat' }
  g.LazyH1 = { fg = c.bg, bg = c['or'], bold = true }
  g.LazyH2 = { fg = c.tx, bold = true }
  g.LazyButton = { fg = c.tx2, bg = c.ui }
  g.LazyButtonActive = { fg = c.tx, bg = c.ui2, bold = true }
  g.LazySpecial = { fg = c['or'] }
  g.LazyProgressDone = { fg = c.gr }
  g.LazyProgressTodo = { fg = c.ui2 }
  g.LazyReasonPlugin = { fg = c.ma }
  g.LazyReasonEvent = { fg = c.ye }
  g.LazyReasonKeys = { fg = c.cy }
  g.LazyReasonCmd = { fg = c.bl }
  g.LazyReasonFt = { fg = c.pu }
  g.LazyReasonStart = { fg = c.gr }
  g.LazyCommit = { fg = c.tx3 }
  g.LazyDimmed = { fg = c.tx3 }
  g.MasonNormal = { link = 'NormalFloat' }
  g.MasonHeader = { fg = c.bg, bg = c['or'], bold = true }
  g.MasonHighlight = { fg = c.bl }
  g.MasonHighlightBlock = { fg = c.bg, bg = c.bl }
  g.MasonHighlightBlockBold = { fg = c.bg, bg = c.bl, bold = true }
  g.MasonHighlightSecondary = { fg = c.ye }
  g.MasonHighlightBlockSecondary = { fg = c.bg, bg = c.ye }
  g.MasonHighlightBlockBoldSecondary = { fg = c.bg, bg = c.ye, bold = true }
  g.MasonMuted = { fg = c.tx2 }
  g.MasonMutedBlock = { fg = c.tx2, bg = c.ui }
  g.MasonMutedBlockBold = { fg = c.tx, bg = c.ui2, bold = true }
  g.MasonError = { fg = c.re }
  g.MasonWarning = { fg = c.ye }
  g.MasonHeading = { bold = true }

  -- fidget (LSP progress), grug-far, todo-comments' fallback groups
  g.FidgetTitle = { fg = c.tx2, bold = true }
  g.FidgetTask = { fg = c.tx3 }
  g.GrugFarResultsMatch = { fg = c.bg, bg = c.ye }
  g.GrugFarResultsMatchAdded = { bg = c.wash.gr }
  g.GrugFarResultsMatchRemoved = { bg = c.wash.re, strikethrough = true }
  g.GrugFarResultsPath = { fg = c.bl }
  g.GrugFarResultsLineNr = { fg = c.tx3 }
  g.GrugFarInputLabel = { fg = c.tx2 }
  g.GrugFarHelpHeader = { fg = c.tx3 }

  -- assembly view (lua/ide/asm.lua): lines produced by the source line under the cursor
  g.IdeAsmMatch = { bg = c.tint.bl }
  g.IdeAsmLabel = { fg = c['or'], bold = true }

  -- checkhealth
  g.healthError = { fg = c.re }
  g.healthWarning = { fg = c.ye }
  g.healthSuccess = { fg = c.gr }

  return g
end

--- ANSI colours for :terminal (lazygit, shells, test output). Derived from the
--- palette the way stephango.com recommends: 400 accents on dark, 600 on light.
local function terminal_colors(c)
  local p = palette
  local function scale(n) return { p.red[n], p.green[n], p.yellow[n], p.blue[n], p.magenta[n], p.cyan[n] } end
  local normal, bright, ansi
  if c.variant == 'dark' then
    normal, bright = scale(400), scale(300)
    ansi = { [0] = c.ui2, [7] = c.tx2, [8] = c.tx3, [15] = c.tx }
  else
    normal, bright = scale(600), scale(400)
    ansi = { [0] = c.tx, [7] = c.ui3, [8] = c.tx2, [15] = c.bg2 }
  end
  for i = 1, 6 do
    ansi[i], ansi[i + 8] = normal[i], bright[i]
  end
  for i = 0, 15 do vim.g['terminal_color_' .. i] = ansi[i] end
end

--- Tell the terminal (Windows Terminal, …) to use Flexoki's background too, so
--- its padding around Neovim matches. Reset when Neovim exits / suspends.
local function sync_terminal(c)
  if vim.g.flexoki_sync_terminal == false or not vim.api.nvim_ui_send or #vim.api.nvim_list_uis() == 0 then return end
  pcall(vim.api.nvim_ui_send, ('\027]11;%s\027\\'):format(c.bg))
  if M._synced then return end
  M._synced = true
  local group = vim.api.nvim_create_augroup('flexoki_terminal', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimLeavePre', 'VimSuspend' }, {
    group = group,
    callback = function() pcall(vim.api.nvim_ui_send, '\027]111\027\\') end, -- back to the profile's colour
  })
  vim.api.nvim_create_autocmd('VimResume', {
    group = group,
    callback = function()
      if vim.g.colors_name == 'flexoki' then sync_terminal(palette.roles(vim.o.background)) end
    end,
  })
end

--- Apply the colour scheme for the current 'background'. (colors/flexoki.lua)
function M.load()
  if vim.g.colors_name then vim.cmd('highlight clear') end
  vim.g.colors_name = 'flexoki'
  local c = palette.roles(vim.o.background)
  local set = vim.api.nvim_set_hl
  for name, spec in pairs(M.groups(c)) do set(0, name, spec) end
  terminal_colors(c)
  sync_terminal(c)
end

--- lualine theme: rounded bubbles. One accent per mode on the end bubbles, a
--- quiet bubble for the file, the editor background between. A function, so
--- lualine rebuilds it when the background flips.
function M.lualine()
  local c = palette.roles(vim.o.background)
  local function mode(color)
    return {
      a = { fg = c.bg, bg = color, gui = 'bold' },
      b = { fg = c.tx, bg = c.ui },
      c = { fg = c.tx2, bg = c.bg },
    }
  end
  return {
    normal = mode(c.gr),
    insert = mode(c.ye),
    visual = mode(c['or']),
    replace = mode(c.re),
    command = mode(c.bl),
    terminal = mode(c.cy),
    inactive = { a = { fg = c.tx3, bg = c.ui }, b = { fg = c.tx3, bg = c.bg }, c = { fg = c.tx3, bg = c.bg } },
  }
end

--- 'dark' or 'light'
function M.set(variant)
  if variant ~= 'dark' and variant ~= 'light' then
    return vim.notify('Flexoki: dark or light', vim.log.levels.WARN)
  end
  if vim.g.colors_name ~= 'flexoki' then vim.cmd.colorscheme('flexoki') end
  vim.o.background = variant -- Neovim reloads the colour scheme on this; plugins follow via ColorScheme
end

function M.toggle() M.set(vim.o.background == 'dark' and 'light' or 'dark') end

--- Startup: restore the last light / dark choice and load the scheme.
function M.setup()
  local ok, saved = pcall(vim.fn.readfile, state_file)
  -- set explicitly, so Neovim's terminal-colour detection leaves it alone
  vim.o.background = (ok and saved[1] == 'light') and 'light' or 'dark'
  vim.cmd.colorscheme('flexoki')

  vim.api.nvim_create_autocmd('OptionSet', {
    group = vim.api.nvim_create_augroup('flexoki_remember', { clear = true }),
    pattern = 'background',
    callback = function()
      if vim.g.colors_name == 'flexoki' then pcall(vim.fn.writefile, { vim.o.background }, state_file) end
    end,
  })
  vim.api.nvim_create_user_command('Flexoki', function(cmd)
    if cmd.args == '' or cmd.args == 'toggle' then M.toggle() else M.set(cmd.args) end
  end, {
    nargs = '?',
    complete = function() return { 'toggle', 'dark', 'light' } end,
    desc = 'Flexoki: toggle / dark / light',
  })
end

return M
