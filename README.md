# terraform-aws-autoscale-infra

> A prep cook doesn't staff a full team at 7am. They scale up for the dinner rush and down after close.
> This infrastructure does the same — it grows under load, shrinks when idle, and costs nothing to recreate.

Production-grade, cost-optimized, highly available web infrastructure on AWS. Provisioned entirely
with Terraform across 8 phases. Every resource has a reason. Every decision is documented.

**Live URL after deploy:**
`http://<alb_dns_name>.us-east-1.elb.amazonaws.com` — refresh to watch the ALB round-robin between AZs.

---

## Architecture

```
                            Internet
                                │
                      ┌─────────▼──────────┐
                      │  Application Load   │  ports 80/443
                      │  Balancer (ALB)     │  drop_invalid_header_fields
                      │  multi-AZ           │  desync_mitigation: defensive
                      └──────┬─────┬────────┘
                             │     │
               ┌─────────────┘     └──────────────┐
               │                                  │
     ┌─────────▼──────────┐            ┌──────────▼─────────┐
     │    us-east-1a       │            │    us-east-1b       │
     │    10.0.1.0/24      │            │    10.0.2.0/24      │
     │  ┌──────────────┐  │            │  ┌──────────────┐  │
     │  │  EC2 t3.micro │  │            │  │  EC2 t3.micro │  │
     │  │  AL2023       │  │            │  │  AL2023       │  │
     │  │  Apache/httpd │  │            │  │  Apache/httpd │  │
     │  └──────────────┘  │            │  └──────────────┘  │
     └────────────────────┘            └────────────────────┘
               │                                  │
               └─────────────┬────────────────────┘
                             │
                   ┌─────────▼──────────┐
                   │   Auto Scaling     │
                   │   min 1            │
                   │   desired 2        │
                   │   max 4            │
                   └─────────┬──────────┘
                             │
                   ┌─────────▼──────────┐
                   │   CloudWatch       │
                   │   CPU > 70% → +1   │
                   │   CPU < 20% → -1   │
                   └────────────────────┘

VPC: 10.0.0.0/16  │  Region: us-east-1  │  State: S3 (use_lockfile, no DynamoDB)
```

---

## The Business Case

This project exists to answer one question a recruiter or hiring manager will ask:
**"Can this person make infrastructure decisions, not just follow tutorials?"**

### Cost Comparison

| Approach | Monthly AWS Cost | Availability | Ops Overhead |
|---|---|---|---|
| Fixed t3.medium, always-on, single AZ | ~$33/mo | ~99.5% | 2–4 hrs/change |
| This project (autoscaling, multi-AZ) | ~$18–22/mo | ~99.95% | Zero — it's code |
| **Saving** | **~$11–15/mo** | **+0.45% uptime** | **$150–$300/change eliminated** |

The AWS bill difference is the smaller number. The real saving is operational:

- Manual provisioning at $75/hr consulting rate = **$150–$300 per infrastructure change**
- This project's provisioning cost = `terraform apply` = **$0**, reproducible in under 10 minutes
- Estimated annual operational saving = **$1,800–$3,600+**

At minimum capacity (1 instance, quiet periods), total AWS cost drops to **~$14/month**.

### Why Each Decision Was Made

**`use_lockfile = true` instead of DynamoDB** Terraform 1.11 deprecated `dynamodb_table` for
state locking. S3 native conditional writes handle locking without a second service to provision,
pay for, or grant IAM permissions to. Simplified the stack and eliminated a dependency.

**Dynamic AMI lookup via data source**  `data "aws_ami"` with the `al2023-ami-*-x86_64` filter
resolves the current AMI at plan time. Hardcoded AMI IDs go stale, break across regions, and fail
silently. Lesson carried forward from a Jenkins build that failed because of a hardcoded ID.

**Layered security groups**  The EC2 security group's ingress rule references the ALB security
group ID as its source, not a CIDR range. Even if an instance's public IP is discovered,
the connection is rejected at the network level. `cidr_blocks = []` on the EC2 ingress is
intentional.

**IMDSv2 required on the launch template**  `http_tokens = "required"` forces the two-step
metadata token fetch, preventing SSRF attacks against the instance metadata service. A CIS
benchmark requirement. One line in the launch template.

**SSM Session Manager instead of SSH**  The EC2 IAM role grants `AmazonSSMManagedInstanceCore`.
No port 22 open, no key pairs to manage, no bastion host to maintain. Full shell access via
the AWS console or CLI, with a CloudTrail audit trail on every session.

**`create_before_destroy` on the ASG**  Prevents a gap in serving capacity when the ASG is
replaced. The new group reaches healthy capacity before the old one terminates.

**`prevent_destroy` on the S3 state bucket** — Terraform stops with an error rather than deleting
the bucket that holds all infrastructure state. One lifecycle guard prevents an irreversible mistake.

