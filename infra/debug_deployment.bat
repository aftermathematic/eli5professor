@echo off
REM Debug script to capture deployment issues

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

REM Redirect all output to both console and log file
(
echo ========================================
echo DEPLOYMENT DEBUG LOG
echo Generated: %date% %time%
echo ========================================
echo.

echo [SYSTEM INFO]
echo OS: %OS%
echo Processor: %PROCESSOR_ARCHITECTURE%
echo User: %USERNAME%
echo Current Directory: %CD%
echo.

echo [PATH INFORMATION]
echo PATH=%PATH%
echo.

echo [AWS CLI CHECK]
where aws
if %ERRORLEVEL% equ 0 (
    aws --version
    aws configure list
    aws sts get-caller-identity
) else (
    echo AWS CLI not found in PATH
)
echo.

echo [TERRAFORM CHECK]
where terraform
if %ERRORLEVEL% equ 0 (
    terraform version
) else (
    echo Terraform not found in PATH
)
echo.

echo [DIRECTORY CONTENTS]
echo Contents of current directory:
dir /b
echo.
echo Contents of infra directory:
if exist "infra" (
    dir infra /b
) else (
    echo infra directory not found
)
echo.

echo [TERRAFORM STATE]
if exist ".terraform" (
    echo .terraform directory exists
    dir .terraform /b
) else (
    echo .terraform directory does not exist
)
echo.
if exist ".terraform.lock.hcl" (
    echo .terraform.lock.hcl exists
) else (
    echo .terraform.lock.hcl does not exist
)
echo.
if exist "terraform.tfstate" (
    echo terraform.tfstate exists
) else (
    echo terraform.tfstate does not exist
)
echo.

echo [AWS RESOURCES CHECK]
echo Checking Discord secret...
aws secretsmanager describe-secret --secret-id eli5-discord-bot/discord-credentials-dev --region eu-west-3 2>&1
echo.
echo Checking OpenAI secret...
aws secretsmanager describe-secret --secret-id eli5-discord-bot/openai-credentials-dev --region eu-west-3 2>&1
echo.
echo Checking ECR repository...
aws ecr describe-repositories --repository-names eli5-discord-bot-dev --region eu-west-3 2>&1
echo.

echo [ENVIRONMENT VARIABLES]
echo DEPLOY_ALL_RUNNING=%DEPLOY_ALL_RUNNING%
echo AWS_REGION=%AWS_REGION%
echo.

echo [RECENT ERRORS]
echo Checking Windows Event Log for recent errors...
wevtutil qe Application /c:5 /rd:true /f:text /q:"*[System[Level=2]]" 2>nul
echo.

echo ========================================
echo DEBUG LOG COMPLETE
echo ========================================
) 2>&1 | tee %DEBUG_LOG%

echo.
echo Debug information saved to: %DEBUG_LOG%
echo Please share this log file when reporting the deployment crash issue.
echo.
pause
