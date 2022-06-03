cls
@echo off

zig build run -Drelease-small

set "file=zig-out/bin/qove.exe"
FOR %%A IN (%file%) DO echo %%~zA bytes
