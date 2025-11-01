@echo off
echo Building the website

if "%~1"=="" (
    echo Usage: run_build.bat "commit message"
    exit /b 1
)

REM Delete old search indices
del /q "docs\pagefind\*"

echo Running Jekyll build...
call bundle exec jekyll build --config _config.yml
echo Jekyll exited with code %errorlevel%
pause
if errorlevel 1 (
    echo Jekyll build failed!
    exit /b 1
)

echo Running Pagefind...
.\pagefind.exe
if errorlevel 1 (
    echo Pagefind failed!
    exit /b 1
)

echo Website built, putting it up on GitHub

git add -A

git diff --cached --quiet
if %errorlevel% equ 0 (
    echo No changes to commit.
) else (
    git commit -m "%~1"
    git push
)
