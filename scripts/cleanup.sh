#!/bin/bash

# Скрипт для удаления всех ресурсов

set -e

echo "🧹 Удаление Data Drift Detection Solution"

# Удаление namespace (это удалит все ресурсы внутри)
echo "📦 Удаление namespace drift-detection..."
kubectl delete namespace drift-detection --ignore-not-found=true

echo "⏳ Ожидание удаления ресурсов..."
kubectl wait --for=delete namespace/drift-detection --timeout=60s 2>/dev/null || true

# Удаление Minikube кластера
read -p "❓ Остановить и удалить Minikube кластер? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Остановка Minikube..."
    minikube stop
    echo "🗑️  Удаление Minikube кластера..."
    minikube delete
    echo "✅ Кластер удален"
else
    echo "ℹ️  Minikube кластер оставлен. Для остановки и удаления выполните:"
    echo "   minikube stop"
    echo "   minikube delete"
fi

echo ""
echo "✅ Очистка завершена!"
