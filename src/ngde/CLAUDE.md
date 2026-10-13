# NGDE workspace

Parent folder for the AFTC_CDSS (NGDE / CTDSS) repos. Not a git repo itself.
Each repo is cloned from `https://www.trmc.osd.mil/bitbucket/scm/aftc_cdss/<name>.git`
and has its own git history, branches, and PRs. Jira keys are `AFTC_CDSS-<n>`.

Open everything with `code-insiders ngde.code-workspace` (alias `ngde`).
`bootstrap.sh` re-clones the repos on a new machine.
`./dev` runs common tasks (repo sync, CRC start/stop/login, PL3 prereqs, health
check); `./dev help` lists them. The workspace's VS Code tasks call it, so add
new logic to `dev`, not to `tasks.json`.
The root files (`dev`, `bootstrap.sh`, `ngde.code-workspace`, this file,
`.vscode/settings.json`) are managed by chezmoi on `dev_openshift` machines. Edit
them here, then `chezmoi re-add` and commit in `~/.local/share/chezmoi`.

## Repos

| Dir | What it is | Stack | Default branch |
|-----|------------|-------|----------------|
| `ctdss-api` | Backend API; bridges the UI, the metadata DB, and Airflow | Python | `Dev` |
| `ctdss-ui` | CTDSS UI plus an Express auth proxy (OIDC session, forwards to ctdss-api) | React/TS, Node | `Dev` |
| `nas-airflow` | CTDSS Airflow: DAGs that process files; vendors `nas_airflow_support` | Python, Airflow | `Dev` |
| `arbiter` | On-demand creation/management of programs on OpenShift (PL3 SAP/SAR) | Python, Alembic | `Dev` |
| `arbiter-ui` | Arbiter frontend | React, TanStack | `Dev` |
| `iac` | Ansible, Helm, and the ctdss operator for PL2 (`pl2/`) and PL3 (`pl3/`); onboarding docs in `docs/` | Ansible, Helm | `Dev` |
| `iac-pl3` | Git worktree of `iac` (shares its `.git`), used for PL3 work in parallel | | detached |
| `pipeline-shared-lib` | Jenkins shared library used by every repo's `Jenkinsfile` | Groovy | `main` |
| `scan-triage` | Local notes/scripts for SAST/SCA triage. Not a repo | | |

## How they fit together

- Request path: browser -> `ctdss-ui` proxy -> `ctdss-api` -> metadata DB and Airflow (`nas-airflow`).
- `arbiter` / `arbiter-ui` are a separate app pair on the same platform.
- Each app repo has an `iac/` dir for its own container build; deployment (Helm charts, operator, Ansible) lives in the `iac` repo.
- CI: each repo's `Jenkinsfile` imports `pipeline-shared-lib`. A change to a shared step affects all of them.

## Working across repos

- `iac` and `iac-pl3` are the same repo. A branch checked out in one can't be checked out in the other.
- A change that spans repos means one branch and one PR per repo. Use the same Jira key in each branch name.
- Run git commands with `git -C <repo>`. There is no git repo at this level.
- Per-repo details belong in that repo's own CLAUDE.md, not here.
