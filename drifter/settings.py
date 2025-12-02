from typing import Annotated
from annotated_types import Ge, Le

from pydantic.types import confloat
from pydantic_settings import BaseSettings, SettingsConfigDict


class Config(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")
    drift_rows: Annotated[int, Ge(100), Le(10_000)] = 1000
    drift_cols: Annotated[int, Ge(2), Le(30)] = 12
    drift_prob: Annotated[float, Ge(0.0), Le(1.0)] = 0.4
