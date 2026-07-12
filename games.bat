@echo off
chcp 65001 > nul
title ИГРОВАЯ КОНСОЛЬ

:: Включаем поддержку ANSI-цветов
for /f "tokens=2 delims=[" %%i in ('ver') do set "srv=%%i"
set "esc="
for /f %%A in ('echo prompt $E^|cmd') do set "esc=%%A"

set "lime=%esc%[38;2;166;226;46m"
set "reset=%esc%[0m"

set "DATABASE=Игры.txt"

:: Если базы данных нет, создаем чистый пустой файл
if not exist "%DATABASE%" type null > "%DATABASE%"

:: Полностью скрываем рабочий стол и панель задач
taskkill /f /im explorer.exe > nul 2>&1
taskkill /f /im Steam.exe 2>nul
taskkill /f /im epicgameslauncher.exe 2>nul
taskkill /f /im Discord.exe 2>nul
taskkill /f /im Telegram.exe 2>nul
taskkill /f /im WhatsApp.exe 2>nul

:menu
cls
echo %lime%───────────────────────────────────────────────────
echo    ТЕРМИНАЛ АКТИВИРОВАН! Выберите игру:
echo ───────────────────────────────────────────────────
echo.

setlocal enabledelayedexpansion
set "count=0"
for /f "usebackq delims=" %%A in ("%DATABASE%") do (
    set /a count+=1
    for /f "tokens=1 delims=|" %%B in ("%%A") do (
        echo    [!count!] %%B
    )
)

echo.
echo    [A] Добавить новую игру
echo    [D] Удалить игру из меню
echo    [0] ВЫХОД (Вернуть рабочий стол ПК)
echo ───────────────────────────────────────────────────

set "choice="
set /p choice="%lime%Выберите номер игры или действие и нажмите Enter: %reset%"

if "%choice%"=="0" goto exit
if /i "%choice%"=="A" goto add_game
if /i "%choice%"=="D" goto remove_game

if not defined count goto invalid_choice
set "valid=0"
set "current=0"
for /f "usebackq delims=" %%A in ("%DATABASE%") do (
    set /a current+=1
    if "!current!"=="%choice%" (
        set "valid=1"
        for /f "tokens=1,2,3 delims=|" %%B in ("%%A") do (
            set "game_name=%%B"
            set "game_folder=%%C"
            set "game_exe=%%D"
        )
    )
)

if "%valid%"=="1" (
    cls
    echo %lime%[Оптимизация]%reset% Выгрузка фонового софта и очистка Temp...
    
    taskkill /f /im chrome.exe > nul 2>&1
    
    del /q /f /s "%USERPROFILE%\AppData\Local\Temp\*.*" > nul 2>&1
    del /q /f /s "%SystemRoot%\Temp\*.*" > nul 2>&1

    echo Запуск %game_name%...
    cd /d "%game_folder%"
    start /wait "" "%game_folder%\%game_exe%"
    endlocal
    goto menu
)

:invalid_choice
endlocal
echo %lime%Неверный ввод! Пожалуйста, выберите существующий пункт.%reset%
timeout /t 2 > nul
goto menu

:add_game
cls
echo %lime%───────────────────────────────────────────────────
echo              ДОБАВЛЕНИЕ НОВОЙ ИГРЫ
echo ───────────────────────────────────────────────────
echo.
set "new_name="
set /p new_name="%lime%1. Введите красивое НАЗВАНИЕ игры для меню: %reset%"
if not defined new_name goto menu
echo.
echo %lime%2. Сейчас откроется окно... Выберите главный (.exe) - файл игры.
echo Пожалуйста, подождите...%reset%

:: Окно выбора файла стартует с системного диска. Пользователь сам выберет нужную папку.
set "ps_fallback=Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.OpenFileDialog; $d.Filter='Игры (*.exe)^|*.exe'; $d.InitialDirectory='%SystemDrive%\'; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$d.FileName}"
set "new_path="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "%ps_fallback%"`) do set "new_path=%%I"

if not defined new_path (
    echo.
    echo %lime%Файл не был выбран! Добавление отменено.%reset%
    timeout /t 2 > nul
    goto menu
)

for %%F in ("%new_path%") do (
    set "folder=%%~dpF"
    set "exe=%%~nxF"
)
if "%folder:~-1%"=="\" set "folder=%folder:~0,-1%"

echo %new_name%^|%folder%^|%exe%>> "%DATABASE%"

echo.
echo %lime%Отлично! Игра "%new_name%" успешно добавлена в список.%reset%
timeout /t 2 > nul
goto menu

:remove_game
cls
echo %lime%───────────────────────────────────────────────────
echo               УДАЛЕНИЕ ИГРЫ ИЗ МЕНЮ
echo ───────────────────────────────────────────────────
echo.
set "rcount=0"
for /f "usebackq delims=" %%A in ("%DATABASE%") do (
    set /a rcount+=1
    for /f "tokens=1 delims=|" %%B in ("%%A") do (
        echo    [!rcount!] %%B
    )
)
echo.
echo    [0] Назад в главное меню
echo ───────────────────────────────────────────────────
echo.
set "del_choice="
set /p del_choice="%lime%Введите номер игры, которую нужно УДАЛИТЬ: %reset%"

if "%del_choice%"=="0" goto menu
if not defined del_choice goto menu

:: Создаем временный файл прямо в этой же папке
set "TEMP_DB=Временный_список.txt"
if exist "%TEMP_DB%" del "%TEMP_DB%"

set "rcurrent=0"
set "deleted_name="
for /f "usebackq delims=" %%A in ("%DATABASE%") do (
    set /a rcurrent+=1
    if "!rcurrent!"=="%del_choice%" (
        for /f "tokens=1 delims=|" %%B in ("%%A") do set "deleted_name=%%B"
    ) else (
        echo %%A>> "%TEMP_DB%"
    )
)

if defined deleted_name (
    :: Если удалили последнюю игру и файл не создался, просто обнуляем базу
    if not exist "%TEMP_DB%" type null > "%DATABASE%"
    
    :: Если временный файл создался, заменяем им нашу базу Игры.txt
    if exist "%TEMP_DB%" (
        move /y "%TEMP_DB%" "%DATABASE%" > nul
    )
    echo.
    echo %lime%Игра "!deleted_name!" успешно удалена из меню консоли!%reset%
) else (
    if exist "%TEMP_DB%" del "%TEMP_DB%"
    echo.
    echo %lime%Неверный номер! Ничего не удалено.%reset%
)

timeout /t 2 > nul
goto menu

:exit
cls
echo Возврат рабочего стола Windows...
powershell -NoProfile -Command "& ""$env:SystemRoot\explorer.exe"""
timeout /t 1 > nul
ie4uinit.exe -show
exit
