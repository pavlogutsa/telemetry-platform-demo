tar \
  --exclude='.git' \
  --exclude='.DS_Store' \
  --exclude='__MACOSX' \
  --exclude='._*' \
  --exclude='*/._*' \
  --exclude='.idea' \
  --exclude='.vscode' \
  --exclude='*.tgz' \
  --exclude='charts/*.tgz' \
  -czf helm-charts.tar.gz helm/

tar \
  --exclude='.git' \
  --exclude='.DS_Store' \
  --exclude='__MACOSX' \
  --exclude='._*' \
  --exclude='*/._*' \
  --exclude='.idea' \
  --exclude='.vscode' \
  --exclude='.terraform' \
  --exclude='.terraform.lock.hcl' \
  --exclude='.terragrunt-cache' \
  --exclude='*.tfstate' \
  --exclude='*.tfstate.backup' \
  -czf infra-terraform.tar.gz infra/