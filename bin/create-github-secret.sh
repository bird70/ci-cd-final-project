#!/bin/bash
# =============================================================================
# create-github-secret.sh
#
# Creates (or replaces) the Kubernetes / OpenShift Secret called
# 'github-token' that Tekton pipelines use to authenticate to GitHub.
#
# Usage:
#   export GITHUB_ACCOUNT=<your-github-username>
#   export GITHUB_TOKEN=<your-personal-access-token>
#   bash bin/create-github-secret.sh
#
# HOW TO CREATE A GITHUB PAT (classic)
# -----------------------------------------------------------------------
# 1. Log in to https://github.com and click your profile avatar → Settings.
# 2. In the left sidebar scroll to "Developer settings" → click it.
# 3. Choose "Personal access tokens" → "Tokens (classic)".
# 4. Click "Generate new token" → "Generate new token (classic)".
# 5. Give the token a descriptive name, e.g. "ci-cd-final-project-pat".
# 6. Set an expiration (90 days is a sensible default).
# 7. Select the scopes your pipeline needs:
#      ✅ repo         – full read/write access to private repositories
#      ✅ workflow     – allows updating GitHub Actions workflow files
# 8. Click "Generate token" and COPY the value immediately.
#    GitHub shows it only once!
# 9. Set the environment variables below and run this script.
# =============================================================================

set -euo pipefail

# ── Validate inputs ──────────────────────────────────────────────────────────
if [[ -z "${GITHUB_ACCOUNT:-}" ]]; then
  echo "ERROR: GITHUB_ACCOUNT environment variable is not set."
  echo "       Export it with: export GITHUB_ACCOUNT=<your-github-username>"
  exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN environment variable is not set."
  echo "       Export it with: export GITHUB_TOKEN=<your-personal-access-token>"
  exit 1
fi

SECRET_NAME="github-token"
GITHUB_HOST="https://github.com"

echo "Creating Kubernetes secret '${SECRET_NAME}' for GitHub user '${GITHUB_ACCOUNT}'..."

# Delete existing secret if present (idempotent)
if kubectl get secret "${SECRET_NAME}" &>/dev/null 2>&1; then
  echo "Deleting existing secret '${SECRET_NAME}'..."
  kubectl delete secret "${SECRET_NAME}"
fi

# Create the basic-auth secret
kubectl create secret generic "${SECRET_NAME}" \
  --from-literal=username="${GITHUB_ACCOUNT}" \
  --from-literal=password="${GITHUB_TOKEN}" \
  --type=kubernetes.io/basic-auth

# Annotate so Tekton knows which host this secret applies to
kubectl annotate secret "${SECRET_NAME}" \
  "tekton.dev/git-0=${GITHUB_HOST}"

echo ""
echo "✅  Secret '${SECRET_NAME}' created successfully."
echo ""
echo "Next steps:"
echo "  1. Apply the Tekton tasks:  kubectl apply -f .tekton/tasks.yml"
echo "  2. Reference the secret in your Pipeline/PipelineRun workspaces:"
echo "     workspaces:"
echo "       - name: github-credentials"
echo "         secret:"
echo "           secretName: ${SECRET_NAME}"
