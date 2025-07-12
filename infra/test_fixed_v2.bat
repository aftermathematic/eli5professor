@echo off
echo Testing the fixed v2 script with simulated choice 3...
echo.

REM Simulate the environment where resources exist
set DISCORD_EXISTS=true
set OPENAI_EXISTS=true
set ECR_EXISTS=true

REM Test the choice handling by directly setting the choice
echo 3 | .\wait_for_deletion_fixed_v2.bat

echo.
echo Test completed. Check the output above to see if choice 3 was handled correctly.
pause
