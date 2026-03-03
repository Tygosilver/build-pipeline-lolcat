#!/bin/bash
set -e

echo "Режим: COVERAGE (сборка с инструментированием)"

cd /work/src/lolcat

# АБСОЛЮТНАЯ ОЧИСТКА всех артефактов покрытия
rm -rf lolcat censor *.o *.gcno *.gcda *.gcov coverage*.info 2>/dev/null || true
find . -maxdepth 1 -name "*.gcno" -delete 2>/dev/null || true
find . -maxdepth 1 -name "*.gcda" -delete 2>/dev/null || true

# Компиляция с инструментированием
gcc --coverage -O0 -g -std=c99 -o lolcat lolcat.c -lm

# Убедиться, что НЕТ .gcda файлов (только .gcno должны существовать после компиляции)
find . -maxdepth 1 -name "*.gcda" -delete 2>/dev/null || true
GCNO_COUNT=$(find . -maxdepth 1 -name "*.gcno" | wc -l)
GCDA_COUNT=$(find . -maxdepth 1 -name "*.gcda" | wc -l)
echo "После компиляции: .gcno=${GCNO_COUNT}, .gcda=${GCDA_COUNT} (ожидается .gcda=0)"

# Выполнение теста — ОСНОВНОЙ КОД ПРОГРАММЫ (не --help!)
echo "Запуск теста: обработка данных через lolcat"
echo "test input line 1" | ./lolcat > /dev/null 2>&1 || true

# Проверка создания .gcda файла
if [[ -f lolcat.gcda ]]; then
    GCDA_SIZE=$(stat -c%s lolcat.gcda 2>/dev/null || echo "0")
    echo "Файл покрытия создан, размер: ${GCDA_SIZE} байт"
    HAS_COVERAGE_DATA=1
else
    echo "Файл покрытия НЕ создан (код программы не был выполнен)"
    HAS_COVERAGE_DATA=0
fi

# Генерация отчёта ТОЛЬКО из текущих данных
rm -f coverage.info 2>/dev/null || true
if [[ "$HAS_COVERAGE_DATA" -eq 1 ]]; then
    lcov --capture --directory . --output-file coverage.info --no-external --quiet 2>/dev/null || true
else
    # Создать ПУСТОЙ отчёт с 0% покрытия
    echo "TN:" > coverage.info
    echo "SF:lolcat.c" >> coverage.info
    echo "end_of_record" >> coverage.info
fi

# Извлечение процента покрытия
if [[ -f coverage.info && -s coverage.info ]]; then
    COVERAGE_RAW=$(lcov --summary coverage.info 2>/dev/null | grep -oP 'lines.*:\s*\K[0-9.]+(?=%)' | head -1 || echo "0.0")
    # Если данные отсутствуют — принудительно установить 0.0
    if [[ -z "$COVERAGE_RAW" || "$COVERAGE_RAW" == "100.0" && "$HAS_COVERAGE_DATA" -eq 0 ]]; then
        COVERAGE="0.0"
    else
        COVERAGE="$COVERAGE_RAW"
    fi
else
    COVERAGE="0.0"
fi

echo "Покрытие кода: ${COVERAGE}%"

# Проверка регрессии
PREV_FILE="/work/reports/last_coverage.txt"
if [[ -f "$PREV_FILE" ]]; then
    PREV_COVERAGE=$(cat "$PREV_FILE")
    echo "Предыдущее покрытие: ${PREV_COVERAGE}%"
    if command -v bc &>/dev/null; then
        if (( $(echo "$COVERAGE < $PREV_COVERAGE - 0.1" | bc -l) )); then
            echo "РЕГРЕССИЯ ПОКРЫТИЯ: ${COVERAGE}% < ${PREV_COVERAGE}%"
            echo "Сборка прервана из-за ухудшения покрытия кода!"
            exit 1
        else
            echo "Покрытие сохранено или улучшено: ${COVERAGE}% >= ${PREV_COVERAGE}%"
        fi
    fi
else
    echo "Предыдущее покрытие не найдено — первая сборка"
fi

echo "$COVERAGE" > "$PREV_FILE"

# Упаковка
fpm -s dir -t deb -n lolcat-coverage -v "1.0-rev${REVISION}" --architecture amd64 --description "Rainbow text pipe (COVERAGE build)" -p "/work/artifacts/lolcat-coverage_1.0-rev${REVISION}_${BUILD_ID}_amd64.deb" ./lolcat=/usr/bin/lolcat

# Генерация HTML-отчёта
mkdir -p "/work/reports/coverage_${BUILD_ID}"
genhtml coverage.info -o "/work/reports/coverage_${BUILD_ID}" 2>/dev/null || true

echo "COVERAGE сборка завершена. Артефакт: /work/artifacts/lolcat-coverage_1.0-rev${REVISION}_${BUILD_ID}_amd64.deb"
