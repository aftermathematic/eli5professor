@echo off
echo Testing the final fixed wait_for_deletion.bat script...
echo.

REM Test with simulated choice 3
echo 3 | .\wait_for_deletion.bat

echo.
echo Test completed. The script should have handled choice 3 correctly.
pause
