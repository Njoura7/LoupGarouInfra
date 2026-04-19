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
│  
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

Create a local `.env` file next to `docker-compose.yml` with the SQL Server password before starting the stack. You can copy the included `.env.example` and fill in your own value.

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

All Azure infrastructure is defined as code in the `infra/` folder and provisioned with a single Terraform command.

### Architecture provisioned

| Resource | Azure Service | Purpose |
|---|---|---|
| Resource Group | `loupgarou-rg` | Container for all resources |
| Container Registry | ACR — `loupgarouacr.azurecr.io` | Stores Docker images |
| Kubernetes Cluster | AKS — `loupgarou-aks` | Runs API and React pods |
| SQL Server | Azure SQL — `loupgarou-sql` | Managed database server |
| SQL Database | Azure SQL Basic | `LoupGarou` database |
| Firewall rule | — | Allows Azure services to reach SQL |
| Role assignment | AcrPull | Allows AKS to pull images from ACR |


---

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) installed and on PATH
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in:

```bash
az login
```

- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed

---

### First time setup

Create `infra/terraform.tfvars` with your values — this file is gitignored and must never be committed:

```hcl
subscription_id     = "your-azure-subscription-id"
location            = "swedencentral"
resource_group_name = "loupgarou-rg"
acr_name            = "loupgarouacr"
aks_name            = "loupgarou-aks"
sql_server_name     = "loupgarou-sql"
sql_admin_login     = "loupgarouadmin"
sql_admin_password  = "YourStrongPassword@2024!"
sql_database_name   = "LoupGarou"
```

---

### Provision all infrastructure — one command

```bash
cd infra
terraform init      # first time only — downloads Azure provider
terraform plan      # dry run — shows what will be created
terraform apply     # provisions everything on Azure (~5–10 minutes)
```

Once complete, Terraform outputs:

```
acr_login_server = "loupgarouacr.azurecr.io"
sql_server_fqdn  = "loupgarou-sql.database.windows.net"

```

![Azure resources diagram](docs/azure-resources.png)

---

### Connect kubectl to AKS

```bash
az aks get-credentials --resource-group loupgarou-rg --name loupgarou-aks
kubectl get nodes    # verify node is Ready
```

---

### Push Docker images to ACR

```bash
az acr login --name loupgarouacr

docker build -t loupgarouacr.azurecr.io/api:latest ../LoupGarouAPI
docker build -t loupgarouacr.azurecr.io/react:latest ../LoupGarouReact

docker push loupgarouacr.azurecr.io/api:latest
docker push loupgarouacr.azurecr.io/react:latest
```

---

### Deploy to AKS

Create the API Secret before applying the manifests. Replace the value with your real Azure SQL connection string:

```bash
kubectl create secret generic api-db-connection \
    --from-literal=ConnectionStrings__SqlServer="Server=loupgarou-sql.database.windows.net;Database=LoupGarou;User Id=loupgarouadmin;Password=YOUR_PASSWORD;TrustServerCertificate=True;MultipleActiveResultSets=true"
```

```bash
kubectl apply -f k8s/
kubectl get services    # wait ~2 minutes for EXTERNAL-IP to appear on react service
```

Once the `react` service has an external IP, the app is live and accessible from any browser.

---

### Tear down

```bash
terraform destroy
```

Removes all provisioned Azure resources. Run this when not demoing to preserve student credits.

---

## Challenges and solutions

### Region restrictions — Azure for Students

Azure for Students subscriptions are locked to specific regions by a university-managed policy (`sys.regionrestriction`). Not all Azure regions or VM sizes are available.

To find your allowed regions:

```bash
az policy assignment list --scope /subscriptions/<your-subscription-id> --output table
```

Then check the policy assignment details in the Azure portal under **Policy → Assignments → Allowed resource deployment regions → Parameters**.

In our case the allowed regions were: `francecentral`, `germanywestcentral`, `polandcentral`, `swedencentral`, `spaincentral`. We chose `swedencentral`.

### VM size restrictions

Even within allowed regions, certain VM sizes are blocked for AKS. `Standard_B2s` (the most common small AKS node) was not available. To find available VM sizes for AKS in your region:

```bash
az aks get-versions --location <your-region> --output table
az vm list-usage --location <your-region> --output table
```

We used `Standard_B2as_v2` (2 vCPUs, Basv2 family) which was available and within the 6 vCPU regional quota of the student subscription.

### OIDC issuer conflict

During iterative Terraform applies across regions, the AKS cluster had `oidc_issuer_enabled` set to `true` by Azure automatically. Once enabled, it cannot be disabled. The fix is to explicitly set it in `main.tf`:

```hcl
oidc_issuer_enabled       = true
workload_identity_enabled = false
```

