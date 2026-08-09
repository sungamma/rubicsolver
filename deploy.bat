@echo off
chcp 65001 >nul
setlocal

set "projectName=rubicsolver"
set "publishDir=X:\certificate"
if defined DEPLOY_PUBLISH_DIR set "publishDir=%DEPLOY_PUBLISH_DIR%"
set "updateNotesDest=rubicsolver_update_notes.md"

set "target=%~1"
if "%target%"=="" set "target=android"
if /I "%target%"=="apk" set "target=android"
if /I not "%target%"=="android" (
    echo Usage: deploy.bat [android, apk] [publishDir]
    exit /b 1
)
if not "%~2"=="" set "publishDir=%~2"

pushd "%~dp0"
for /f "tokens=2 delims=+" %%a in ('findstr /r /c:"^version:" pubspec.yaml') do set "buildNumber=%%a"
if not defined buildNumber (
    echo Could not read build number from pubspec.yaml
    popd
    exit /b 1
)

call "%~dp0..\deploy_flutter_app.bat" android "%publishDir%"
set "exitCode=%errorlevel%"
popd
exit /b %exitCode%
