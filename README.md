<div align="center">

# ⚡ ResQOps

### Automated Disaster Recovery Platform on AWS

*Detects cloud failures and recovers across regions — fully automated, zero human intervention.*

[![CI/CD](https://github.com/Niladri11/ResQops/actions/workflows/ci.yml/badge.svg)](https://github.com/Niladri11/ResQops/actions/workflows/ci.yml)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-Multi--Region-FF9900?logo=amazonaws)
![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?logo=docker)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-OIDC_CI%2FCD-2088FF?logo=githubactions)
![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?logo=prometheus)

</div>

---

## 🎯 What ResQOps Does

Every minute of cloud downtime costs money. Most companies have no automated DR plan — they rely on engineers manually detecting failures and reacting.

**ResQOps eliminates that gap.**

When the primary AWS region (Mumbai) degrades or fails:

1. 🔴 **Prometheus** detects the failure within 15 seconds
2. 📣 **AlertManager** fires a webhook to Lambda
3. ⚡ **Lambda** triggers the DR failover sequence
4. 🌏 **Singapore region** (ap-southeast-1) comes online automatically
5. 💬 **Slack** notifies the team throughout the entire process

**RTO achieved: under 8 minutes — no human required.**
---

## 🎬 Demo

> Full live demo — automated failover from Mumbai to Singapore, Prometheus alerting, Lambda trigger, and Slack notifications end to end.

[![Watch Demo](https://img.youtube.com/vi/H_psx-2Tx9w/maxresdefault.jpg)](https://youtu.be/H_psx-2Tx9w?si=0lz0jl-zmPcXASi9)

---

## 🏗️ Architecture

<img width="896" height="901" alt="image" src="https://github.com/user-attachments/assets/af88b39d-991d-4e60-9ba7-6760c7bab61a" />



---

## 🛠️ Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| ☁️ Cloud | AWS (EC2, RDS, ECR, Lambda, SNS, VPC, IAM) | Core infrastructure |
| 🏗️ IaC | Terraform | Multi-region infra as code |
| 📦 Containers | Docker | App containerization |
| 🔄 CI/CD | GitHub Actions + OIDC | Zero-credential pipeline |
| 📊 Monitoring | Prometheus + Grafana | Real-time observability |
| 🚨 Alerting | AlertManager + Slack | Automated notifications |
| ⚡ DR Trigger | AWS Lambda + SNS | Serverless failover logic |
| 🐍 App | Python (Flask) | Demo application |

---

## 🔐 Security Design

ResQOps is built with security at every layer — not bolted on at the end.

```
Identity Layer    →  OIDC-based auth (zero static AWS credentials in GitHub)
Code Layer        →  TruffleHog secret scanning on every push
IAM Layer         →  Least-privilege roles (only what each service needs)
Network Layer     →  VPC private subnets for RDS (never exposed to internet)
Container Layer   →  ECR image scanning (CVE detection on base images)
```

---

## 🔄 CI/CD Pipeline

Every push to `main` triggers:

```
1. Checkout code
2. OIDC → AWS assumes role (no keys stored anywhere)
3. Build Docker image
4. Tag with commit SHA
5. Push to ECR
6. SSH deploy to EC2
7. Health check → confirm app is live
```

> 📸 *GitHub Actions screenshot — coming soon*

---

## 📊 Monitoring & Observability

**Prometheus** scrapes app metrics every **15 seconds**:
- HTTP request rate
- Error rate (5xx responses)
- Response latency (p50 / p95 / p99)
- Instance health

**Grafana** dashboard surfaces 4 key panels:
- Request rate over time
- Error rate %
- p95 latency
- Active instances (primary vs DR)

**AlertManager** rule: if error rate > 10% for 2 consecutive minutes → fire alert → trigger Lambda.

<img width="1851" height="817" alt="image" src="https://github.com/user-attachments/assets/6b370f40-17ee-48de-a030-b62f12d795e3" />



---

## ⚡ DR Flow — Step by Step

```
[1] Prometheus: error_rate > 10% for 2m         → alert fires
[2] AlertManager: routes to webhook receiver     → POST to Lambda URL
[3] Lambda: validates payload                    → triggers DR sequence
[4] SNS: publishes DR_TRIGGERED event            → Slack message #1 sent
[5] Terraform: provisions Singapore infra        → EC2 + RDS come up
[6] EC2: pulls Docker image from ECR             → container starts
[7] Health check: GET /health → 200 OK           → confirmed live
[8] SNS: publishes DR_COMPLETE event             → Slack message #2 sent

Total elapsed: < 8 minutes
```

<img width="1025" height="372" alt="image" src="https://github.com/user-attachments/assets/a5fbaf9c-f7fc-418a-ad4d-3f2801397e6c" />



---

## 📁 Project Structure

```
ResQops/
├── .github/
│   └── workflows/
│       ├── ci.yml              # Build + push to ECR
│       └── dr-deploy.yml       # DR region deployment
├── Terraform/
│   ├── main.tf                 # Primary region (ap-south-1)
│   ├── variables.tf
│   ├── outputs.tf
│   └── dr-region/
│       └── main.tf             # DR region (ap-southeast-1)
├── app/
│   ├── app.py                  # Flask API
│   ├── requirements.txt
│   └── Dockerfile
├── lambda/
│   └── dr_trigger.py           # Failover logic
├── monitoring/
│   ├── prometheus.yml          # Scrape config
│   └── alertmanager.yml        # Alert routing (gitignored)
└── README.md
```

---

## 🚀 Setup

> ⚠️ **Prerequisites:** AWS account, Terraform installed, Docker installed, GitHub repo with OIDC configured.

```bash
# 1. Clone the repo
git clone https://github.com/Niladri11/ResQops.git
cd ResQops

# 2. Configure your variables (never commit this file)
cp Terraform/terraform.tfvars.example Terraform/terraform.tfvars
# Edit terraform.tfvars with your AWS account details

# 3. Provision primary region infrastructure
cd Terraform
terraform init
terraform apply

# 4. Push to main branch to trigger CI/CD pipeline
git push origin main
```

---

## 📐 Key Concepts Demonstrated

| Concept | How It's Implemented |
|---|---|
| **RTO < 8 min** | Lambda-triggered failover, no manual steps |
| **Zero-credential CI/CD** | GitHub OIDC → AWS temporary credentials |
| **Infrastructure as Code** | Terraform modules parametrized by region |
| **Proactive monitoring** | Prometheus detects degradation before full failure |
| **Least-privilege IAM** | Separate roles for EC2, Lambda, GitHub Actions |
| **Secret hygiene** | TruffleHog in CI + gitignored sensitive configs |

---

## 👤 Author

**Niladri Tewari**
B.Tech CSE (Cybersecurity) · The Neotia University · Graduating 2027
Targeting Cloud & DevOps Engineering roles

[![LinkedIn](https://img.shields.io/badge/LinkedIn-niladritewari-0A66C2?logo=linkedin)](https://linkedin.com/in/niladritewari)
[![GitHub](https://img.shields.io/badge/GitHub-Niladri11-181717?logo=github)](https://github.com/Niladri11)

---

<div align="center">

*Built to solve a real problem. Every component is intentional.*

⭐ Star this repo if you found it useful

</div>
