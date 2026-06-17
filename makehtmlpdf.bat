@echo off
setlocal

REM %1 = base name with or without .md
if "%~1"=="" (
    echo Usage: makehtmlpdf README
    exit /b 1
)

REM Normalize input: ensure .md extension
set "INPUT=%~1"
if /I not "%INPUT:~-3%"==".md" set "INPUT=%INPUT%.md"

REM Build full path without double quotes
set "BASE=%~dp0%INPUT%"
echo Processing %BASE%


REM --- Start MiniWeb silently in background ---
echo Starting MiniWeb...
start "" /min cmd /c "s:\miniweb\miniweb.exe -p 80 -r S:\pi\Pi_Multiboot\documentation_images -l s:\miniweb\logs -m 5 -d 1"

REM Give MiniWeb time to bind to port 80
timeout /t 3 >nul

REM --- Convert Markdown → HTML ---
"C:\Program Files\Pandoc\Pandoc.exe" -f gfm "%BASE%.md" --lua-filter=localize-images.lua -o "%BASE%.html"

REM --- Convert HTML → PDF using WeasyPrint ---
weasyprint "%BASE%.html" "%BASE%.pdf" -s pdf.css

REM --- Stop MiniWeb cleanly ---
echo Stopping MiniWeb...
taskkill /IM miniweb.exe /F >nul 2>&1

echo Done.
endlocal
