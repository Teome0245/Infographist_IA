@echo off
REM Lance ComfyUI au demarrage Windows (sans activer le venv manuellement).
REM Logs : C:\Users\sdesh\ComfyUI\user\boot.log

set COMFY_DIR=C:\Users\sdesh\ComfyUI
set PYTHON=%COMFY_DIR%\venv\Scripts\python.exe
set LOG=%COMFY_DIR%\user\boot.log

cd /d "%COMFY_DIR%"

echo [%date% %time%] Demarrage ComfyUI >> "%LOG%"

REM --listen 0.0.0.0 : accessible depuis WSL (Infographiste_IA)
REM --lowvram        : GTX 1050 Ti 4 Go
"%PYTHON%" main.py --listen 0.0.0.0 --port 8188 --lowvram >> "%LOG%" 2>&1

echo [%date% %time%] ComfyUI arrete (code %ERRORLEVEL%) >> "%LOG%"
