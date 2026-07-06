#!/usr/bin/env bash
# Verify OpenShift Pipelines stack installation.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; FAILED=1; }

FAILED=0
CICD_NS="${CICD_NS:-cicd}"
ARGOCD_NS="${ARGOCD_NS:-argocd}"

echo "=== OpenShift Pipelines stack verification ==="
echo

echo "--- Operator (OLM) ---"
if oc get subscription openshift-pipelines-operator -n openshift-operators &>/dev/null; then
  phase=$(oc get subscription openshift-pipelines-operator -n openshift-operators \
    -o jsonpath='{.status.state}' 2>/dev/null || echo "Unknown")
  ok "Subscription openshift-pipelines-operator (state: ${phase})"
else
  fail "Subscription openshift-pipelines-operator not found in openshift-operators"
fi

if oc get tektonconfig config &>/dev/null; then
  ok "TektonConfig config exists"
else
  fail "TektonConfig config not found (operator may still be installing)"
fi

if oc get pods -n openshift-pipelines --no-headers 2>/dev/null | grep -q Running; then
  ok "Pods running in openshift-pipelines namespace"
else
  fail "No running pods in openshift-pipelines namespace"
fi

task_count=$(oc get tasks -n openshift-pipelines --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${task_count}" -gt 0 ] 2>/dev/null; then
  ok "Inbuilt tasks available in openshift-pipelines (${task_count} tasks)"
else
  fail "No tasks found in openshift-pipelines namespace"
fi

echo
echo "--- Argo CD applications ---"
for app in openshift-pipelines-operator tekton-pipelines sample-camel-dev; do
  if oc get application "${app}" -n "${ARGOCD_NS}" &>/dev/null; then
    sync=$(oc get application "${app}" -n "${ARGOCD_NS}" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "?")
    health=$(oc get application "${app}" -n "${ARGOCD_NS}" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "?")
    if [ "${sync}" = "Synced" ] && [ "${health}" = "Healthy" ]; then
      ok "Argo CD app ${app} (Synced / Healthy)"
    else
      fail "Argo CD app ${app} (sync=${sync}, health=${health})"
    fi
  else
    fail "Argo CD app ${app} not found in ${ARGOCD_NS}"
  fi
done

echo
echo "--- CI/CD namespace (${CICD_NS}) ---"
for res in pipeline/universal-build pipeline/universal-deploy eventlistener/tekton-webhook; do
  if oc get "${res}" -n "${CICD_NS}" &>/dev/null; then
    ok "${res} in ${CICD_NS}"
  else
    fail "${res} not found in ${CICD_NS}"
  fi
done

if oc get secret github-webhook-secret -n "${CICD_NS}" &>/dev/null; then
  ok "Secret github-webhook-secret"
else
  fail "Secret github-webhook-secret not found (create manually)"
fi

if oc get secret argocd-token -n "${CICD_NS}" &>/dev/null; then
  ok "Secret argocd-token"
else
  fail "Secret argocd-token not found (create manually for dev deploy trigger)"
fi

if oc get route tekton-webhook -n "${CICD_NS}" &>/dev/null; then
  url=$(oc get route tekton-webhook -n "${CICD_NS}" -o jsonpath='https://{.spec.host}')
  ok "Webhook route: ${url}"
else
  fail "Route tekton-webhook not found in ${CICD_NS}"
fi

echo
echo "--- Sample app (dev) ---"
if oc get deployment -n sample-camel-dev -l app.kubernetes.io/name=sample-camel &>/dev/null; then
  ok "sample-camel deployment in sample-camel-dev"
else
  fail "sample-camel deployment not found in sample-camel-dev"
fi

echo
if [ "${FAILED}" -eq 0 ]; then
  echo -e "${GREEN}All checks passed.${NC}"
  exit 0
else
  echo -e "${RED}Some checks failed — see messages above.${NC}"
  exit 1
fi
