# LoupGarou Infra

Infrastructure for the LoupGarou app — Docker orchestration, Kubernetes manifests, and cloud provisioning via Terraform on Azure.

## Architecture

| Component | Technology | Azure Service |
|---|---|---|
| React frontend | Kubernetes pod | AKS |
| ASP.NET Core API | Kubernetes pod | AKS |
| Database | DBaaS | Azure SQL (Basic) |
| Container registry | — | ACR |

All infrastructure is provisioned with a single command: `terraform apply`

## Repositories

| Repo | Description |
|---|---|
| [LoupGarouAPI](https://github.com/BenAyedMehdi/LoupGarouAPI) | ASP.NET Core backend |
| [LoupGarouReact](https://github.com/BenAyedMehdi/LoupGarouReact) | React frontend |
| [LoupGarouInfra](https://github.com/BenAyedMehdi/LoupGarouInfra) | This repo — all infra lives here |

## Folder structure

```
LoupGarouInfra/
├── docker-compose.yml        ← local full-stack setup (all 3 services)
├── infra/                    ← Terraform — provisions Azure infrastructure
│   ├── main.tf               ← all Azure resources defined here
│   ├── variables.tf          ← input variables
│   ├── outputs.tf            ← ACR URL, AKS config, SQL endpoint
│   └── terraform.tfvars      ← your actual values (gitignored — never commit)
├── k8s/                      ← Kubernetes manifests
│   ├── api-deployment.yaml
│   ├── react-deployment.yaml
│   └── postgres-deployment.yaml
└── .github/
    └── workflows/
        └── ci.yml        ← CI pipeline
        └── cd.yml        ← CD pipeline
```

---

## Local setup — full stack with Docker

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- All three repos cloned side by side in the same parent folder:

```
projects/
├── LoupGarouAPI/
├── LoupGarouReact/
└── LoupGarouInfra/     ← this repo
```

### Run

```bash
docker compose up --build
```

| Service | URL |
|---|---|
| Frontend | `http://localhost:3000` |
| API + Swagger | `http://localhost:8080` |

Database migrations and card seeding run automatically when the API starts. No manual setup needed.

### Stop

```bash
docker compose down
```

Full reset including all database data:

```bash
docker compose down -v
```

---

## Cloud setup — Azure via Terraform

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in:

```bash
az login
```

### First time setup

Create `infra/terraform.tfvars` with your values — this file is gitignored and must never be committed:

```hcl
subscription_id     = "your-azure-subscription-id"
location            = "westeurope"
resource_group_name = "loupgarou-rg"
acr_name            = "loupgarouacr"
aks_name            = "loupgarou-aks"
sql_server_name     = "loupgarou-sql"
sql_admin_login     = "loupgarouadmin"
sql_admin_password  = "YourStrongPassword@2024!"
sql_database_name   = "LoupGarou"
```

### Provision all infrastructure — one command

```bash
cd infra
terraform init     ← first time only, downloads Azure provider
terraform plan     ← dry run, shows what will be created
terraform apply    ← provisions everything on Azure (~10 minutes)
```

`terraform apply` creates all 7 Azure resources in one shot:
- Resource Group
- Azure Container Registry (ACR)
- AKS cluster (1 node, Standard_B2s)
- Azure SQL Server
- Azure SQL Database (Basic tier)
- Firewall rule allowing AKS to reach SQL
- Role assignment allowing AKS to pull images from ACR

### Tear down

```bash
terraform destroy
```

Removes all provisioned Azure resources. Useful for saving student credits when not demoing.

---

## CI/CD pipeline

The GitHub Actions pipeline in `.github/workflows/deploy.yml` triggers automatically on every push to `main`:

1. Checks out both app repos
2. Builds the API and React Docker images
3. Pushes both images to ACR
4. Applies the K8s manifests to AKS — new version live automatically

No manual deployment steps required after merging to `main`.