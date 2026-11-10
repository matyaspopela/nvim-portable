@echo off
rem Portable Neovim + Flexoki + g++ (w64devkit). Nothing is installed: every
rem setting, plugin, undo file and cache lives in this folder.
rem Usage:  nvim.cmd [files]     (drag a file onto it, or run it from a terminal)
setlocal
call "%~dp0env.cmd"
"%NVIM_PORTABLE%\nvim\bin\nvim.exe" %*
