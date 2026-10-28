@echo off
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 (
  echo Python topilmadi. Python 3.10-3.12 ni python.org dan o'rnating ("Add to PATH" belgisini qo'ying).
  pause
  exit /b 1
)
if not exist .venv (
  python -m venv .venv
)
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
if not exist workflows mkdir workflows
echo.
echo Tayyor. Endi README.md dagi ComfyUI qadamlarini bajaring, keyin run.bat ni ishga tushiring.
pause
