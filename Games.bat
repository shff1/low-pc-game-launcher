@echo off
chcp 65001 > nul
title ИГРОВАЯ КОНСОЛЬ (LIBRARY MODE)
setlocal enabledelayedexpansion

:: Настройка цветов
set "esc="
for /f %%A in ('echo prompt $E^|cmd') do set "esc=%%A"
set "lime=%esc%[38;2;166;226;46m"
set "gray=%esc%[38;2;150;150;150m"
set "blue=%esc%[38;2;0;170;255m"
set "reset=%esc%[0m"

set "SCRIPT_DIR=%~dp0"
set "DATABASE=%SCRIPT_DIR%Игры.txt"
set "STATS_DB=%SCRIPT_DIR%Статистика.txt"

if not exist "%DATABASE%" type nul > "%DATABASE%"
if not exist "%STATS_DB%" type nul > "%STATS_DB%"

:: Скрываем рабочий стол при старте и глушим фоновый софт
taskkill /f /im explorer.exe > nul 2>&1
taskkill /f /im Steam.exe > nul 2>&1
taskkill /f /im epicgameslauncher.exe > nul 2>&1
taskkill /f /im Discord.exe > nul 2>&1
taskkill /f /im Telegram.exe > nul 2>&1
taskkill /f /im WhatsApp.exe > nul 2>&1

:menu
cls

:: --- ПОДСЧЁТ ОБЩЕЙ СТАТИСТИКИ ДЛЯ ШАПКИ ---
set "total_games=0"
for /f "usebackq delims=" %%A in ("%DATABASE%") do set /a total_games+=1

set "total_seconds=0"
for /f "usebackq tokens=1,2 delims=|" %%S in ("%STATS_DB%") do set /a total_seconds+=%%T
call :format_time %total_seconds% total_ftime

:: --- ВЕРХНЯЯ ПАНЕЛЬ ---
echo  %gray%[ ИГРОВАЯ КОНСОЛЬ ]   [ ИГР: %total_games% ]   [ ВСЕГО ИГРАНО: %total_ftime% ]%reset%
echo  %blue%________________________________________________________________________________%reset%
echo.
echo  %lime%  БИБЛИОТЕКА ИГР:%reset%
echo.

:: --- ВЕРТИКАЛЬНЫЙ СПИСОК ИГР ---
set "count=0"
for /f "usebackq delims=" %%A in ("%DATABASE%") do (
    set /a count+=1
    for /f "tokens=1 delims=|" %%B in ("%%A") do set "gname=%%B"

    :: Получаем время для этой игры
    set "playtime=0"
    for /f "usebackq tokens=1,2 delims=|" %%S in ("%STATS_DB%") do (
        if "%%S"=="!gname!" set "playtime=%%T"
    )

    :: ВЫЗОВ ПОДПРОГРАММЫ ФОРМАТИРОВАНИЯ
    call :format_time !playtime! ftime

    :: Вывод широкой панели игры
    set "n=!gname!                                   "
    set "t=!ftime!           "
    echo   %lime%┌──────────────────────────────────────────────────────────┐%reset%
    echo   %lime%│ [!count!] !n:~0,30! %gray%Время: !t:~0,10!%reset%    %lime%│%reset%
    echo   %lime%└──────────────────────────────────────────────────────────┘%reset%
)

if %count%==0 (
    echo          %gray%БИБЛИОТЕКА ПУСТА. НАЖМИТЕ [A], ЧТОБЫ ДОБАВИТЬ ИГРУ.%reset%
)

echo.
echo  %blue%________________________________________________________________________________%reset%
echo    %gray%[A] Добавить игру    [D] Удалить игру    [0] Выход в Windows%reset%
echo.

set "choice="
set /p choice="%blue%  Выберите номер игры или действие и нажмите Enter: %reset%"

if "%choice%"=="0" goto exit
if /i "%choice%"=="A" goto add_game
if /i "%choice%"=="D" goto remove_game

:: Проверка выбора игры
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

if "%valid%"=="0" (
    echo %lime% Неверный ввод! Пожалуйста, выберите существующий пункт.%reset%
    timeout /t 2 > nul
    goto menu
)

if "%valid%"=="1" (
    if not exist "!game_folder!\!game_exe!" (
        echo %lime% Файл игры не найден!%reset%
        timeout /t 2 > nul
        goto menu
    )

    cls
    echo %blue%[ОПТИМИЗАЦИЯ]%reset% Выгрузка Chrome и очистка системы...

    taskkill /f /im chrome.exe > nul 2>&1
    taskkill /f /im Discord.exe > nul 2>&1
    taskkill /f /im Telegram.exe > nul 2>&1
    taskkill /f /im WhatsApp.exe > nul 2>&1

    del /q /f /s "%USERPROFILE%\AppData\Local\Temp\*.*" > nul 2>&1
    del /q /f /s "%SystemRoot%\Temp\*.*" > nul 2>&1

    echo Запуск !game_name!...
    set "start_time=!time!"
    cd /d "!game_folder!"
    start /wait "" "!game_folder!\!game_exe!"
    set "end_time=!time!"
    cd /d "%SCRIPT_DIR%"

    call :calc_elapsed "!start_time!" "!end_time!" elapsed_seconds
    call :update_stats "!game_name!" !elapsed_seconds!
    goto menu
)
goto menu