### SQL Server name must be globally unique

Azure SQL Server names are globally unique across all Azure customers. If a name was used in a previous failed attempt it may be soft-deleted and reserved for a period. Use a unique name in `terraform.tfvars` if you hit a conflict.

### Azure SQL Basic tier — transient connection failures

The Azure SQL Basic tier provides only 5 DTUs (Database Throughput Units). Under normal application load this causes intermittent connection drops with error `40613: Database is not currently available`.

The symptom is a `500 Internal Server Error` from the API even though migrations ran successfully and the app started cleanly.

The fix is enabling EF Core's built-in retry logic in `Program.cs`:

```csharp
builder.Services.AddDbContext<LoupGarouDbContext>(
    o => o.UseSqlServer(
        builder.Configuration.GetConnectionString("SqlServer"),
        sqlOptions => sqlOptions.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(30),
            errorNumbersToAdd: null
        )
    )
);
```

This tells EF Core to automatically retry failed connections up to 5 times before giving up — which is exactly what Azure SQL recommends for the Basic tier.

---

## Live application

The application is deployed and accessible at:

| Service | URL |
|---|---|
| Frontend | http://135.116.213.70 |
| API + Swagger | http://135.116.213.70/api (proxied via nginx) |

The full deployment flow on AKS:
- React frontend served by nginx on port 80
- nginx proxies `/api/*` requests internally to the API pod on port 8080
- API connects to Azure SQL — migrations and seeding run automatically on startup
- No manual database setup required

---

## What's next — CI/CD pipeline

The remaining step is automating the build and deploy flow via GitHub Actions. The goal is:

```
push to main → GitHub Actions triggers
  → build API image → push to ACR
  → build React image → push to ACR
  → kubectl rollout restart → new version live on AKS
```

This is implemented in `.github/workflows/ci.yml` and `.github/workflows/cd.yml`.


---
 
## CI/CD pipeline
 
The pipeline is split into two workflow files in `.github/workflows/`.
 
### How it works
 
```
push to any branch
    → CI runs (build + test + CodeQL)
        → if CI passes on main/develop
            → CD runs (build + push to ACR + deploy to AKS)
```
 
### CI (`ci.yml`) — runs on every push to every branch
 
| Job | What it does |
|---|---|
| Build and test API | Restores, builds, runs 3 unit tests |
| Build and test React | Installs deps, runs 3 Jest tests, builds Docker image |
| CodeQL analysis | Static security analysis on C# code |
 
### CD (`cd.yml`) — runs only when CI passes on `main` or `develop`
 
| Step | What it does |
|---|---|
| Checkout repos | Pulls latest from LoupGarouAPI and LoupGarouReact |
| Login to ACR | Authenticates Docker to Azure Container Registry |
| Build and push API image | Tags with git SHA + latest, pushes to ACR |
| Build and push React image | Tags with git SHA + latest, pushes to ACR |
| Deploy to AKS | Updates running deployments with new image, waits for rollout |
 
Every deployment is tagged with the git commit SHA — so you can always trace which exact code is running in production.


![CI/CD pipeline](docs/ci-cd-pipeline-logs.png)

--- 

### Monitoring deployments
 
**Check running pods:**
```bash
kubectl get pods
```
 
**Check deployment status:**
```bash
kubectl get deployments
```
 
**Stream live API logs:**
```bash
kubectl logs deployment/api --follow
```
 
**Stream live React logs:**
```bash
kubectl logs deployment/react --follow
```
 
**Check rollout history:**
```bash
kubectl rollout history deployment/api
kubectl rollout history deployment/react
```
 
**Roll back to previous version if something breaks:**
```bash
kubectl rollout undo deployment/api
kubectl rollout undo deployment/react
```
 
### Required GitHub secrets
 
These secrets must be set in `LoupGarouInfra` → Settings → Secrets and variables → Actions:
 
| Secret | Description |
|---|---|
| `ACR_LOGIN_SERVER` | ACR registry URL e.g. `loupgarouacr.azurecr.io` |
| `ACR_USERNAME` | ACR admin username |
| `ACR_PASSWORD` | ACR admin password |
| `KUBE_CONFIG` | Full kubeconfig from `terraform output -raw aks_kube_config` |
 
---
 
## Tearing down Azure resources
 
When not actively demoing, tear down all Azure resources to preserve student credits.
 
**Step 1 — remove Kubernetes resources first:**
```bash
kubectl delete -f k8s/
```
 
**Step 2 — destroy all Terraform-managed Azure resources:**
```bash
cd infra
terraform destroy
```
 
Type `yes` when prompted. This removes all 7 resources: AKS, ACR, SQL Server, SQL Database, firewall rule, role assignment, and resource group.
 
