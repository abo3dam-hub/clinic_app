@echo off
chcp 65001 > nul
echo.
echo ============================================
echo  نظام إدارة العيادة - إعداد المشروع
echo ============================================
echo.

echo [1/4] التحقق من Flutter...
flutter --version
if %ERRORLEVEL% NEQ 0 (
    echo خطأ: Flutter غير مثبت. حمّله من https://flutter.dev
    pause
    exit /b 1
)

echo.
echo [2/4] تثبيت الحزم...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo خطأ في تثبيت الحزم
    pause
    exit /b 1
)

echo.
echo [3/4] التحقق من ملفات الخط...
if not exist "assets\fonts\Cairo-Regular.ttf" (
    echo تحذير: ملف Cairo-Regular.ttf غير موجود في assets\fonts\
    echo يرجى تحميل خط Cairo من https://fonts.google.com/specimen/Cairo
    echo ووضع الملفات في مجلد assets\fonts\
    echo.
)

echo.
echo [4/4] تشغيل التطبيق...
flutter run -d windows

pause
