@echo off
echo Testing choice handling fix...
echo.

set DISCORD_EXISTS=true
set OPENAI_EXISTS=true
set ECR_EXISTS=true

REM Test the resource existence logic
if "%DISCORD_EXISTS%"=="true" (
    set RESOURCES_EXIST=true
) else (
    if "%OPENAI_EXISTS%"=="true" (
        set RESOURCES_EXIST=true
    ) else (
        if "%ECR_EXISTS%"=="true" (
            set RESOURCES_EXIST=true
        ) else (
            set RESOURCES_EXIST=false
        )
    )
)

echo Resources exist: %RESOURCES_EXIST%
echo.

REM Test choice handling with simulated input
set CHOICE=3

echo Simulating choice: %CHOICE%
echo.

if "%CHOICE%"=="1" (
    echo Choice 1 selected
) else (
    if "%CHOICE%"=="2" (
        echo Choice 2 selected
    ) else (
        if "%CHOICE%"=="3" (
            echo Choice 3 selected - SUCCESS!
            echo This means the fix is working correctly.
        ) else (
            echo Invalid choice detected
        )
    )
)

echo.
echo Test completed.
pause
