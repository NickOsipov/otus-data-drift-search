"""
Сервис генерации данных с дрифтом для тестирования систем мониторинга.

Модуль предоставляет FastAPI приложение, которое генерирует синтетические
наборы данных с контролируемым дрифтом распределения.
"""

import io

import numpy as np
import pandas as pd

from fastapi import FastAPI
from fastapi.responses import StreamingResponse

import settings


def get_dataset(drift_prob: float, rows: int, cols: int) -> pd.DataFrame:
    """
    Генерирует синтетический набор данных с контролируемым дрифтом.
    
    Функция создает датафрейм со случайными данными, где каждый признак
    может иметь сдвиг в распределении с заданной вероятностью.
    
    Parameters
    ----------
    drift_prob : float
        Вероятность появления дрифта в каждом признаке (0-1)
    rows : int
        Количество строк в датасете
    cols : int
        Количество столбцов (признаков) в датасете
    
    Returns
    -------
    pd.DataFrame
        Датафрейм с синтетическими данными
    """
    def _get_loc():
        """
        Определяет параметр loc для нормального распределения.
        
        Returns
        -------
        float
            0 если дрифта нет, иначе случайное значение
        """
        return 0 if np.random.random() > drift_prob else np.random.random()

    # Генерация столбцов с нормальным распределением
    return pd.DataFrame(
        np.column_stack(
            [np.random.normal(loc=_get_loc(), size=rows) for _ in range(cols)]
        ),
        columns=[f"feat{i}" for i in range(cols)],
    )


# Префикс для API эндпоинтов
api_prefix = "/api/v1"

# Загрузка конфигурации
cfg = settings.Config()

# Инициализация FastAPI приложения
app = FastAPI()


@app.get(f"{api_prefix}/data")
def data():
    """
    Эндпоинт для получения сгенерированного датасета.
    
    Генерирует датасет с параметрами из конфигурации и возвращает
    его в формате CSV.
    
    Returns
    -------
    StreamingResponse
        CSV файл с данными
    """
    # Генерация датасета с параметрами из конфигурации
    df = get_dataset(cfg.drift_prob, cfg.drift_rows, cfg.drift_cols)

    # Создание потокового ответа с CSV данными
    response = StreamingResponse(
        io.StringIO(df.to_csv(index=False)),
        headers={
            "Content-Disposition": "attachment; filename=dataset.csv",
        },
        media_type="text/csv",
    )

    return response
