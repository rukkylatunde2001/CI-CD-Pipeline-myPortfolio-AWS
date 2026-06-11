# CI/CD Pipeline — Portfolio Website Deployment on AWS

![Pipeline Status](https://img.shields.io/badge/Pipeline-Passing-brightgreen)
![AWS](https://img.shields.io/badge/AWS-CodePipeline-orange)
![Docker](https://img.shields.io/badge/Docker-Containerised-blue)
![ECS](https://img.shields.io/badge/Amazon-ECS%20Fargate-orange)

A fully automated CI/CD pipeline built on AWS that detects code changes on GitHub, builds a Dockerised static portfolio website, and deploys it to Amazon ECS Fargate — with zero manual steps after the initial setup.

> **"Every push to GitHub automatically builds a new Docker image, pushes it to ECR, and deploys an updated container to ECS — no manual steps required."**

---

## Live Demo

![Live Portfolio Website](screenshots/correct-load.png)

---

## Architecture

![Architecture Diagram](screenshots/architecture.png)

Website source code lives in a GitHub repository. Every push to the `main` branch triggers **AWS CodePipeline** via a GitHub App connection. The pipeline runs three automated stages:

1. **Source** — CodePipeline detects the push and pulls the latest code from GitHub.
2. **Build** — AWS CodeBuild reads `buildspec.yml`, builds a Docker image from the `Dockerfile` (using nginx as the web server), and pushes the image to **Amazon ECR** (Elastic Container Registry).
3. **Deploy** — Amazon ECS Fargate pulls the new image from ECR, stops the old container task, and launches a new task running the updated website — live on the internet within minutes.

IAM roles and policies control secure access between every service throughout the pipeline.

---

## Pipeline Success

![CodePipeline All Stages Green](screenshots/working-pipeline.png)

Every push to the `main` branch triggers the full Source → Build → Deploy pipeline automatically.

---

## Pipeline Test — Proving Automation Works

This section documents a real end-to-end test of the pipeline using a deliberate content error.

### The Problem: Missing CSS Files

During the initial GitHub upload, only `fontawesome-all.min.css` was added to `assets/css/`. The main stylesheet (`main.css`), JavaScript folder (`js/`), Sass files (`sass/`), and web fonts (`webfonts/`) were missing.

![GitHub Missing Assets Folder](screenshots/incorrect-assetfolder.png)

The pipeline ran automatically, built the image, and deployed it — but the website loaded **without any styling**, because the CSS files simply were not there.

![Unstyled Website](screenshots/bad-website.png)

### The Fix: Correct the GitHub Source

The full `assets/` folder was uploaded to GitHub — including `main.css`, `js/`, `sass/`, and `webfonts/`. This commit automatically triggered the pipeline with no manual intervention needed.

### The Result: Automated Redeploy

CodeBuild detected the new commit, rebuilt the Docker image with the complete assets, and pushed a new image to ECR.

![CodeBuild Succeeded](screenshots/build-success.png)

ECR now holds the updated image, confirming the build completed successfully.

![ECR Updated Image](screenshots/ECR-updated.png)

ECS deployed the updated container automatically, and the website loaded with full styling, layout, and icons — exactly as designed.

![Styled Website](screenshots/correct-load.png)

This proves the CI/CD pipeline is working correctly: **a change to GitHub = an automatic update to the live website.**

---

## AWS Services Used

| Service | Purpose |
|---|---|
| **GitHub** | Source control — pipeline triggers on every push to `main` |
| **AWS CodePipeline** | Orchestrates the full Source → Build → Deploy workflow |
| **AWS CodeBuild** | Builds the Docker image and pushes it to ECR |
| **Amazon ECR** | Private Docker image registry — stores every built image |
| **Amazon ECS Fargate** | Runs the containerised website serverlessly (no EC2 to manage) |
| **Amazon VPC** | Network isolation for the ECS cluster and tasks |
| **AWS IAM** | Manages secure permissions between all services |
| **Amazon CloudWatch** | Stores CodeBuild logs for debugging |

---

## Key Files in This Repository

| File | Purpose |
|---|---|
| `Dockerfile` | Instructions for building the Docker image using nginx |
| `buildspec.yml` | CodeBuild instruction file — log in to ECR, build, tag, push image |
| `index.html` | Portfolio homepage |
| `assets/` | CSS, JavaScript, Sass, and web fonts |
| `images/` | Project images used in the portfolio |

---

## How It Was Built — Step by Step

**1. Created the GitHub repository**
Created a new public GitHub repository named `CI-CD-Pipeline-myPortfolio-AWS` and uploaded all portfolio files directly via the GitHub web interface — no local Git commands needed. Files uploaded: `index.html`, `assets/`, `images/`, `Dockerfile`, and `buildspec.yml`.

**2. Wrote the Dockerfile**
Created a `Dockerfile` at the root of the repository with no file extension (not `Dockerfile.txt`). It uses `public.ecr.aws/nginx/nginx:alpine` (AWS's own public image registry — avoids Docker Hub rate limits) as the base, removes the default nginx welcome page, copies all portfolio files into the nginx web root, exposes port 80, and starts nginx in the foreground.

**3. Wrote buildspec.yml**
Created `buildspec.yml` at the root of the repository with three phases:
- **pre_build**: Authenticates with ECR using `aws ecr get-login-password`
- **build**: Runs `docker build` and `docker tag` to label the image with the ECR URI
- **post_build**: Runs `docker push` to upload the image to ECR, then creates `imagedefinitions.json` (the file that tells ECS which container name to update and what new image to pull)

**4. Created the ECR repository**
In AWS ECR, created a private repository named `rukayat-portfolio` in `us-east-1`. Copied the repository URI and updated `buildspec.yml` on GitHub with the real URI to replace the placeholder values.

**5. Created the CodeBuild IAM role**
In AWS IAM, created a role named `CodeBuildPortfolioRole` with a trusted relationship for `codebuild.amazonaws.com`. Attached three managed policies: `AmazonEC2ContainerRegistryFullAccess`, `AWSCodeBuildDeveloperAccess`, and `AmazonS3FullAccess`. Added a custom inline policy to allow `ecs:UpdateService` and `ecs:DescribeServices`.

**6. Set up the CodeBuild project**
In AWS CodeBuild, created a project named `portfolio-build` connected to the GitHub repository. Set the environment to Ubuntu with image `aws/codebuild/standard:7.0`, enabled **Privileged mode** (required for Docker builds inside CodeBuild), and attached `CodeBuildPortfolioRole` as the service role.

**7. Ran CodeBuild once to seed ECR**
Triggered the CodeBuild project manually one time before setting up ECS. This produced the first Docker image and pushed it to ECR. ECS requires at least one image in ECR before a Task Definition can reference it.

**8. Set up the ECS cluster**
In Amazon ECS, created a cluster named `portfolio-cluster` using AWS Fargate. Used AWS CloudShell (a browser-based terminal — no local installation needed) to register the ECS service-linked role, then deleted a broken CloudFormation stack left over from a failed cluster attempt, and recreated the cluster successfully.

**9. Created the ECS Task Definition**
In ECS, created a task definition named `portfolio-task` specifying: Fargate launch type, Linux/X86_64, 0.25 vCPU, 0.5 GB memory, container name `portfolio-container`, ECR image URI with `:latest`, and port mapping 80/TCP. The container name must exactly match what is written in `imagedefinitions.json` or the deploy stage will fail.

**10. Created the ECS Service**
Inside `portfolio-cluster`, created a service named `portfolio-service` using the `portfolio-task` definition with 1 desired task. Configured networking with the default VPC, public subnets, a new security group allowing inbound TCP on port 80 from anywhere, and auto-assign public IP turned on.

**11. Built the CodePipeline**
In AWS CodePipeline, created a pipeline named `portfolio-pipeline` with three stages: Source (GitHub via GitHub App, `main` branch), Build (`portfolio-build` CodeBuild project), and Deploy (Amazon ECS, `portfolio-cluster`, `portfolio-service`). The pipeline triggers automatically on every push to `main` via GitHub webhook.

**12. Tested end-to-end automation**
Uploaded the complete `assets/` folder to GitHub and watched the pipeline automatically trigger, build a new Docker image, push it to ECR, and deploy the updated container to ECS — with the fully styled website live within minutes.

---

## Troubleshooting & Lessons Learned

Real issues encountered and resolved during the project:

**Docker Hub rate limiting — `toomanyrequests` error**
The Dockerfile originally used `FROM nginx:alpine` which pulls from Docker Hub. AWS CodeBuild's shared IP addresses frequently hit Docker Hub's unauthenticated pull rate limit, causing the build to fail immediately. Fixed by changing to `FROM public.ecr.aws/nginx/nginx:alpine`, which pulls from AWS's public registry with no rate limits.

**Webhook creation failed in CodeBuild**
The GitHub connection ARN was broken, causing the webhook setup to fail during CodeBuild project creation. Fixed by unchecking the webhook option in CodeBuild — CodePipeline handles source triggering via its own GitHub App connection instead.

**ECS cluster creation failed — service-linked role error**
Creating the ECS cluster failed with "Unable to assume the service linked role". Fixed by opening AWS CloudShell and running: `aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com`

**CloudFormation stack conflict from failed cluster**
The failed cluster attempt left a broken CloudFormation stack with the same name. Fixed by navigating to AWS CloudFormation, deleting the failed stack, then recreating the cluster.

**Privileged mode required for Docker builds**
The build phase failed immediately because Docker-in-Docker requires elevated system permissions. Fixed by editing the CodeBuild project and ticking the **Privileged** checkbox under Additional Configuration in the Environment section.

**ECR access denied during `docker push`**
CodeBuild failed to push images with access denied. Fixed by attaching `AmazonEC2ContainerRegistryFullAccess` to the CodeBuild IAM role and adding a repository-level permissions policy on the ECR repository.

**"Retry" does not pick up source changes**
Clicking "Retry" on a failed Build stage reuses the previously downloaded source — new commits are ignored. The correct action is to click **"Release change"** from the pipeline view to force CodePipeline to fetch fresh source from GitHub.

---

## About the Author

**Rukayat Alarape**
Data Analyst | Cloud Engineer Learner

- GitHub: [@rukkylatunde2001](https://github.com/rukkylatunde2001)
- Email: rukkylatunde2001@gmail.com
