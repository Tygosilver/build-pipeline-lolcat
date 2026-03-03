#!/bin/bash
# Автоматическая остановка скрипта при любой ошибке
set -e

# Вывод информации о режиме сборки
echo "Режим: DEBUG (с отладочными символами)"

# Переход в директорию исходного кода проекта lolcat
cd /work/src/lolcat

# Очистка предыдущих артефактов сборки
make clean 2>/dev/null || rm -f lolcat censor *.o 2>/dev/null || true

# Компиляция без оптимизации (-O0) и с отладочными символами (-g)
gcc -O0 -g -std=c99 -o lolcat lolcat.c -lm

# Проверка наличия отладочных символов в бинарнике с помощью утилиты file
if file lolcat 2>/dev/null | grep -q "with debug_info"; then
    echo "Отладочные символы обнаружены в бинарнике"
else
    echo "Внимание: отладочные символы не обнаружены (проверьте флаг -g при компиляции)"
fi

# Упаковка в DEB-пакет БЕЗ выполнения strip (отладочные символы сохраняются)
# Имя пакета содержит суффикс -debug для отличия от релизной версии
fpm -s dir -t deb -n lolcat-debug -v "1.0-rev${REVISION}" --architecture amd64 --description "Rainbow text pipe (DEBUG build with debug symbols)" -p "/work/artifacts/lolcat-debug_1.0-rev${REVISION}_${BUILD_ID}_amd64.deb" ./lolcat=/usr/bin/lolcat

# Уведомление об успешном завершении
echo "DEBUG сборка завершена. Артефакты в /work/artifacts/"
