@echo off
REM Script to package Lambda functions and upload them to S3

echo ELI5 Discord Bot - Package Lambda Functions
echo ==========================================
echo.
echo This script will package Lambda functions and upload them to S3.
echo.

REM Check if AWS CLI is installed
where aws >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo AWS CLI is not installed. Please install it first:
    echo https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    exit /b 1
)

REM Check if S3 bucket exists
echo Checking if S3 bucket exists...
REM Make sure we're in the infra directory to get the correct Terraform output
set CURRENT_DIR=%CD%
cd %~dp0
for /f "tokens=*" %%i in ('terraform output -raw s3_bucket_id 2^>nul') do set S3_BUCKET=%%i
cd %CURRENT_DIR%

if "%S3_BUCKET%"=="" (
    echo S3 bucket name not found in Terraform outputs. Make sure you've deployed the base infrastructure first.
    echo Run the following commands to deploy the base infrastructure:
    echo cd infra
    echo terraform plan -var-file=dev.tfvars -target=module.model_bucket -out tfplan
    echo terraform apply "tfplan"
    exit /b 1
)

echo S3 bucket name: %S3_BUCKET%

REM Create a temporary directory for packaging
echo Creating temporary directory for packaging...
set TEMP_DIR=%TEMP%\lambda_package
if exist %TEMP_DIR% rmdir /s /q %TEMP_DIR%
mkdir %TEMP_DIR%
echo Temporary directory: %TEMP_DIR%

REM Package the Discord bot Lambda function
echo.
echo Packaging Discord bot Lambda function...
echo -------------------------------------

REM Copy source files
echo Copying source files...
xcopy /E /I /Y "%~dp0..\src\*" %TEMP_DIR%\
copy /Y "%~dp0lambda_requirements\discord_bot_requirements.txt" %TEMP_DIR%\requirements.txt

REM Install dependencies
echo Installing dependencies...
cd %TEMP_DIR%
pip install -r requirements.txt -t . --no-cache-dir --upgrade

REM Remove unnecessary files to reduce package size
echo Removing unnecessary files to reduce package size...
REM Remove tests directories
for /d /r %TEMP_DIR% %%d in (tests) do if exist "%%d" rmdir /s /q "%%d"
for /d /r %TEMP_DIR% %%d in (test) do if exist "%%d" rmdir /s /q "%%d"
REM Remove documentation
for /d /r %TEMP_DIR% %%d in (docs) do if exist "%%d" rmdir /s /q "%%d"
for /d /r %TEMP_DIR% %%d in (doc) do if exist "%%d" rmdir /s /q "%%d"
REM Remove examples
for /d /r %TEMP_DIR% %%d in (examples) do if exist "%%d" rmdir /s /q "%%d"
REM Remove __pycache__ directories
for /d /r %TEMP_DIR% %%d in (__pycache__) do if exist "%%d" rmdir /s /q "%%d"
REM Remove .pyc files
del /s /q %TEMP_DIR%\*.pyc
REM Remove .dist-info directories
for /d /r %TEMP_DIR% %%d in (*.dist-info) do if exist "%%d" rmdir /s /q "%%d"
REM Remove .egg-info directories
for /d /r %TEMP_DIR% %%d in (*.egg-info) do if exist "%%d" rmdir /s /q "%%d"

REM Create the zip file
echo Creating zip file...
powershell -Command "& {Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%TEMP_DIR%\discord_bot.zip' -Force}"

REM Upload to S3
echo Uploading to S3...
aws s3 cp %TEMP_DIR%\discord_bot.zip s3://%S3_BUCKET%/lambda/discord_bot.zip

if %ERRORLEVEL% neq 0 (
    echo Failed to upload Discord bot Lambda function to S3.
    exit /b 1
)

echo Discord bot Lambda function uploaded to S3.

REM Package the API Lambda function
echo.
echo Packaging API Lambda function...
echo -----------------------------

REM Clean up the temporary directory
echo Cleaning up temporary directory...
del /Q %TEMP_DIR%\*

REM Copy source files
echo Copying source files...
copy /Y "%~dp0..\src\app.py" %TEMP_DIR%\
copy /Y "%~dp0..\src\model_loader.py" %TEMP_DIR%\
copy /Y "%~dp0lambda_requirements\api_requirements.txt" %TEMP_DIR%\requirements.txt

REM Install dependencies
echo Installing dependencies...
cd %TEMP_DIR%
pip install -r requirements.txt -t . --no-cache-dir --upgrade

REM Remove unnecessary files to reduce package size
echo Removing unnecessary files to reduce package size...
REM Remove tests directories
for /d /r %TEMP_DIR% %%d in (tests) do if exist "%%d" rmdir /s /q "%%d"
for /d /r %TEMP_DIR% %%d in (test) do if exist "%%d" rmdir /s /q "%%d"
REM Remove documentation
for /d /r %TEMP_DIR% %%d in (docs) do if exist "%%d" rmdir /s /q "%%d"
for /d /r %TEMP_DIR% %%d in (doc) do if exist "%%d" rmdir /s /q "%%d"
REM Remove examples
for /d /r %TEMP_DIR% %%d in (examples) do if exist "%%d" rmdir /s /q "%%d"
REM Remove __pycache__ directories
for /d /r %TEMP_DIR% %%d in (__pycache__) do if exist "%%d" rmdir /s /q "%%d"
REM Remove .pyc files
del /s /q %TEMP_DIR%\*.pyc
REM Remove .dist-info directories
for /d /r %TEMP_DIR% %%d in (*.dist-info) do if exist "%%d" rmdir /s /q "%%d"
REM Remove .egg-info directories
for /d /r %TEMP_DIR% %%d in (*.egg-info) do if exist "%%d" rmdir /s /q "%%d"

REM Create the zip file
echo Creating zip file...
powershell -Command "& {Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%TEMP_DIR%\api.zip' -Force}"

REM Upload to S3
echo Uploading to S3...
aws s3 cp %TEMP_DIR%\api.zip s3://%S3_BUCKET%/lambda/api.zip

if %ERRORLEVEL% neq 0 (
    echo Failed to upload API Lambda function to S3.
    exit /b 1
)

echo API Lambda function uploaded to S3.

REM Clean up
echo.
echo Cleaning up...
cd %~dp0
rmdir /s /q %TEMP_DIR%

echo.
echo ✅ Lambda functions packaged and uploaded to S3 successfully!
echo.
echo You can now deploy the Lambda functions with:
echo terraform plan -var-file=dev.tfvars -var "deployment_type=lambda" -out tfplan
echo terraform apply "tfplan"
echo.
