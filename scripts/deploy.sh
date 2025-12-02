#!/bin/bash

# Скрипт для быстрого развертывания решения

set -e

echo "🚀 Развертывание Data Drift Detection Solution"

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Проверка зависимостей
echo -e "${YELLOW}📋 Проверка зависимостей...${NC}"
command -v minikube >/dev/null 2>&1 || { echo "❌ minikube не установлен. Установите: https://minikube.sigs.k8s.io/"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl не установлен."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ docker не установлен."; exit 1; }
echo -e "${GREEN}✅ Все зависимости установлены${NC}"

# 2. Запуск Minikube кластера
echo -e "${YELLOW}🔧 Запуск Minikube кластера...${NC}"
if minikube status >/dev/null 2>&1; then
    echo "ℹ️  Minikube кластер уже запущен"
else
    minikube start --cpus=4 --memory=8192 --disk-size=20g
    echo -e "${GREEN}✅ Кластер запущен${NC}"
fi

# 3. Сборка образа внутри Minikube
echo -e "${YELLOW}🐳 Сборка образа Drifter в Minikube...${NC}"
cd drifter
eval $(minikube docker-env)
docker build -t drifter:latest .
echo -e "${GREEN}✅ Образ Drifter собран${NC}"
cd ..

echo -e "${YELLOW}🐳 Сборка образа Drift Checker в Minikube...${NC}"
cd drift-checker
eval $(minikube docker-env)
docker build -t drift-checker:latest .
echo -e "${GREEN}✅ Образ Drift Checker собран${NC}"
cd ..

# 4. Создание namespace
echo -e "${YELLOW}📦 Создание namespace...${NC}"
kubectl apply -f k8s/namespace.yaml
echo -e "${GREEN}✅ Namespace создан${NC}"

# 5. Создание RBAC для Airflow
echo -e "${YELLOW}🔐 Создание RBAC для Airflow...${NC}"
kubectl apply -f k8s/airflow-rbac.yaml
echo -e "${GREEN}✅ RBAC создан${NC}"

# 6. Создание Secrets
echo -e "${YELLOW}🔐 Создание Secrets...${NC}"
kubectl apply -f k8s/secrets.yaml
echo -e "${GREEN}✅ Secrets созданы${NC}"

# 7. Развертывание сервисов
echo -e "${YELLOW}🚢 Развертывание PostgreSQL...${NC}"
kubectl apply -f k8s/postgres.yaml

echo -e "${YELLOW}🚢 Развертывание MinIO...${NC}"
kubectl apply -f k8s/minio.yaml

echo -e "${YELLOW}🚢 Развертывание MLflow...${NC}"
kubectl apply -f k8s/mlflow.yaml

echo -e "${YELLOW}🚢 Развертывание Drifter...${NC}"
kubectl apply -f k8s/drifter.yaml

echo -e "${YELLOW}🚢 Развертывание Airflow...${NC}"
kubectl apply -f k8s/airflow.yaml

echo -e "${GREEN}✅ Все сервисы развернуты${NC}"

# 8. Ожидание готовности
echo -e "${YELLOW}⏳ Ожидание готовности подов (это может занять несколько минут)...${NC}"
kubectl wait --for=condition=ready pod --all -n drift-detection --timeout=600s || {
    echo "⚠️  Не все поды готовы. Проверьте статус:"
    kubectl get pods -n drift-detection
}

echo -e "${GREEN}✅ Все поды готовы${NC}"

# 8. Инициализация MinIO через Job
echo -e "${YELLOW}🗄️  Инициализация MinIO...${NC}"
kubectl apply -f k8s/minio-init-job.yaml
kubectl wait --for=condition=complete --timeout=300s job/minio-init -n drift-detection
echo -e "${GREEN}✅ MinIO инициализирован${NC}"

# 9. Копирование DAG
echo -e "${YELLOW}📋 Копирование DAG в Airflow...${NC}"
./copy-dag.sh

# 10. Вывод информации
echo ""
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="
echo -e "${GREEN}🎉 Развертывание завершено!${NC}"
echo "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "=" "="
echo ""
echo "📊 Статус подов:"
kubectl get pods -n drift-detection
echo ""
echo "🌐 Для доступа к UI, выполните в отдельных терминалах:"
echo ""
echo "  Airflow UI (admin/admin):"
echo "  kubectl port-forward -n drift-detection svc/airflow 8080:8080"
echo "  Затем откройте: http://localhost:8080"
echo ""
echo "  MLflow UI:"
echo "  kubectl port-forward -n drift-detection svc/mlflow 5000:5000"
echo "  Затем откройте: http://localhost:5000"
echo ""
echo "  MinIO Console (minio/minio123):"
echo "  kubectl port-forward -n drift-detection svc/minio 9001:9001"
echo "  Затем откройте: http://localhost:9001"
echo ""
echo "📝 Логи можно посмотреть командами:"
echo "  kubectl logs -n drift-detection deployment/airflow -f"
echo "  kubectl logs -n drift-detection deployment/mlflow -f"
echo "  kubectl logs -n drift-detection deployment/drifter -f"
echo ""
echo "🧹 Для удаления всего:"
echo "  kubectl delete namespace drift-detection"
echo "  minikube stop"
echo "  minikube delete"
echo ""
