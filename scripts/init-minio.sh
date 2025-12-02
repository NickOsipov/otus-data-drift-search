#!/bin/bash

# Скрипт для инициализации MinIO и загрузки данных

set -e

NAMESPACE="drift-detection"
MINIO_ALIAS="local-minio"

echo "🔧 Инициализация MinIO..."

# Ждем, пока MinIO будет готов
kubectl wait --for=condition=ready pod -l app=minio -n ${NAMESPACE} --timeout=300s

# Устанавливаем MinIO Client, если нет
if ! command -v mc &> /dev/null; then
    echo "📥 Установка MinIO Client..."
    curl -o /tmp/mc https://dl.min.io/client/mc/release/linux-amd64/mc
    chmod +x /tmp/mc
    MC_CMD="/tmp/mc"
else
    MC_CMD="mc"
fi

# Пробрасываем порт MinIO
echo "🔌 Проброс порта MinIO..."
kubectl port-forward -n ${NAMESPACE} svc/minio 9000:9000 &
PORT_FORWARD_PID=$!

# Ждем, пока порт будет доступен
sleep 5

# Настраиваем alias для MinIO
echo "⚙️  Настройка MinIO alias..."
${MC_CMD} alias set ${MINIO_ALIAS} http://localhost:9000 minio minio123

# Создаем buckets
echo "📦 Создание buckets..."
${MC_CMD} mb ${MINIO_ALIAS}/datasets --ignore-existing
${MC_CMD} mb ${MINIO_ALIAS}/mlflow --ignore-existing

# Загружаем референсные данные
echo "📤 Загрузка референсных данных..."
${MC_CMD} cp solution/data/reference.csv ${MINIO_ALIAS}/datasets/reference.csv

# Проверяем загрузку
echo "✅ Проверка загруженных файлов:"
${MC_CMD} ls ${MINIO_ALIAS}/datasets/

# Убиваем port-forward
kill ${PORT_FORWARD_PID} 2>/dev/null || true

echo ""
echo "✅ MinIO инициализирован успешно!"
echo "📊 Buckets созданы: datasets, mlflow"
echo "📄 Референсные данные загружены в datasets/reference.csv"
