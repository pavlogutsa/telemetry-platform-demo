# 🧰 Local Environment Setup (Intel Mac)

This guide helps a new developer set up a full local environment for the **Telemetry Platform Demo** project on an **Intel-based macOS** system using **Docker Desktop**.

---

## 1. 🧩 Prerequisites

### 1.1 System
- macOS 12 Monterey or newer (Intel chip)
- Admin/sudo access

### 1.2 Install [Homebrew](https://brew.sh)
Homebrew is used to install all other tools.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"
brew doctor
brew update
```

---

## 2. 🧱 Core Development Tools

### 2.1 Git
```bash
brew install git
git --version
```

Configure your identity:
```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

---

### 2.2 Java (JDK 21)
We use **Java 21** for all services.

```bash
brew install openjdk@21
sudo ln -sfn $(brew --prefix)/opt/openjdk@21 /Library/Java/JavaVirtualMachines/openjdk-21.jdk
java -version
```

If needed, add to your PATH:
```bash
echo 'export PATH="/usr/local/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Expected output:
```
openjdk version "21.0.x" 2024-xx-xx
```

---

### 2.3 Gradle (Wrapper preferred)
Gradle wrapper (`./gradlew`) is included in the repo, but a local install is helpful:

```bash
brew install gradle
gradle -v
```

---

### 2.4 Docker Desktop
Used for running all local infrastructure (Oracle DB, Redis, Kafka, etc.).

```bash
brew install --cask docker
```
Then open **Docker Desktop** manually from Applications.

Verify:
```bash
docker --version
docker compose version
```

---

### 2.5 Kubernetes & Kind
We use **Kind** (Kubernetes in Docker) for local cluster deployment.

```bash
brew install kind kubectl
kind version
kubectl version --client
```

---

### 2.6 Helm
Used for packaging and deploying Helm charts to the local cluster.

```bash
brew install helm
helm version
```

---

### 2.7 Python & MkDocs
Used for documentation site generation.

```bash
brew install python@3.12
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

If `requirements.txt` is missing:
```bash
pip install mkdocs mkdocs-material mkdocs-material-extensions pymdown-extensions
```

---

### 2.8 VS Code (Recommended IDE)
```bash
brew install --cask visual-studio-code
```

Recommended extensions:
- Java Extension Pack  
- YAML  
- Docker  
- Kubernetes  
- Markdown All in One  
- Material Icon Theme  

---

## 3. 🗄️ Supporting Infrastructure (Optional Local Setup)

### 3.1 Oracle Database (Docker)
```bash
docker pull gvenzl/oracle-free
docker run -d --name oracle -p 1521:1521 -e ORACLE_PASSWORD=oracle gvenzl/oracle-free
```

**Connection:**
```
username: system
password: oracle
connection: localhost:1521/FREEPDB1
```

---

### 3.2 Redis
```bash
docker run -d --name redis -p 6379:6379 redis:7-alpine
```

---

### 3.3 Kafka + Zookeeper
Option 1 (via Homebrew):
```bash
brew install kafka
brew services start zookeeper
brew services start kafka
```

Option 2 (via Docker Compose):
```bash
docker compose -f docker-compose.kafka.yml up -d
```

---

## 4. 🧩 Project Setup

### 4.1 Clone Repository
```bash
git clone https://github.com/pavlogutsa/telemetry-platform-demo.git
cd telemetry-platform-demo
```

### 4.2 Build Project
```bash
./gradlew clean build
```

### 4.3 Run Sample Service
```bash
./gradlew :agent-ingest-svc:bootRun
```

If the task isn’t found:
```bash
./gradlew :agent-ingest-svc:tasks
```
Then run the Spring Boot task shown.

---

## 5. 🌐 Documentation Site

To preview documentation locally:
```bash
cd docs
mkdocs serve
```

Open [http://localhost:8000](http://localhost:8000)

To build manually:
```bash
mkdocs build --strict
```

---

## 6. 🔍 Verification Script

Once everything is installed, run the environment validation script below to make sure your setup is correct.

Create a file named `setup_check.sh` in the project root and paste the following content:

```bash
#!/bin/bash
# ============================================================
# 🧰 Telemetry Platform Demo - Environment Verification Script
# For Intel Mac local setup
# ============================================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check() {
  local cmd=$1
  local name=$2
  if command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ $name found:${NC} $($cmd --version 2>/dev/null | head -n 1)"
  else
    echo -e "${RED}❌ $name not found${NC}"
  fi
}

echo "------------------------------------------------------------"
echo "🔍 Telemetry Platform Demo - Environment Check"
echo "------------------------------------------------------------"

# Core tools
check java "Java (JDK)"
check gradle "Gradle"
check git "Git"
check docker "Docker"
check kind "Kind (Kubernetes)"
check kubectl "kubectl"
check helm "Helm"
check python3 "Python3"
check mkdocs "MkDocs"

# Additional checks
echo
echo "------------------------------------------------------------"
echo "🧱 Infrastructure Containers Check"
echo "------------------------------------------------------------"

for svc in oracle redis kafka; do
  if docker ps --format '{{.Names}}' | grep -q "$svc"; then
    echo -e "${GREEN}✅ $svc container is running${NC}"
  else
    echo -e "${YELLOW}⚠️  $svc container not found or not running${NC}"
  fi
done

echo
echo "------------------------------------------------------------"
echo "📦 Project Gradle Build Check"
echo "------------------------------------------------------------"

if [ -f "./gradlew" ]; then
  ./gradlew -q projects >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Gradle wrapper works correctly${NC}"
  else
    echo -e "${RED}❌ Gradle wrapper failed to run${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  Gradle wrapper (./gradlew) not found in this directory${NC}"
fi

echo
echo "------------------------------------------------------------"
echo "✅ Verification Complete"
echo "------------------------------------------------------------"
echo -e "Review any ${RED}❌ Missing${NC} or ${YELLOW}⚠️  Warning${NC} items above."
```

Make the script executable and run it:

```bash
chmod +x setup_check.sh
./setup_check.sh
```

Example output:

```
🔍 Telemetry Platform Demo - Environment Check
✅ Java (JDK) found: openjdk version "21.0.3"
✅ Gradle found: Gradle 8.5
✅ Docker found: Docker version 25.0.1, build c12345
⚠️  redis container not found or not running
✅ Gradle wrapper works correctly
✅ Verification Complete
```

---

## 7. 🧭 Next Steps

1. Review architecture in [`docs/02-architecture.md`](./docs/02-architecture.md)  
2. Inspect Helm values under `helm/telemetry-platform/`  
3. Deploy locally to Kind:

   ```bash
   kind create cluster --name telemetry
   helm install telemetry ./helm/telemetry-platform
   ```

4. Open Grafana/Prometheus dashboards after deployment.

---

## 8. 💡 Troubleshooting

| Problem | Solution |
|----------|-----------|
| `pymdownx.mermaid` not found | `pip install pymdown-extensions` |
| `docker compose` not found | Reinstall Docker Desktop or update CLI integration |
| Oracle container won’t start | `docker logs oracle` |
| `java` not found | Add JDK 21 to PATH (see section 2.2) |

---

✅ **Your environment is now ready!**  
You can build, run, document, and deploy the Telemetry Platform locally.
