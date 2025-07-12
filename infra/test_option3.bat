@echo off
REM Test script to simulate option 3 directly

echo Testing option 3 directly...
echo.

REM Set the variables as they would be set by the main script
set AWS_REGION=eu-west-3
set DISCORD_DELETING=false
set OPENAI_DELETING=false
set ECR_EXISTS=true
set CHOICE=3

echo [DEBUG] Starting deployment continuation with option 3...
echo [DEBUG] Current directory: %CD%
echo [DEBUG] AWS Region: %AWS_REGION%
echo [DEBUG] Discord secret deleting: %DISCORD_DELETING%
echo [DEBUG] OpenAI secret deleting: %OPENAI_DELETING%
echo [DEBUG] ECR exists: %ECR_EXISTS%
echo.

REM Log environment variables for debugging
echo [DEBUG] Environment variables:
echo [DEBUG] PATH length: %PATH:~0,50%...
echo [DEBUG] ERRORLEVEL=%ERRORLEVEL%
echo.

REM Check if we're being called from deploy_all.bat
if defined DEPLOY_ALL_RUNNING (
    echo [DEBUG] Called from deploy_all.bat - returning control
    exit /b 0
) else (
    echo [DEBUG] Running standalone - continuing with next steps
    
    REM Try to continue with the next deployment step
    echo [DEBUG] Attempting to continue deployment...
    
    REM Check if terraform is available
    where terraform >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Terraform not found in PATH
        echo [DEBUG] PATH contains problematic characters - check manually
        exit /b 1
    ) else (
        echo [DEBUG] Terraform found
    )
    
    REM Check if we have terraform files
    if not exist "main.tf" (
        echo [ERROR] main.tf not found in current directory
        echo [DEBUG] Current directory contents:
        dir /b
        exit /b 1
    ) else (
        echo [DEBUG] main.tf found
    )
    
    REM Try to run terraform init
    echo [DEBUG] Running terraform init...
    terraform init
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Terraform init failed with error level %ERRORLEVEL%
        exit /b %ERRORLEVEL%
    ) else (
        echo [DEBUG] Terraform init successful
    )
)

echo.
echo Test completed successfully!
pause
