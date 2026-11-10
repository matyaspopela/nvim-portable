@echo off
rem A command prompt where g++, gcc, make, cmake, gdb, nvim and rg work.
call "%~dp0env.cmd"
cd /d "%USERPROFILE%"
echo Portable dev shell: g++, gcc, make, cmake, ninja, gdb, nvim
cmd /k
