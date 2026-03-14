@echo off
setlocal

REM %1 = base name without extension (e.g. README)

if "%1"=="" (
    echo Usage: makepdf README
    exit /b 1
)

set BASE=%1

REM Convert Markdown → HTML
"C:\Program Files\Pandoc\Pandoc" -f gfm "%BASE%.md" -o "%BASE%.html"

REM Convert HTML → PDF with wkhtmltopdf
"C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe" ^
  --user-style-sheet pdf.css ^
  --margin-top 10mm --margin-bottom 10mm --margin-left 10mm --margin-right 10mm ^
  --no-stop-slow-scripts ^
  "%BASE%.html" "%BASE%.pdf"

endlocal