**Provider-level `default_tags`** — `Project`, `ManagedBy`, and `Repository` are injected on every
AWS resource automatically. No tag drift. No per-resource boilerplate. Full cost attribution and
audit trail without repetition.

---

## What's Built

| Phase | What | Resources |
|---|---|---|
| 1 — Remote State | S3 bucket: versioned, AES256, block public access, `use_lockfile` | 5 |
| 2 — Networking | VPC `10.0.0.0/16`, 2 public subnets, IGW, route tables | 8 |
| 3 — Security | ALB SG (80/443 from internet), EC2 SG (80 from ALB only) | 2 |
| 4 — Compute | IAM role + SSM profile, AL2023 launch template, ASG | 5 |
| 5 — Load Balancer | ALB, target group, HTTP listener, ASG attachment | 4 |
| 6 — Intelligence | CloudWatch alarms, scale-out + scale-in policies | 4 |
| 7 — CI/CD | GitHub Actions: fmt, validate, plan on every push and PR | — |
| **Total AWS resources** | | **28** |

---

## Project Structure

```
terraform-aws-autoscale-infra/
├── bootstrap/                  # One-time S3 remote state setup — run once, never touch again
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── providers.tf                # S3 backend + AWS provider v6 + default_tags
├── variables.tf                # All input variables with defaults
├── locals.tf                   # Computed name_prefix and common_tags
├── main.tf                     # VPC, subnets, IGW, route tables
├── security_groups.tf          # Layered ALB and EC2 security groups
├── iam.tf                      # EC2 IAM role, policy attachment, instance profile
├── compute.tf                  # AMI data source, launch template, ASG
├── alb.tf                      # ALB, target group, listener, ASG attachment
├── cloudwatch.tf               # Scaling policies and CloudWatch alarms
├── outputs.tf                  # Full infrastructure output values
├── terraform.tfvars            # Explicit deployment values
└── .github/
    └── workflows/
        └── terraform-ci.yml    # CI: fmt check, validate, plan on PRs
```

---

## How to Deploy

**Prerequisites:**
- Terraform >= 1.11.0
- AWS CLI configured (`aws sts get-caller-identity` should return your account)
- IAM user with EC2, S3, IAM, ELB, CloudWatch, and AutoScaling permissions
- `us-east-1` region

**Step 1 — Bootstrap remote state (one time only):**

```bash
cd bootstrap
terraform init
terraform plan   # Expect: 5 to add
terraform apply
cd ..
```

Copy the `backend_config_snippet` output into `providers.tf` if deploying fresh.

**Step 2 — Deploy main infrastructure:**

```bash
terraform init
terraform plan   # Review before applying
terraform apply
```

The `alb_dns_name` output is your live URL. Allow 3–5 minutes for instances to
finish `user_data` (dnf update + Apache install) and pass ALB health checks.

**To verify it's working:**

```bash
curl http://<alb_dns_name>.us-east-1.elb.amazonaws.com
```

Refresh multiple times — the AZ in the response alternates between `us-east-1a` and `us-east-1b`.

**To tear down:**

```bash
terraform destroy
# The S3 state bucket has prevent_destroy = true.
# Remove that lifecycle block in bootstrap/main.tf before destroying bootstrap.
```

---

## Monthly Cost Estimate (us-east-1, on-demand)

| Resource | Quantity | Monthly Cost |
|---|---|---|
| Application Load Balancer | 1 | ~$7.00 |
| EC2 t3.micro — minimum (1 instance) | 1 | ~$7.49 |
| EC2 t3.micro — typical (2 instances) | 2 | ~$14.98 |
| S3 state bucket (KB of state data) | 1 | ~$0.01 |
| CloudWatch alarms | 2 | ~$0.20 |
| **Total — minimum capacity** | | **~$14.70/mo** |
| **Total — typical load** | | **~$22.19/mo** |

Cost scales automatically. At low traffic, the ASG scales to 1 instance.
At high traffic, it scales to 4. You pay for what you use.

---

## Stack

| Tool | Version | Purpose |
|---|---|---|
| Terraform | >= 1.11.0 | Infrastructure provisioning |
| AWS Provider | ~> 6.0 | AWS API integration |
| Amazon Linux 2023 | Latest (dynamic) | EC2 instance OS |
| Apache httpd | Latest via dnf | Web server |
| GitHub Actions | — | CI/CD validation |

---

## Built By

**Matt Shaw** — Cloud Engineer  
Documenting the transition from professional kitchen to cloud infrastructure at
[Terraforming My Career](https://www.linkedin.com/newsletters/terraforming-my-career-7395876133298343936)

Kitchens and cloud systems fail the same way. I learned to prevent both.

[mattrshaw.com](https://mattrshaw.com) · [LinkedIn](https://www.linkedin.com/in/mattrshaw4) · [GitHub](https://github.com/mattrshaw4)
