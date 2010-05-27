@echo off
setlocal EnableDelayedExpansion
set "files="
for %%i in (dcollections\*.d dcollections\model\*.d) do set files=!files! %%i
echo %1
if %1 == unittest goto unittest
@echo on
dmd -lib -ofdcollections.lib %files%
@goto end
:unittest
echo void main(^){} > unit_test.d
@echo on
dmd -unittest unit_test.d %files%
@echo off
echo running unit tests...
.\unit_test
del unit_test.d
:end
