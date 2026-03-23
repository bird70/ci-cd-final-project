# CI/CD Tools and Practices Final Project Template

This repository contains the template to be used for the Final Project for the Coursera course **CI/CD Tools and Practices**.

## Usage

This repository is to be used as a template to create your own repository in your own GitHub account. No need to Fork it as it has been set up as a Template. This will avoid confusion when making Pull Requests in the future.

From the GitHub **Code** page, press the green **Use this template** button to create your own repository from this template.

Name your repo: `ci-cd-final-project`.

## Setup

After entering the lab environment you will need to run the `setup.sh` script in the `./bin` folder to install the prerequisite software.

```bash
bash bin/setup.sh
```

Then you must exit the shell and start a new one for the Python virtual environment to be activated.

```bash
exit
```

## Tasks

## Granting an External Environment Access to This Repo (PAT Setup)

External CI/CD systems – such as a Tekton pipeline running on OpenShift or IBM Cloud – need a **GitHub Personal Access Token (PAT)** to clone, commit, and push code on your behalf.

### Step 1 – Create a GitHub PAT

1. Log in to <https://github.com> and click your **profile avatar → Settings**.
2. Scroll to **Developer settings** (bottom of the left sidebar) → click it.
3. Choose **Personal access tokens → Tokens (classic)**.
4. Click **Generate new token → Generate new token (classic)**.
5. Give the token a descriptive name, e.g. `ci-cd-final-project-pat`.
6. Set an appropriate expiration (90 days is a sensible default).
7. Grant the scopes your pipeline needs:
   - ✅ **`repo`** – full read/write access to private repositories
   - ✅ **`workflow`** – allows updating GitHub Actions workflow files
8. Click **Generate token** and **copy the value immediately** – GitHub shows it only once.

### Step 2 – Store the PAT as a Kubernetes / OpenShift Secret

Export your credentials and run the helper script:

```bash
export GITHUB_ACCOUNT=<your-github-username>
export GITHUB_TOKEN=<the-pat-you-just-created>
bash bin/create-github-secret.sh
```

This creates a `kubernetes.io/basic-auth` Secret named **`github-token`** and annotates it so Tekton knows it belongs to `https://github.com`.

### Step 3 – Apply the Tekton Tasks

```bash
kubectl apply -f .tekton/tasks.yml
```

### Step 4 – Reference the Secret in Your Pipeline

In any Tekton `PipelineRun` or `TaskRun` that needs GitHub access, bind the secret to the `github-credentials` workspace:

```yaml
workspaces:
  - name: github-credentials
    secret:
      secretName: github-token
```

### GitHub Actions (optional)

A CI workflow is already configured in `.github/workflows/workflow.yml`. It runs lint and unit tests automatically on every push or pull-request to `main` – no extra credentials are required for that workflow because GitHub Actions has built-in `GITHUB_TOKEN` access.

If you need to *write* back to the repository from a workflow step, add your PAT as a repository secret:

1. Go to **Settings → Secrets and variables → Actions** in your repo.
2. Click **New repository secret**.
3. Name it `GH_PAT` and paste your token value.
4. Use it in a workflow step with `${{ secrets.GH_PAT }}`.

## License

Licensed under the Apache License. See [LICENSE](/LICENSE)

## Author

Skills Network

## <h3 align="center"> © IBM Corporation 2023. All rights reserved. <h3/>
