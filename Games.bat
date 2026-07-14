@echo off
chcp 65001 > nul
title ИГРОВАЯ КОНСОЛЬ
setlocal enabledelayedexpansion

:: Включаем поддержку ANSI-цветов
set "esc="
for /f %%A in ('echo prompt $E^|cmd') do set "esc=%%A"

set "lime=%esc%[38;2;166;226;46m"
set "reset=%esc%[0m"

set "SCRIPT_DIR=%~dp0"
set "DATABASE=%SCRIPT_DIR%Игры.txt"
set "STATS_DB=%SCRIPT_DIR%Статистика.txt"

:: Если баз данных нет, создаем чистые пустые файлы
if not exist "%DATABASE%" type nul > "%DATABASE%"
if not exist "%STATS_DB%" type nul > "%STATS_DB%"

:: Полностью скрываем рабочий стол и панель задач + глушим лаунчеры
taskkill /f /im explorer.exe > nul 2>&1
taskkill /f /im Steam.exe 2>nul
taskkill /f /im epicgameslauncher.exe 2>nul
taskkill /f /im Discord.exe 2>nul
taskkill /f /im Telegram.exe 2>nul
taskkill /f /im WhatsApp.exe 2>nul

:menu
cls
echo %lime%───────────────────────────────────────────────────
echo     ТЕРМИНАЛ АКТИВИРОВАН! Выберите игру:
echo ───────────────────────────────────────────────────
echo.

set "count=0"
for /f "usebackq delims=" %%A in ("%DATABASE%") do (
    set /a count+=1
    for /f "tokens=1 delims=|" %%B in ("%%A") do set "gname=%%B"
    set "playtime=0"
    for /f "usebackq tokens=1,2 delims=|" %%S in ("%STATS_DB%") do (
        if "%%S"=="!gname!" set "playtime=%%T"
    )
    call :format_time !playtime! ftime
    echo     [!count!] !gname!  ^(!ftime!^)
)

echo.
echo     [A] Добавить новую игру
echo     [D] Удалить игру из меню
echo     [0] ВЫХОД (Вернуть рабочий стол ПК)
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
    if not exist "!game_folder!\!game_exe!" (
        echo %lime%Файл игры не найден! Возможно, её удалили или перенесли.%reset%
        timeout /t 2 > nul
        goto menu
    )

    cls
    echo %lime%[Оптимизация]%reset% Выгрузка фонового софта и очистка Temp...

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

:invalid_choice
echo %lime%Неверный ввод! Пожалуйста, выберите существующий пункт.%reset%
timeout /t 2 > nul
goto menu

:add_game
cls
echo %lime%───────────────────────────────────────────────────
echo                 ДОБАВЛЕНИЕ НОВОЙ ИГРЫ
echo ───────────────────────────────────────────────────
echo.
set "new_name="
set /p new_name="%lime%1. Введите красивое НАЗВАНИЕ игры для меню: %reset%"
if not defined new_name goto menu
echo.
echo %lime%2. Выберите главный (.exe) файл игры...%reset%

set "temp_file=%temp%\game_path.tmp"
if exist "%temp_file%" del "%temp_file%"

:: Запускаем PowerShell через отдельный процесс, батник ждет (/wait) окончания выбора
start /wait "" powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.OpenFileDialog; $d.Filter='Игры (*.exe)|*.exe'; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ [System.IO.File]::WriteAllText('%temp_file%', $d.FileName) }"

:: Возвращаем кодировку нашего батника в чувство
chcp 65001 > nul

if not exist "%temp_file%" (
    echo %lime%Файл не выбран!%reset%
    timeout /t 2 > nul
    goto menu
)

:: Читаем путь
set /p raw_path=<"%temp_file%"
del "%temp_file%"

:: Принудительное получение абсолютного пути
for %%I in ("%raw_path%") do set "full_path=%%~fI"

for %%F in ("%full_path%") do (
    set "folder=%%~dpF"
    set "exe=%%~nxF"
)
if "%folder:~-1%"=="\" set "folder=%folder:~0,-1%"

