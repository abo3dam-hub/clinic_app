@echo off
chcp 65001 > nul
echo.
echo ============================================
echo  بناء نسخة الإنتاج
echo ============================================
echo.
flutter build windows --release
echo.
echo تم البناء! الملف في:
echo build\windows\x64\runner\Release\clinic_app.exe
echo.
pause
