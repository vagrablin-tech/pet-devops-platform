SHELL := /bin/bash
CLUSTER := dev
REGISTRY := k3d-registry.localhost:5000
NAMESPACE := platform
API_IMAGE := $(REGISTRY)/pet/api:dev

.PHONY: tools cluster-up cluster-down infra-up infra-down api-build api-push api-deploy api-undeploy test-smoke

tools:
	@command -v docker >/dev/null
	@command -v kubectl >/dev/null
	@command -v helm >/dev/null
	@command -v k3d >/dev/null
	@command -v jq >/dev/null
	@echo "OK: tools present"

cluster-up: tools
	@k3d registry create registry.localhost --port 5000 >/dev/null 2>&1 || true
	@k3d cluster create $(CLUSTER) \
		--registry-use $(REGISTRY) \
		--agents 1 \
		--k3s-arg "--disable=traefik@server:0" \
		--port "80:80@loadbalancer"
	@kubectl create ns $(NAMESPACE) >/dev/null 2>&1 || true
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
	@helm repo update >/dev/null
	@helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		-n ingress-nginx --create-namespace
	@echo "Cluster up. Ingress on http://127.0.0.1"

cluster-down:
	@k3d cluster delete $(CLUSTER) >/dev/null 2>&1 || true

infra-up:
	@kubectl create ns $(NAMESPACE) >/dev/null 2>&1 || true
	@helm upgrade --install postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
		-n $(NAMESPACE) \
		--set auth.postgresPassword=postgres \
		--set auth.database=app
	@helm upgrade --install redis oci://registry-1.docker.io/bitnamicharts/redis \
		-n $(NAMESPACE) \
		--set auth.enabled=false
	@helm upgrade --install rabbitmq oci://registry-1.docker.io/bitnamicharts/rabbitmq \
		-n $(NAMESPACE) \
		--set auth.username=user \
		--set auth.password=pass
	@echo "Infra up (postgres/redis/rabbitmq)"


infra-down:
	@helm uninstall postgres -n $(NAMESPACE) >/dev/null 2>&1 || true
	@helm uninstall redis -n $(NAMESPACE) >/dev/null 2>&1 || true
	@helm uninstall rabbitmq -n $(NAMESPACE) >/dev/null 2>&1 || true

api-build:
	@docker build -t $(API_IMAGE) ./app/api

api-push:
	@docker push $(API_IMAGE)

api-deploy:
	@helm upgrade --install api ./deploy/charts/api \
		-n $(NAMESPACE) \
		--set image.repository=$(REGISTRY)/pet/api \
		--set image.tag=dev

api-undeploy:
	@helm uninstall api -n $(NAMESPACE) >/dev/null 2>&1 || true

test-smoke:
	@echo "GET /healthz"
	@curl -fsS -H 'Host: api.127.0.0.1.nip.io' http://127.0.0.1/healthz | jq .
	@echo "GET /metrics"
	@curl -fsS -H 'Host: api.127.0.0.1.nip.io' http://127.0.0.1/metrics | head
