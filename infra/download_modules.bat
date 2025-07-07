@echo off
REM Script to manually download Terraform modules

echo ELI5 Twitter Bot - Download Terraform Modules
echo ===========================================
echo.
echo This script will manually download Terraform modules to fix initialization issues.
echo.

REM Check if Terraform is installed
where terraform >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Terraform is not installed. Please install it first:
    echo https://developer.hashicorp.com/terraform/downloads
    exit /b 1
)

REM Create the modules directory structure
echo Creating modules directory structure...
mkdir .terraform\modules 2>nul

REM Function to download a module
:download_module
echo.
echo Downloading module: %1
echo Source: %2
    
REM Create the module directory
mkdir .terraform\modules\%1 2>nul
    
REM Copy the module files
xcopy /E /I /Y %2\* .terraform\modules\%1\
    
echo Module %1 downloaded to .terraform\modules\%1
exit /b 0

REM Download the modules
call :download_module model_bucket modules\s3-bucket
call :download_module app_repository modules\ecr-repository
call :download_module twitter_bot_service modules\apprunner-service
call :download_module api_service modules\apprunner-service
call :download_module twitter_bot_lambda modules\lambda-function
call :download_module api_lambda modules\lambda-function

REM Create a modules.json file
echo Creating modules.json file...
(
echo {
echo   "Modules": [
echo     {
echo       "Key": "model_bucket",
echo       "Source": "./modules/s3-bucket",
echo       "Dir": "modules/s3-bucket"
echo     },
echo     {
echo       "Key": "app_repository",
echo       "Source": "./modules/ecr-repository",
echo       "Dir": "modules/ecr-repository"
echo     },
echo     {
echo       "Key": "twitter_bot_service",
echo       "Source": "./modules/apprunner-service",
echo       "Dir": "modules/apprunner-service"
echo     },
echo     {
echo       "Key": "api_service",
echo       "Source": "./modules/apprunner-service",
echo       "Dir": "modules/apprunner-service"
echo     },
echo     {
echo       "Key": "twitter_bot_lambda",
echo       "Source": "./modules/lambda-function",
echo       "Dir": "modules/lambda-function"
echo     },
echo     {
echo       "Key": "api_lambda",
echo       "Source": "./modules/lambda-function",
echo       "Dir": "modules/lambda-function"
echo     }
echo   ]
echo }
) > .terraform\modules\modules.json

echo.
echo ✅ Terraform modules downloaded successfully!
echo.
echo Now try running terraform init again:
echo terraform init
echo.
