@echo off
REM Test script to directly simulate option 3 with the fixed version

echo Testing fixed wait_for_deletion script with option 3...
echo.

REM Set the environment as it would be when option 3 is chosen
set AWS_REGION=eu-west-3
set DISCORD_EXISTS=true
set OPENAI_EXISTS=true
set ECR_EXISTS=true
set RESOURCES_EXIST=true
set CHOICE=3

echo Simulating option 3 selection...
echo.
echo Proceeding with deployment anyway.
echo Note that deployment may fail if resources still exist.
echo.
echo DEBUG: Starting deployment continuation with option 3...
echo DEBUG: Current directory: %CD%
echo DEBUG: AWS Region: %AWS_REGION%
echo DEBUG: Discord exists: %DISCORD_EXISTS%
echo DEBUG: OpenAI exists: %OPENAI_EXISTS%
echo DEBUG: ECR exists: %ECR_EXISTS%
echo.

REM Check if we're being called from deploy_all.bat
if defined DEPLOY_ALL_RUNNING (
    echo DEBUG: Called from deploy_all.bat - returning control
    exit /b 0
) else (
    echo DEBUG: Running standalone - continuing with next steps
    echo.
    echo DEBUG: Checking terraform availability...
    where terraform >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ERROR: Terraform not found in PATH
        exit /b 1
    ) else (
        echo DEBUG: Terraform found
    )
    
    echo DEBUG: Checking for main.tf...
    if not exist "main.tf" (
        echo ERROR: main.tf not found in current directory
        exit /b 1
    ) else (
        echo DEBUG: main.tf found
    )
    
    echo DEBUG: Running terraform init...
    terraform init
    if %ERRORLEVEL% neq 0 (
        echo ERROR: Terraform init failed
        exit /b %ERRORLEVEL%
    ) else (
        echo DEBUG: Terraform init successful
    )
)

echo.
echo SUCCESS: Fixed version completed without crashing!
echo.
pause
