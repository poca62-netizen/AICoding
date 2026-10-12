@echo off
setlocal
cd /d "%~dp0"
if errorlevel 1 goto folder_error

if not exist "env.json" (
  echo ERROR: env.json was not found in the app folder.
  echo Create env.json with your KAKAO_REST_API_KEY, then try again.
  pause
  exit /b 1
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: Flutter was not found. Add Flutter bin to PATH.
  pause
  exit /b 1
)

echo Starting the app in Chrome with env.json...
echo Keep this window open while using the app.
echo Press r to reload, R to restart, or q to quit.
call flutter run -d chrome --dart-define-from-file=env.json
set "app_exit_code=%errorlevel%"
if not "%app_exit_code%"=="0" (
  echo.
  echo Flutter exited with an error. Check the message above.
  pause
)
exit /b %app_exit_code%

:folder_error
echo ERROR: Could not open the app folder.
pause
exit /b 1
