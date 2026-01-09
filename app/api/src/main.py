from fastapi import FastAPI, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
import os

try:
    import psycopg
except Exception:
    psycopg = None

try:
    import redis
except Exception:
    redis = None

app = FastAPI(title="pet-api")

REQS = Counter("http_requests_total", "Total HTTP requests", ["path", "method", "status"])
LAT = Histogram("http_request_latency_seconds", "Request latency", ["path"])

PG_DSN = os.getenv("PG_DSN", "")
REDIS_HOST = os.getenv("REDIS_HOST", "")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

@app.get("/healthz")
def healthz():
    return {"status": "ok"}

@app.get("/readyz")
def readyz():
    # Postgres readiness
    if PG_DSN:
        if psycopg is None:
            return Response(content="psycopg not installed", status_code=503)
        try:
            with psycopg.connect(PG_DSN, connect_timeout=2) as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1;")
                    cur.fetchone()
        except Exception as e:
            return Response(content=f"postgres not ready: {e}", status_code=503)

    # Redis readiness
    if REDIS_HOST:
        if redis is None:
            return Response(content="redis lib not installed", status_code=503)
        try:
            r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, socket_connect_timeout=2)
            r.ping()
        except Exception as e:
            return Response(content=f"redis not ready: {e}", status_code=503)

    return {"status": "ready"}

@app.get("/work")
def work():
    start = time.time()
    status = "200"
    try:
        time.sleep(0.05)
        return {"result": "done"}
    finally:
        LAT.labels(path="/work").observe(time.time() - start)
        REQS.labels(path="/work", method="GET", status=status).inc()

@app.get("/metrics")
def metrics():
    data = generate_latest()
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)
