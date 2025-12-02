import os
import tempfile
from pathlib import Path

import pandas as pd
import mlflow
import s3fs

from evidently import ColumnMapping
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset


def main():
    """Проверка дрифта данных"""
    
    drifter_url = os.environ.get("DRIFTER_URL", "http://drifter.drift-detection.svc.cluster.local/api/v1/data")
    mlflow_uri = os.environ.get("MLFLOW_TRACKING_URI", "http://mlflow.drift-detection.svc.cluster.local:5000")
    reference_data_path = os.environ.get("REFERENCE_DATA_S3_PATH", "s3://datasets/reference.csv")
    
    aws_access_key_id = os.environ["AWS_ACCESS_KEY_ID"]
    aws_secret_access_key = os.environ["AWS_SECRET_ACCESS_KEY"]
    s3_endpoint_url = os.environ["MLFLOW_S3_ENDPOINT_URL"]
    
    print("Настройка MLflow...")
    mlflow.set_tracking_uri(mlflow_uri)
    
    print("Подключение к S3 (MinIO)...")
    s3 = s3fs.S3FileSystem(
        key=aws_access_key_id,
        secret=aws_secret_access_key,
        endpoint_url=s3_endpoint_url,
        use_ssl=False
    )
    
    print("Загрузка эталонного датасета из MinIO...")
    reference_df = pd.read_csv(s3.open(reference_data_path))
    print(f"Эталонный датасет загружен: {reference_df.shape}")
    print(reference_df.head())
    
    print("Загрузка текущего датасета из сервиса drifter...")
    current_df = pd.read_csv(drifter_url)
    print(f"Текущий датасет загружен: {current_df.shape}")
    print(current_df.head())
    
    print("Настройка маппинга столбцов...")
    column_mapping = ColumnMapping()
    column_mapping.numerical_features = list(reference_df.columns)
    
    print("Генерация отчета о дрифте...")
    data_drift_report = Report(metrics=[DataDriftPreset()])
    data_drift_report.run(
        current_data=current_df,
        reference_data=reference_df,
        column_mapping=column_mapping,
    )
    
    report = data_drift_report.as_dict()
    
    print("Логирование результатов в MLflow...")
    with tempfile.TemporaryDirectory() as tmp_dir:
        # Сохраняем текущий датасет как артефакт
        dataset_path = Path(tmp_dir, "current-dataset.csv")
        current_df.to_csv(dataset_path, index=False)
        
        with mlflow.start_run() as run:            
            # Логируем параметры
            mlflow.log_param("dataset_drift", report["metrics"][1]["result"]["dataset_drift"])
            
            # Логируем метрики
            mlflow.log_metrics({
                "number_of_drifted_columns": report["metrics"][1]["result"]["number_of_drifted_columns"],
                "share_of_drifted_columns": report["metrics"][1]["result"]["share_of_drifted_columns"],
            })
            
            # Логируем drift score для каждой фичи
            for feature in column_mapping.numerical_features:
                drift_score = report["metrics"][1]["result"]["drift_by_columns"][feature]["drift_score"]
                mlflow.log_metric(f"drift_score_{feature}", drift_score)
            
            print(f"MLflow Run ID: {run.info.run_id}")
            print(f"Обнаружен дрифт датасета: {report['metrics'][1]['result']['dataset_drift']}")
            print(f"Количество столбцов с дрифтом: {report['metrics'][1]['result']['number_of_drifted_columns']}")
            print(f"Доля столбцов с дрифтом: {report['metrics'][1]['result']['share_of_drifted_columns']:.2%}")


if __name__ == "__main__":
    main()
