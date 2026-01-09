from fastapi import FastAPI, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

app = FastAPI(title="pet-api")

REQS = Counter("http_requests_total", "Total HTTP requests", ["path", "method", "status"])
LAT = Histogram("http_request_latency_seconds", "Request latency", ["path"])

@app.get("/healthz")
def healthz():
    return {"status": "ok"}

@app.get("/readyz")
def readyz():
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
