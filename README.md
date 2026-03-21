# ResQOps — Automated Disaster Recovery Platform

[![CI/CD](https://github.com/Niladri11/ResQops/actions/workflows/ci.yml/badge.svg)](your-actions-url)

> Production-grade cloud infrastructure platform that automatically 
> detects failures and recovers across AWS regions in under 8 minutes.

## The Problem
Every minute of cloud downtime costs $5,600 on average. 73% of 
companies have no automated DR plan. ResQOps solves this.

## Architecture
![Architecture](docs/architecture.png)

## Live Demo
[▶ Watch 3-min demo video](your-youtube-link)

## What It Does
- Monitors a production Flask API on AWS EC2
- Detects downtime via Prometheus + AlertManager
- Automatically triggers DR deployment in a second AWS region
- Notifies team via Slack throughout the recovery process
- Achieves RTO of under X minutes

## Tech Stack
| Category | Tools |
|---|---|
| Cloud | AWS (EC2, ECR, RDS, Lambda, SNS, VPC, IAM) |
| IaC | Terraform |
| Containers | Docker |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus, Grafana, AlertManager |
| Alerting | Slack Webhooks |
| DR Trigger | AWS Lambda, SNS |
| Language | Python (Flask), Bash |

## CI/CD Pipeline
![GitHub Actions](docs/screenshots/github-actions.png)
Every push triggers: test → build → ECR push → deploy → health check

## Monitoring Dashboards
### Application Metrics
![App Dashboard](docs/screenshots/grafana-app.png)

### System Health  
![System Dashboard](docs/screenshots/grafana-system.png)

## Alerting & DR Flow
![Slack Alerts](docs/screenshots/slack-alerts.png)

1. Prometheus detects AppDown
2. AlertManager fires Slack alert + triggers SNS
3. Lambda receives SNS → triggers GitHub Actions DR workflow
4. Terraform provisions infrastructure in ap-southeast-1
5. Docker pulls image → container starts → health check passes
6. Slack confirms DR complete

## RTO Achieved
**X minutes Y seconds** from failure detection to DR region healthy

## Setup
\`\`\`bash
git clone https://github.com/Niladri11/ResQops
cd ResQops/terraform
terraform init
terraform apply
\`\`\`

## Project Structure
\`\`\`
ResQops/
├── app/                    # Flask API
├── terraform/              # Primary region IaC
│   └── dr-region/          # DR region IaC
├── lambda/                 # DR trigger function
├── monitoring/             # Prometheus + AlertManager configs
├── grafana/dashboards/     # Exported dashboard JSONs
├── .github/workflows/      # CI/CD + DR pipelines
└── docs/                   # Architecture diagram + screenshots
\`\`\`
```

---

## DAY 32 — Record Demo Video

This is non-negotiable. A 3 minute video does more than any README.

**Use:** Loom (free) or Windows screen recorder `Win + G`

**Script — exactly what to show:**
```
0:00 - 0:20  Show GitHub repo + README
0:20 - 0:40  Show GitHub Actions green CI/CD run
0:40 - 1:10  Show Prometheus Targets page — both UP
1:10 - 1:40  Show Grafana dashboards — app + system
1:40 - 2:10  Stop Docker container
             Show Slack 🔴 AppDown alert firing
2:10 - 2:40  Show DR EC2 spinning up in ap-southeast-1
             Show curl http://dr-ip:5000/health returning ok
2:40 - 3:00  Show Slack ✅ Resolved + DR Complete messages
```

Upload to YouTube as **Unlisted**. Paste link in README under Live Demo section.

---

## DAY 33 — Final Cleanup + Commit

**Clean up your GitHub repo:**
```
✅ No hardcoded secrets anywhere
✅ .gitignore has: *.tfvars, alertmanager.yml, .env
✅ All config files have placeholder values
✅ README has screenshots + video link
✅ Architecture diagram in docs/
✅ Grafana dashboard JSONs exported and committed
