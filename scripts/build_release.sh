#!/bin/bash

# Автоматическая остановка скрипта при любой ошибке
set -e

# Вывод информации о режиме сборки
echo "Режим: RELEASE (оптимизированная сборка)"

# Переход в директорию исходного кода проекта lolcat
cd /work/src/lolcat

# Очистка предыдущих артефактов сборки (игнорируем ошибки при отсутствии файлов)
make clean 2>/dev/null || rm -f lolcat censor *.o 2>/dev/null || true

# Компиляция с оптимизацией (-O2) и без отладочных проверок (-DNDEBUG)
gcc -O2 -DNDEBUG -std=c99 -o lolcat lolcat.c -lm

# Проверка существования бинарного файла после компиляции
if [[ ! -f lolcat ]]; then
    echo "Ошибка: бинарный файл lolcat не создан после компиляции"
    exit 1
fi

# Удаление отладочной информации для уменьшения размера бинарника
strip lolcat

# Повторная проверка существования файла после strip
if [[ ! -f lolcat ]]; then
    echo "Ошибка: файл lolcat удалён после выполнения strip"
    exit 1
fi

# Упаковка в DEB-пакет одной командой (без переносов строк для надёжности)
# -s dir: источник — директория с файлами
# -t deb: целевой формат — deb
# -n: имя пакета
# -v: версия пакета с номером ревизии из переменной окружения
# --architecture: целевая архитектура
# --description: описание пакета
# -p: путь к выходному файлу пакета
# ./lolcat=/usr/bin/lolcat: карта файлов (относительный путь в контейнере -> путь в системе после установки)
fpm -s dir -t deb -n lolcat -v "1.0-rev${REVISION}" --architecture amd64 --description "Rainbow text pipe" -p "/work/artifacts/lolcat-release_1.0-rev${REVISION}_${BUILD_ID}_amd64.deb" ./lolcat=/usr/bin/lolcat

# Уведомление об успешном завершении
echo "RELEASE сборка завершена. Артефакты в /work/artifacts/"
