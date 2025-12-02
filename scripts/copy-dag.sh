#!/bin/bash

# Скрипт для копирования DAG в Airflow PVC

set -e

NAMESPACE="drift-detection"

echo "📋 Копирование DAG в Airflow..."

# Ждем, пока Airflow будет готов
kubectl wait --for=condition=ready pod -l app=airflow -n ${NAMESPACE} --timeout=300s

# Получаем имя пода Airflow
AIRFLOW_POD=$(kubectl get pod -n ${NAMESPACE} -l app=airflow -o jsonpath='{.items[0].metadata.name}')

echo "📤 Копирование drift_detection.py в под ${AIRFLOW_POD}..."

# Копируем DAG в под
kubectl cp dags/drift_detection.py ${NAMESPACE}/${AIRFLOW_POD}:/opt/airflow/dags/drift_detection.py

echo "✅ DAG скопирован успешно!"

# Проверяем содержимое директории
echo "📂 Содержимое /opt/airflow/dags:"
kubectl exec -n ${NAMESPACE} ${AIRFLOW_POD} -- ls -la /opt/airflow/dags/

echo ""
echo "💡 Теперь можно открыть Airflow UI и активировать DAG 'drift_detection'"
