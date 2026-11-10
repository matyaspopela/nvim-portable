@echo off
rem Font + Windows Terminal profiles + clangd config for this portable Neovim
rem (your user only, no admin).
rem   setup-terminal.cmd            install
rem   setup-terminal.cmd uninstall  remove them again
setlocal
call "%~dp0env.cmd"
"%NVIM_PORTABLE%\nvim\bin\nvim.exe" --clean -l "%NVIM_PORTABLE%\tools\setup-terminal.lua" %*
echo.
pause
