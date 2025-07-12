@echo off
setlocal enabledelayedexpansion
REM Script to wait for AWS resources to be deleted - CRASH-FREE VERSION

echo ELI5 Discord Bot - Wait for Resource Deletion
echo ==========================================
echo.
echo This script will wait for AWS resources to be deleted before proceeding with deployment.
echo.

REM Check if AWS CLI is installed
where aws >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo AWS CLI is not installed. Please install it first:
    echo https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    exit /b 1
)

REM Set AWS region directly to avoid command substitution issues
set AWS_REGION=eu-west-3
echo AWS Region: %AWS_REGION%

REM Check if Discord secret exists
echo.
echo Checking if Discord secret exists...
aws secretsmanager describe-secret --secret-id eli5-discord-bot/discord-credentials-dev --region %AWS_REGION% >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Discord secret exists.
    set DISCORD_EXISTS=true
) else (
    echo Discord secret does not exist.
    set DISCORD_EXISTS=false
)

REM Check if OpenAI secret exists
echo.
echo Checking if OpenAI secret exists...
aws secretsmanager describe-secret --secret-id eli5-discord-bot/openai-credentials-dev --region %AWS_REGION% >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo OpenAI secret exists.
    set OPENAI_EXISTS=true
) else (
    echo OpenAI secret does not exist.
    set OPENAI_EXISTS=false
)

REM Check if ECR repository exists
echo.
echo Checking if ECR repository exists...
aws ecr describe-repositories --repository-names eli5-discord-bot-dev --region %AWS_REGION% >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ECR repository exists.
    set ECR_EXISTS=true
) else (
    echo ECR repository does not exist.
    set ECR_EXISTS=false
)

REM If any resources exist, ask the user what to do
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

if "%RESOURCES_EXIST%"=="true" (
    echo.
    echo Some resources already exist.
    echo You have the following options:
    echo 1. Wait and try again later
    echo 2. Run the force cleanup script
    echo 3. Proceed with deployment anyway
    echo.
    
    :CHOICE_LOOP
    set /p CHOICE="Enter your choice (1, 2, or 3): "
    
    REM Trim all whitespace from choice using delayed expansion
    set "CHOICE=!CHOICE: =!"
    
    if "!CHOICE!"=="1" (
        echo.
        echo Please wait and try again later.
        echo You may need to manually clean up existing resources.
        echo.
        pause
        exit /b 0
    ) else if "!CHOICE!"=="2" (
        echo.
        echo Please run the force cleanup script manually:
        echo bash ./force_cleanup.sh
        echo.
        pause
        exit /b 0
    ) else if "!CHOICE!"=="3" (
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
        exit /b 0
    ) else (
        echo.
        echo Invalid choice "!CHOICE!". Please enter 1, 2, or 3.
        echo.
        goto CHOICE_LOOP
    )
) else (
    echo.
    echo No resources exist.
    echo You can proceed with deployment.
    echo.
)

echo Script completed.
echo.
