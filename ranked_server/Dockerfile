FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt && useradd --uid 10001 --create-home ranked && mkdir /data && chown ranked:ranked /data
COPY app.py rules.py schema.sql /app/ranked_server/
USER ranked
ENV RANKED_DATABASE=/data/ranked.sqlite3 RANKED_REQUIRE_TLS=true
EXPOSE 8000
CMD ["uvicorn", "ranked_server.app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--proxy-headers", "--forwarded-allow-ips", "*", "--no-access-log"]
