FROM python:3.12-slim-bookworm

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl git \
    && rm -rf /var/lib/apt/lists/*

COPY worker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY shared/ ./shared/
COPY worker/app/ ./app/

ENV PYTHONPATH=/app

EXPOSE 9090

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "9090"]
