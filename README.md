# pet-devops-platform (local)

Local Kubernetes DevOps pet-project: k3d + FastAPI + Helm + ingress-nginx + (postgres/redis/rabbitmq).

## Requirements (Ubuntu VM)
- docker
- kubectl
- helm
- k3d
- make

## Quickstart
```bash
make cluster-up
make infra-up
make api-build api-push api-deploy
make test-smoke
