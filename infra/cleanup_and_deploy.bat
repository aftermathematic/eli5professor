@echo off
setlocal enabledelayedexpansion

echo ELI5 Discord Bot - Cleanup and Deploy
echo =====================================
echo.
echo This script will clean up existing resources and deploy fresh infrastructure.
echo.

REM Check if AWS CLI is installed
where aws >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo AWS CLI is not installed. Please install it first:
    echo https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    exit /b 1
)

REM Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo PowerShell is not available. This script requires PowerShell.
    exit /b 1
)

echo Step 1: Clean up existing AWS resources
echo ======================================
echo.
echo The following resources will be force deleted:
echo - Discord credentials secret
echo - OpenAI credentials secret  
echo - ECR repository
echo - S3 bucket contents
echo.
set /p CLEANUP_CONFIRM="Do you want to proceed with cleanup? (y/n): "

if /i "!CLEANUP_CONFIRM!"=="y" (
    echo.
    echo Running force cleanup...
    powershell -ExecutionPolicy Bypass -File "force_delete_resources.ps1"
    
    if %ERRORLEVEL% neq 0 (
        echo.
        echo Cleanup failed. Please check the error messages above.
        echo You may need to manually clean up resources in the AWS Console.
        pause
        exit /b 1
    )
    
    echo.
    echo Cleanup completed. Waiting 10 seconds for AWS to propagate changes...
    timeout /t 10 /nobreak >nul
    
) else (
    echo.
    echo Cleanup skipped. Proceeding with deployment anyway...
    echo Note: Deployment may fail if conflicting resources exist.
)

echo.
echo Step 2: Deploy infrastructure
echo =============================
echo.
echo Starting deployment process...

REM Set flag to indicate we're running automated deployment
set DEPLOY_ALL_RUNNING=1

REM Run the deployment
call deploy_all.bat

if %ERRORLEVEL% neq 0 (
    echo.
    echo Deployment failed. Error level: %ERRORLEVEL%
    echo.
    echo If you see resource conflicts, you may need to:
    echo 1. Run this script again and choose 'y' for cleanup
    echo 2. Manually delete conflicting resources in AWS Console
    echo 3. Wait longer for AWS resource deletion to propagate
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ✅ Cleanup and deployment completed successfully!
echo.
echo Your ELI5 Discord Bot infrastructure is now deployed.
echo.
pause
