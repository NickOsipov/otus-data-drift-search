FROM python:3.12.3-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

COPY app.py .
COPY settings.py .

CMD ["fastapi", "run", "app.py", "--port", "80"]
