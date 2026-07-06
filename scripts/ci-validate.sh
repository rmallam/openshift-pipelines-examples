#!/usr/bin/env bash
# CI validation for manifests, pipelines, and deploy configs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
FAILED=0

ok()   { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; FAILED=1; }

echo "=== YAML syntax ==="
while IFS= read -r -d '' file; do
  if python3 -c "import yaml,sys; list(yaml.safe_load_all(open('${file}')))" 2>/dev/null; then
    ok "${file#${ROOT}/}"
  else
    fail "Invalid YAML: ${file#${ROOT}/}"
  fi
done < <(find . \
  \( -path './.git' -o -path './.cursor' -o -path './apps/sample-camel/target' \) -prune \
  -o -path '*/helm/*/templates/*' -prune \
  -o -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)

echo
echo "=== No custom Tekton Tasks ==="
if rg --glob '*.yaml' --glob '*.yml' -n '^kind: Task$' \
  --glob '!**/.cursor/**' \
  --glob '!**/.github/**' . 2>/dev/null; then
  fail "Custom Task CRs found — use inbuilt openshift-pipelines tasks only"
else
  ok "No custom Task definitions"
fi

echo
echo "=== Pipeline cluster resolver ==="
for pipeline in pipelines/universal-build-pipeline.yaml pipelines/universal-deploy-pipeline.yaml; do
  if rg -q 'resolver: cluster' "${pipeline}" && rg -q 'value: openshift-pipelines' "${pipeline}"; then
    ok "${pipeline} uses cluster resolver"
  else
    fail "${pipeline} missing cluster resolver references"
  fi
done

echo
echo "=== Kustomize build ==="
KUSTOMIZE="${KUSTOMIZE:-kustomize}"
for dir in \
  pipelines \
  pipelines/triggers \
  operators/openshift-pipelines \
  deploy/kustomize/base \
  deploy/kustomize/overlays/dev \
  deploy/kustomize/overlays/staging \
  deploy/kustomize/overlays/prod; do
  if "${KUSTOMIZE}" build "${dir}" >/dev/null; then
    ok "kustomize build ${dir}"
  else
    fail "kustomize build ${dir}"
  fi
done

echo
echo "=== Helm lint & template ==="
HELM="${HELM:-helm}"
CHART="deploy/helm/sample-camel"
if "${HELM}" lint "${CHART}"; then
  ok "helm lint ${CHART}"
else
  fail "helm lint ${CHART}"
fi
for values in values.yaml values-dev.yaml values-staging.yaml values-prod.yaml; do
  if "${HELM}" template sample-camel "${CHART}" -f "${CHART}/${values}" >/dev/null; then
    ok "helm template ${CHART} -f ${values}"
  else
    fail "helm template ${CHART} -f ${values}"
  fi
done

echo
echo "=== Helm chart templates ==="
ok "Helm templates validated via helm lint/template (Go templates excluded from YAML syntax check)"

echo
if [ "${FAILED}" -eq 0 ]; then
  echo -e "${GREEN}All validation checks passed.${NC}"
  exit 0
else
  echo -e "${RED}Validation failed.${NC}"
  exit 1
fi