echo %new_name%^|%folder%^|%exe%>> "%DATABASE%"

echo.
echo %lime%Отлично! Игра "%new_name%" успешно добавлена.%reset%
timeout /t 2 > nul
goto menu

:remove_game
cls
echo %lime%───────────────────────────────────────────────────
echo                УДАЛЕНИЕ ИГРЫ ИЗ МЕНЮ
echo ───────────────────────────────────────────────────
echo.
set "rcount=0"
for /f "usebackq delims=" %%A in ("%DATABASE%") do (
    set /a rcount+=1
    for /f "tokens=1 delims=|" %%B in ("%%A") do (
        echo     [!rcount!] %%B
    )
)
echo.
echo     [0] Назад в главное меню
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
    if not exist "%TEMP_DB%" type nul > "%DATABASE%" 2>nul

    :: Если временный файл создался, заменяем им нашу базу Игры.txt, глуша системные ошибки
    if exist "%TEMP_DB%" (
        move /y "%TEMP_DB%" "%DATABASE%" > nul 2>&1
    )

    :: Заодно чистим статистику удалённой игры
    set "TEMP_STATS=Временная_статистика.txt"
    if exist "!TEMP_STATS!" del "!TEMP_STATS!"
    for /f "usebackq tokens=1,2 delims=|" %%S in ("%STATS_DB%") do (
        if not "%%S"=="!deleted_name!" (
            echo %%S^|%%T>> "!TEMP_STATS!"
        )
    )
    if exist "!TEMP_STATS!" (
        move /y "!TEMP_STATS!" "%STATS_DB%" > nul 2>&1
    ) else (
        type nul > "%STATS_DB%"
    )

    echo.
    echo %lime%Игра "!deleted_name!" успешно удалена из меню консоли!%reset%
) else (
    if exist "%TEMP_DB%" del "%TEMP_DB%" > nul 2>&1
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
endlocal
exit

:: ──────────────────────────────────────────────
:: ПОДПРОГРАММЫ (вызываются через call, не мешают основному меню)
:: ──────────────────────────────────────────────

:: Считает разницу между двумя метками времени в секундах, учитывая переход через полночь
:calc_elapsed
setlocal
set "t1=%~1"
set "t2=%~2"
set "t1=%t1: =0%"
set "t2=%t2: =0%"
for /f "tokens=1-3 delims=:.," %%a in ("%t1%") do (
    set /a h1=1%%a-100
    set /a m1=1%%b-100
    set /a s1=1%%c-100
)
for /f "tokens=1-3 delims=:.," %%a in ("%t2%") do (
    set /a h2=1%%a-100
    set /a m2=1%%b-100
    set /a s2=1%%c-100
)
set /a total1=(h1*3600)+(m1*60)+s1
set /a total2=(h2*3600)+(m2*60)+s2
set /a diff=total2-total1
if %diff% lss 0 set /a diff+=86400
endlocal & set "%~3=%diff%"
goto :eof

:: Прибавляет секунды к общему времени игры в файле статистики
:update_stats
setlocal enabledelayedexpansion
set "gname=%~1"
set "elapsed=%~2"
set "TMP=%temp%\stats_update.tmp"
if exist "!TMP!" del "!TMP!"
set "found=0"
for /f "usebackq tokens=1,2 delims=|" %%S in ("%STATS_DB%") do (
    if "%%S"=="!gname!" (
        set /a newtotal=%%T+elapsed
        echo %%S^|!newtotal!>> "!TMP!"
        set "found=1"
    ) else (
        echo %%S^|%%T>> "!TMP!"
    )
)
if "!found!"=="0" (
    echo !gname!^|!elapsed!>> "!TMP!"
)
move /y "!TMP!" "%STATS_DB%" > nul 2>&1
endlocal
goto :eof

:: Переводит секунды в формат "Хч Yм" для вывода в меню
:format_time
setlocal
set /a h=%~1/3600
set /a m=(%~1%%3600)/60
if %h%==0 (
    set "res=%m%м"
) else (
    set "res=%h%ч %m%м"
)
endlocal & set "%~2=%res%"
goto :eof
