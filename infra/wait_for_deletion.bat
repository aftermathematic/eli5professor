@echo off
REM Script to wait for AWS resources to be deleted

echo ELI5 Twitter Bot - Wait for Resource Deletion
echo =========================================
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

REM Get AWS region
for /f "tokens=*" %%a in ('aws configure get region') do set AWS_REGION=%%a
if "%AWS_REGION%"=="" (
    set AWS_REGION=eu-west-3
)
echo AWS Region: %AWS_REGION%

REM Check if Twitter secret is scheduled for deletion
echo.
echo Checking if Twitter secret is scheduled for deletion...
aws secretsmanager describe-secret --secret-id eli5-twitter-bot/twitter-credentials-dev --region %AWS_REGION% >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Twitter secret exists.
    
    REM Check if it's scheduled for deletion
    for /f "tokens=*" %%a in ('aws secretsmanager describe-secret --secret-id eli5-twitter-bot/twitter-credentials-dev --region %AWS_REGION% --query "DeletedDate" --output text') do set TWITTER_DELETED=%%a
    
    if not "%TWITTER_DELETED%"=="None" (
        echo Twitter secret is scheduled for deletion.
        set TWITTER_DELETING=true
    ) else (
        echo Twitter secret is not scheduled for deletion.
        set TWITTER_DELETING=false
    )
) else (
    echo Twitter secret does not exist or cannot be accessed.
    set TWITTER_DELETING=false
)

REM Check if OpenAI secret is scheduled for deletion
echo.
echo Checking if OpenAI secret is scheduled for deletion...
aws secretsmanager describe-secret --secret-id eli5-twitter-bot/openai-credentials-dev --region %AWS_REGION% >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo OpenAI secret exists.
    
    REM Check if it's scheduled for deletion
    for /f "tokens=*" %%a in ('aws secretsmanager describe-secret --secret-id eli5-twitter-bot/openai-credentials-dev --region %AWS_REGION% --query "DeletedDate" --output text') do set OPENAI_DELETED=%%a
    
    if not "%OPENAI_DELETED%"=="None" (
        echo OpenAI secret is scheduled for deletion.
        set OPENAI_DELETING=true
    ) else (
        echo OpenAI secret is not scheduled for deletion.
        set OPENAI_DELETING=false
    )
) else (
    echo OpenAI secret does not exist or cannot be accessed.
    set OPENAI_DELETING=false
)

REM Check if ECR repository exists
echo.
echo Checking if ECR repository exists...
aws ecr describe-repositories --repository-names eli5-twitter-bot-dev --region %AWS_REGION% >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ECR repository exists.
    set ECR_EXISTS=true
) else (
    echo ECR repository does not exist or cannot be accessed.
    set ECR_EXISTS=false
)

REM If any resources are scheduled for deletion, ask the user what to do
if "%TWITTER_DELETING%"=="true" (
    set RESOURCES_DELETING=true
) else if "%OPENAI_DELETING%"=="true" (
    set RESOURCES_DELETING=true
) else if "%ECR_EXISTS%"=="true" (
    set RESOURCES_DELETING=true
) else (
    set RESOURCES_DELETING=false
)

if "%RESOURCES_DELETING%"=="true" (
    echo.
    echo Some resources already exist or are scheduled for deletion.
    echo You have the following options:
    echo 1. Wait for the resources to be deleted (may take up to 30 days for secrets)
    echo 2. Run the force_cleanup.sh script to clean up existing resources
    echo 3. Proceed with deployment anyway (may fail if resources still exist)
    echo.
    set /p CHOICE="Enter your choice (1, 2, or 3): "
    
    if "%CHOICE%"=="1" (
        echo.
        echo Waiting for resources to be deleted...
        
        if "%TWITTER_DELETING%"=="true" (
            echo.
            echo Waiting for Twitter secret to be deleted...
            echo This may take a long time (up to 30 days).
            echo Press Ctrl+C to cancel.
            
            :wait_twitter
            timeout /t 30 >nul
            aws secretsmanager describe-secret --secret-id eli5-twitter-bot/twitter-credentials-dev --region %AWS_REGION% >nul 2>&1
            if %ERRORLEVEL% equ 0 (
                for /f "tokens=*" %%a in ('aws secretsmanager describe-secret --secret-id eli5-twitter-bot/twitter-credentials-dev --region %AWS_REGION% --query "DeletedDate" --output text') do set TWITTER_DELETED=%%a
                
                if not "%TWITTER_DELETED%"=="None" (
                    echo Twitter secret is still scheduled for deletion. Waiting...
                    goto wait_twitter
                ) else (
                    echo Twitter secret is no longer scheduled for deletion.
                )
            ) else (
                echo Twitter secret no longer exists or cannot be accessed. Deletion complete.
            )
        )
        
        if "%OPENAI_DELETING%"=="true" (
            echo.
            echo Waiting for OpenAI secret to be deleted...
            echo This may take a long time (up to 30 days).
            echo Press Ctrl+C to cancel.
            
            :wait_openai
            timeout /t 30 >nul
            aws secretsmanager describe-secret --secret-id eli5-twitter-bot/openai-credentials-dev --region %AWS_REGION% >nul 2>&1
            if %ERRORLEVEL% equ 0 (
                for /f "tokens=*" %%a in ('aws secretsmanager describe-secret --secret-id eli5-twitter-bot/openai-credentials-dev --region %AWS_REGION% --query "DeletedDate" --output text') do set OPENAI_DELETED=%%a
                
                if not "%OPENAI_DELETED%"=="None" (
                    echo OpenAI secret is still scheduled for deletion. Waiting...
                    goto wait_openai
                ) else (
                    echo OpenAI secret is no longer scheduled for deletion.
                )
            ) else (
                echo OpenAI secret no longer exists or cannot be accessed. Deletion complete.
            )
        )
        
        echo.
        echo Resource deletion check complete.
        echo You can now proceed with deployment.
        echo.
    ) else if "%CHOICE%"=="2" (
        echo.
        echo Running force_cleanup.sh script...
        
        REM Check if WSL is available
        where wsl >nul 2>&1
        if %ERRORLEVEL% equ 0 (
            wsl ./force_cleanup.sh
        ) else (
            echo WSL is not available. Please run the force_cleanup.sh script manually in a bash environment.
        )
        
        echo.
        echo Force cleanup complete.
        echo You can now proceed with deployment.
        echo.
    ) else (
        echo.
        echo Proceeding with deployment anyway.
        echo Note that deployment may fail if resources still exist.
        echo.
    )
) else (
    echo.
    echo No resources are scheduled for deletion.
    echo You can proceed with deployment.
    echo.
)

echo Script completed.
echo.
