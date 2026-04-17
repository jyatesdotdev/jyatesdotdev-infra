# jyatesdotdev-infra

This repository holds the Infrastructure as Code (IaC) configuration for `jyates.dev`, orchestrating the entirely serverless AWS architecture.

## Overview

The `jyates.dev` stack is designed for ultra-low base cost, global scale, and hardened DDoS resistance.

* **DNS & Content Delivery**: Name.com DNS delegates to AWS Route53. AWS CloudFront handles edge caching and SSL (AWS ACM), distributing traffic between the static S3 SPA and the API Gateway.
* **Compute Layer**: AWS API Gateway routes traffic to highly restricted AWS Lambda Go functions. 
* **Database Layer**: Amazon DynamoDB running in `PAY_PER_REQUEST` (On-Demand billing). 
* **Observability**: AWS CloudWatch RUM handles frontend telemetry. A unified CloudWatch Dashboard tracks requests, error rates, and estimated costs in a single view.
* **Security & Costs**: 
    - CloudFront WAF shields against layer 7 DDoS.
    - API Gateway employs API Keys to restrict raw access.
    - Lambdas have strict concurrency limits.
    - AWS Budgets monitor forecasted billing limits.

## How it works

This repository acts as the "Brain" of the deployment lifecycle. It does **not** deploy itself on push.

Instead, the `jyatesdotdev-frontend` and `jyatesdotdev-api` repositories listen for pushes to `main`. When either pipeline successfully compiles code, it pings this repository via a GitHub Action `repository_dispatch` webhook.

This repository catches that webhook and runs `terraform apply`, fetching the new ZIPs/Assets and performing a zero-downtime structural update natively inside AWS.

## Setup & Required Secrets

Terraform requires several API keys to communicate externally. Before GitHub Actions can trigger Terraform, you must deploy these as Repository Secrets:

* `AWS_ACCESS_KEY_ID`: Your AWS deployment user credentials.
* `AWS_SECRET_ACCESS_KEY`: Your AWS deployment user credentials.
* `TERRAFORM_ROLE_ARN`: The IAM Role Terraform assumes to run operations.
* `NAMEDOTCOM_USERNAME`: Registrar API username (for automated DNS delegation).
* `NAMEDOTCOM_TOKEN`: Registrar API key.
* `ADMIN_USERNAME`: Basic auth username for the dashboard.
* `ADMIN_PASSWORD`: Basic auth password.
* `SES_FROM_EMAIL`: Authorized SES sender identity.
* `SES_ADMIN_EMAIL`: Authorized SES recipient for comment notifications.
* `RECAPTCHA_SECRET`: Google ReCaptcha v3 server key.
