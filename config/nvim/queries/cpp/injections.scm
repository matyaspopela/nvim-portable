; extends

; SQL inside C++ raw strings. Neovim's own rule already covers R"sql(...)sql"
; (the delimiter names the language). This adds plain R"(...)" strings whose
; text is an SQL statement, so no delimiter is needed:
;   auto q = R"(SELECT id, name FROM users WHERE id = ?)";
; #sql-raw? is defined in lua/plugins/treesitter.lua.
((raw_string_literal
  (raw_string_content) @injection.content)
  (#sql-raw? @injection.content)
  (#set! injection.language "sql"))