**Reprovisioning for the demo:**
```bash
cd infra
terraform apply    # ~10 minutes
az aks get-credentials --resource-group loupgarou-rg --name loupgarou-aks
kubectl apply -f k8s/
```
 
Then push any change to `main` to trigger the CD pipeline and redeploy the latest images.
 
> **Note:** After `terraform destroy` and `terraform apply`, the public IP of the React service will change. Run `kubectl get services` to find the new IP.


---
 
## Challenges while setting up the CI/CD pipelines and solutions
 
### .NET SDK version conflict in Docker builds
 
The `global.json` file at the solution root pinned the SDK to `10.0.202` for local development. When the CI runner built the Docker image using `mcr.microsoft.com/dotnet/sdk:8.0` (matching the project's `net8.0` target framework), the build failed immediately because the image only ships with .NET 8 SDK and `global.json` was demanding 10.0.202.
 
**Solution:** Deleted `global.json` entirely since the project targets `net8.0` and the local SDK conflict it was solving no longer exists. The Dockerfile base images were also aligned to `mcr.microsoft.com/dotnet/sdk:8.0` and `mcr.microsoft.com/dotnet/aspnet:8.0` to match the project target framework.
 
---
 
### Dockerfile not found in CI/CD context
 
Both the CI and CD pipelines check out app repos into named subdirectories (`LoupGarouAPI/`, `LoupGarouReact/`). A plain `docker build -t image:tag LoupGarouAPI` command looks for a `Dockerfile` at the root of the build context — but Docker was resolving the path relative to the runner's working directory, not the repo folder.
 
**Solution:** Added the `-f` flag to explicitly point to each Dockerfile:
 
```bash
docker build -t image:tag -f LoupGarouAPI/Dockerfile LoupGarouAPI
docker build -t image:tag -f LoupGarouReact/Dockerfile LoupGarouReact
```
 
---
 
### `Microsoft.AspNetCore.Mvc.Testing` version incompatibility
 
The test project originally referenced `Microsoft.AspNetCore.Mvc.Testing 9.0.0` while the project target framework was `net8.0`. Version 9.0.0 of this package only supports `net9.0` — the restore step failed with `NU1202: Package is not compatible with net8.0`.
 
**Solution:** Downgraded to `Microsoft.AspNetCore.Mvc.Testing 8.0.0` which is compatible with `net8.0`.
 
---
 
### `UseInMemoryDatabase` not found — missing EF Core InMemory package
 
The unit tests use an in-memory database via `UseInMemoryDatabase()` from `Microsoft.EntityFrameworkCore.InMemory`. This package was accidentally removed from `TestLoupGarou.csproj` during package cleanup. The error `CS1061: does not contain a definition for UseInMemoryDatabase` appeared both locally and in CI.
 
**Solution:** Re-added `Microsoft.EntityFrameworkCore.InMemory` at version `9.0.0` to match the rest of the EF Core packages. All EF Core packages must use the same version regardless of the target framework version.
 
```xml
<PackageReference Include="Microsoft.EntityFrameworkCore.InMemory" Version="9.0.0" />
```
 
---
 
### `--no-restore` flag caused NETSDK1005 in CI
 
The test command used `--no-restore` assuming the restore step had already run. However, the restore was running against the solution file while the test command targeted the test project directly. The assets file for `net10.0` (from an earlier migration attempt) didn't match what was actually restored, causing `NETSDK1005: Assets file doesn't have a target for net10.0`.
 
**Solution:** Removed `--no-restore` from the test command and switched to restoring each project individually rather than via the solution file:
 
```yaml
- name: Restore dependencies
  run: |
    dotnet restore LoupGarouAPI/LoupGarou/LoupGarou.csproj
    dotnet restore LoupGarouAPI/TestLoupGarou/TestLoupGarou.csproj
 
- name: Run unit tests
  run: dotnet test LoupGarouAPI/TestLoupGarou/TestLoupGarou.csproj --verbosity normal
```
 
---
 
### Axios ESM import breaking Jest in React tests
 
React tests using `jest.mock('axios')` failed with `SyntaxError: Cannot use import statement outside a module`. Axios v1+ ships as an ES module, which the default Jest/CRA configuration cannot parse.
 
**Solution:** Instead of importing axios and mocking it with `jest.mock('axios')`, we defined mock functions directly and used the factory pattern to replace the entire axios module with plain CommonJS-compatible functions:
 
```javascript
const mockGet = jest.fn();
const mockPost = jest.fn();
 
jest.mock('axios', () => ({
  get: mockGet,
  post: mockPost,
}));
 
const apiCalls = require('../apiCalls').default;
```
 
This avoids Jest ever touching the real axios package and its ESM syntax.
 