@echo off
REM Simple debug script to capture deployment issues

echo ELI5 Discord Bot - Deployment Debug Script
echo ==========================================
echo.
echo This script will capture detailed information about deployment issues.
echo.

REM Create a debug log file with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set DEBUG_LOG=debug_deployment_%TIMESTAMP%.log

echo Creating debug log: %DEBUG_LOG%
echo.

echo ======================================== > %DEBUG_LOG%
echo DEPLOYMENT DEBUG LOG >> %DEBUG_LOG%
echo Generated: %date% %time% >> %DEBUG_LOG%
echo ======================================== >> %DEBUG_LOG%
echo. >> %DEBUG_LOG%

echo [SYSTEM INFO] >> %DEBUG_LOG%
echo OS: %OS% >> %DEBUG_LOG%
echo Processor: %PROCESSOR_ARCHITECTURE% >> %DEBUG_LOG%
echo User: %USERNAME% >> %DEBUG_LOG%
echo Current Directory: %CD% >> %DEBUG_LOG%
echo. >> %DEBUG_LOG%

echo [PATH INFORMATION] >> %DEBUG_LOG%
echo PATH=%PATH% >> %DEBUG_LOG%
echo. >> %DEBUG_LOG%

echo [AWS CLI CHECK] >> %DEBUG_LOG%
where aws >> %DEBUG_LOG% 2>&1
if %ERRORLEVEL% equ 0 (
    aws --version >> %DEBUG_LOG% 2>&1
    aws configure list >> %DEBUG_LOG% 2>&1
    aws sts get-caller-identity >> %DEBUG_LOG% 2>&1
) else (
    echo AWS CLI not found in PATH >> %DEBUG_LOG%
)
echo. >> %DEBUG_LOG%

echo [TERRAFORM CHECK] >> %DEBUG_LOG%
where terraform >> %DEBUG_LOG% 2>&1
if %ERRORLEVEL% equ 0 (
    terraform version >> %DEBUG_LOG% 2>&1
) else (
    echo Terraform not found in PATH >> %DEBUG_LOG%
)
echo. >> %DEBUG_LOG%

echo [DIRECTORY CONTENTS] >> %DEBUG_LOG%
echo Contents of current directory: >> %DEBUG_LOG%
dir /b >> %DEBUG_LOG%
echo. >> %DEBUG_LOG%

echo [TERRAFORM STATE] >> %DEBUG_LOG%
if exist ".terraform" (
    echo .terraform directory exists >> %DEBUG_LOG%
    dir .terraform /b >> %DEBUG_LOG% 2>&1
) else (
    echo .terraform directory does not exist >> %DEBUG_LOG%
)
echo. >> %DEBUG_LOG%

if exist ".terraform.lock.hcl" (
    echo .terraform.lock.hcl exists >> %DEBUG_LOG%
) else (
    echo .terraform.lock.hcl does not exist >> %DEBUG_LOG%
)
echo. >> %DEBUG_LOG%

if exist "terraform.tfstate" (
    echo terraform.tfstate exists >> %DEBUG_LOG%
) else (
    echo terraform.tfstate does not exist >> %DEBUG_LOG%
)
echo. >> %DEBUG_LOG%

echo [AWS RESOURCES CHECK] >> %DEBUG_LOG%
echo Checking Discord secret... >> %DEBUG_LOG%
aws secretsmanager describe-secret --secret-id eli5-discord-bot/discord-credentials-dev --region eu-west-3 >> %DEBUG_LOG% 2>&1
echo. >> %DEBUG_LOG%
echo Checking OpenAI secret... >> %DEBUG_LOG%
aws secretsmanager describe-secret --secret-id eli5-discord-bot/openai-credentials-dev --region eu-west-3 >> %DEBUG_LOG% 2>&1
echo. >> %DEBUG_LOG%
echo Checking ECR repository... >> %DEBUG_LOG%
aws ecr describe-repositories --repository-names eli5-discord-bot-dev --region eu-west-3 >> %DEBUG_LOG% 2>&1
echo. >> %DEBUG_LOG%

echo [ENVIRONMENT VARIABLES] >> %DEBUG_LOG%
echo DEPLOY_ALL_RUNNING=%DEPLOY_ALL_RUNNING% >> %DEBUG_LOG%
echo AWS_REGION=%AWS_REGION% >> %DEBUG_LOG%
echo. >> %DEBUG_LOG%

echo ======================================== >> %DEBUG_LOG%
echo DEBUG LOG COMPLETE >> %DEBUG_LOG%
echo ======================================== >> %DEBUG_LOG%

echo.
echo Debug information saved to: %DEBUG_LOG%
echo.
echo Now let's also show you the key information on screen:
echo.

echo [CURRENT STATUS]
echo Current Directory: %CD%
echo.

echo [AWS CLI STATUS]
where aws
if %ERRORLEVEL% equ 0 (
    echo AWS CLI found
    aws --version
) else (
    echo [ERROR] AWS CLI not found in PATH
)
echo.

echo [TERRAFORM STATUS]
where terraform
if %ERRORLEVEL% equ 0 (
    echo Terraform found
    terraform version
) else (
    echo [ERROR] Terraform not found in PATH
)
echo.

echo [TERRAFORM FILES]
if exist "main.tf" (
    echo main.tf exists
) else (
    echo [ERROR] main.tf not found
)
echo.

echo [TERRAFORM INITIALIZATION]
if exist ".terraform" (
    echo .terraform directory exists
) else (
    echo [WARNING] .terraform directory does not exist - terraform not initialized
)
echo.

echo To see the full debug log, run: type %DEBUG_LOG%
echo.
pause
