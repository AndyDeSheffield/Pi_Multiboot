@echo off
setlocal

REM Require an argument
if "%~1"=="" (
    echo Usage: makehtmlpdf README
    exit /b 1
)

REM Get name, strip .md if present so BASE is always extension-less
set "NAME=%~1"
if /I "%NAME:~-3%"==".md" set "NAME=%NAME:~0,-3%"

REM BASE = script directory + bare name (no extension)
set "BASE=%~dp0%NAME%"
echo Processing "%BASE%"

REM --- Start MiniWeb silently in background ---
echo Starting MiniWeb...
start "" /min cmd /c "s:\miniweb\miniweb.exe -p 80 -r S:\pi\Pi_Multiboot\documentation_images -l s:\miniweb\logs -m 5 -d 1"

timeout /t 3 >nul

REM --- Convert Markdown → HTML ---
"C:\Program Files\Pandoc\Pandoc.exe" -f gfm "%BASE%.md" --lua-filter=localize-images.lua -o "%BASE%.html"

REM --- Convert HTML → PDF ---
weasyprint "%BASE%.html" "%BASE%.pdf" -s pdf.css

echo Stopping MiniWeb...
taskkill /IM miniweb.exe /F >nul 2>&1

echo Done.
endlocal
