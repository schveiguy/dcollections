@echo off
for %%i in (*.d) do dmd %%i -L+..\dcollections.lib -I..
