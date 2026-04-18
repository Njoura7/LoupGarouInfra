# LoupGarou Infra

Infrastructure for the LoupGarou app — Docker orchestration, Kubernetes manifests, and cloud provisioning (Terraform/Azure).

## Repositories

| Repo | Description |
|---|---|
| [LoupGarouAPI](https://github.com/BenAyedMehdi/LoupGarouAPI) | ASP.NET Core backend |
| [LoupGarouReact](https://github.com/BenAyedMehdi/LoupGarouReact) | React frontend |
| [LoupGarouInfra](https://github.com/BenAyedMehdi/LoupGarouInfra) | This repo — all infra lives here |

## Structure

```
LoupGarouInfra/
├── docker-compose.yml    ← local full-stack setup
├── infra/                ← Terraform — provisions Azure infrastructure
├── k8s/                  ← Kubernetes manifests
└── .github/
    └── workflows/
        └── deploy.yml    ← CI/CD pipeline
```

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- All three repos cloned side by side:

```
projects/
├── LoupGarouAPI/
├── LoupGarouReact/
└── LoupGarouInfra/     ← this repo
```

## Local setup — full stack with Docker

```bash
docker compose up --build
```

| Service | URL |
|---|---|
| Frontend | `http://localhost:3000` |
| API + Swagger | `http://localhost:8080` |

Database migrations and card seeding run automatically when the API starts. No manual setup needed.

To stop:

```bash
docker compose down
```

To fully reset including all data:

```bash
docker compose down -v
```