:add_game
cls
echo %blue%  ДОБАВЛЕНИЕ ИГРЫ%reset%
set /p "new_name=  Введите название: "
if not defined new_name goto menu
set "temp_file=%temp%\game_path.tmp"
if exist "%temp_file%" del "%temp_file%"
start /wait "" powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.OpenFileDialog; $d.Filter='Игры (*.exe)|*.exe'; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ [System.IO.File]::WriteAllText('%temp_file%', $d.FileName) }"
chcp 65001 > nul
if not exist "%temp_file%" (
    echo %lime% Файл не выбран!%reset%
    timeout /t 2 > nul
    goto menu
)
set /p raw_path=<"%temp_file%"
del "%temp_file%"
for %%I in ("%raw_path%") do set "full_path=%%~fI"
for %%F in ("%full_path%") do (set "folder=%%~dpF" & set "exe=%%~nxF")
if "%folder:~-1%"=="\" set "folder=%folder:~0,-1%"
echo %new_name%^|%folder%^|%exe%>> "%DATABASE%"
echo.
echo %lime% Игра "%new_name%" успешно добавлена.%reset%
timeout /t 2 > nul
goto menu

:remove_game
cls
echo %blue%  УДАЛЕНИЕ ИЗ БИБЛИОТЕКИ%reset%
set "rcount=0"
for /f "usebackq delims=" %%A in ("%DATABASE%") do (
    set /a rcount+=1
    for /f "tokens=1 delims=|" %%B in ("%%A") do echo    [!rcount!] %%B
)
echo.
echo    [0] Назад в главное меню
set /p del_choice="  Номер для удаления: "
if "%del_choice%"=="0" goto menu
if not defined del_choice goto menu

set "TEMP_DB=%temp%\temp_db.txt"
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
    if not exist "%TEMP_DB%" type nul > "%DATABASE%"
    if exist "%TEMP_DB%" move /y "%TEMP_DB%" "%DATABASE%" > nul

    :: Чистим статистику удалённой игры
    set "TEMP_STATS=%temp%\temp_stats.txt"
    if exist "!TEMP_STATS!" del "!TEMP_STATS!"
    for /f "usebackq tokens=1,2 delims=|" %%S in ("%STATS_DB%") do (
        if not "%%S"=="!deleted_name!" echo %%S^|%%T>> "!TEMP_STATS!"
    )
    if exist "!TEMP_STATS!" (
        move /y "!TEMP_STATS!" "%STATS_DB%" > nul
    ) else (
        type nul > "%STATS_DB%"
    )
    echo.
    echo %lime% Игра "!deleted_name!" успешно удалена.%reset%
) else (
    if exist "%TEMP_DB%" del "%TEMP_DB%"
    echo.
    echo %lime% Неверный номер! Ничего не удалено.%reset%
)
timeout /t 2 > nul
goto menu

:exit
cls
echo %blue%[SYSTEM]%reset% Возврат рабочего стола...
powershell -NoProfile -Command "& ""$env:SystemRoot\explorer.exe"""
timeout /t 1 > nul
ie4uinit.exe -show
endlocal
exit

:: ──────────────────────────────────────────────
:: ПОДПРОГРАММЫ (ДОЛЖНЫ БЫТЬ В САМОМ КОНЦЕ)
:: ──────────────────────────────────────────────

:format_time
setlocal
set "seconds=%~1"
if "%seconds%"=="" set "seconds=0"
set /a h=%seconds%/3600
set /a m=(%seconds%%%3600)/60
if %h%==0 (set "res=%m%m") else (set "res=%h%h %m%m")
endlocal & set "%~2=%res%"
goto :eof

:calc_elapsed
setlocal
set "t1=%~1"
set "t2=%~2"
set "t1=%t1: =0%"
set "t2=%t2: =0%"
for /f "tokens=1-3 delims=:.," %%a in ("%t1%") do (set /a h1=1%%a-100, m1=1%%b-100, s1=1%%c-100)
for /f "tokens=1-3 delims=:.," %%a in ("%t2%") do (set /a h2=1%%a-100, m2=1%%b-100, s2=1%%c-100)
set /a total1=(h1*3600)+(m1*60)+s1, total2=(h2*3600)+(m2*60)+s2, diff=total2-total1
if %diff% lss 0 set /a diff+=86400
endlocal & set "%~3=%diff%"
goto :eof

:update_stats
setlocal enabledelayedexpansion
set "gname=%~1"
set "elapsed=%~2"
set "TMP_S=%temp%\stats.tmp"
if exist "!TMP_S!" del "!TMP_S!"
set "found=0"
for /f "usebackq tokens=1,2 delims=|" %%S in ("%STATS_DB%") do (
    if "%%S"=="!gname!" (
        set /a nt=%%T+elapsed
        echo %%S^|!nt!>> "!TMP_S!"
        set "found=1"
    ) else (echo %%S^|%%T>> "!TMP_S!")
)
if "!found!"=="0" echo !gname!^|!elapsed!>> "!TMP_S!"
move /y "!TMP_S!" "%STATS_DB%" > nul
endlocal
goto :eof
