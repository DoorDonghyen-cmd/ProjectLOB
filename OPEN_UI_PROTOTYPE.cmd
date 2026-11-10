@echo off
cd /d "%~dp0"
echo Open http://127.0.0.1:8765/index.html in your browser.
python tools\serve_ui_prototype.py
pause
