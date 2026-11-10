@echo off
rem Sets up PATH and Neovim's folders for this portable setup (used by nvim.cmd and shell.cmd).
set "NVIM_PORTABLE=%~dp0"
set "NVIM_PORTABLE=%NVIM_PORTABLE:~0,-1%"
set "XDG_CONFIG_HOME=%NVIM_PORTABLE%\config"
set "XDG_DATA_HOME=%NVIM_PORTABLE%\data"
set "XDG_STATE_HOME=%NVIM_PORTABLE%\state"
set "XDG_CACHE_HOME=%NVIM_PORTABLE%\cache"
set "PATH=%NVIM_PORTABLE%\nvim\bin;%NVIM_PORTABLE%\w64devkit\bin;%NVIM_PORTABLE%\clangd\bin;%NVIM_PORTABLE%\tools;%PATH%"
