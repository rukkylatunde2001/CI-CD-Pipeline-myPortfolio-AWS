# CI/CD Pipeline for a Portfolio Website
## Using AWS CodePipeline, ECS, ECR & CodeBuild

---

## What This Project Is About

This project is about automating the process of deploying a website. Right now, if you make a change to your portfolio, you have to manually upload it somewhere for people to see it. This project eliminates that. Once it is set up, all you do is push your code to GitHub, and AWS takes care of everything else — packaging your site, storing it, and putting it live on the internet automatically.

That automation process is called a **CI/CD pipeline**. CI stands for Continuous Integration (automatically building and testing code) and CD stands for Continuous Deployment (automatically releasing it to users). This is a skill used by every professional software and cloud team in the world.

By the end of this project, your portfolio will be running inside a Docker container on AWS, and every future update you push to GitHub will be deployed automatically within minutes.

---

## What You Will Learn

- What Docker is and how to containerise a website
- What the key AWS services (ECS, ECR, CodeBuild, CodePipeline) do and why they exist
- How to set up a fully automated CI/CD pipeline from scratch
- How IAM permissions work and why they matter
- How to troubleshoot real AWS errors

---

## Understanding the Architecture Before You Start

Before touching any AWS console, you need to understand how all the pieces fit together. Here is a plain-English explanation of each service and the role it plays.

### GitHub
This is where your portfolio code lives. It is the starting point. When you push new code to GitHub, it signals AWS to start the pipeline. Nothing else happens manually — GitHub is the trigger.

### AWS CodePipeline
Think of CodePipeline as the manager of the whole process. It does not do the actual work itself — it coordinates everything. It watches GitHub, and the moment it sees a new commit on your main branch, it kicks off the pipeline and passes the job along to CodeBuild.

### AWS CodeBuild
This is the builder. CodeBuild receives your code, spins up a temporary environment (like a virtual computer), and follows the instructions in your `buildspec.yml` file step by step. Those instructions tell it to build a Docker image from your code and push it to ECR. Once CodeBuild is done, it shuts its environment down — you are not charged for idle time.

### Amazon ECR (Elastic Container Registry)
ECR is a private storage space for Docker images. Think of it like a private version of Docker Hub that lives inside your AWS account. Every time CodeBuild creates a new Docker image of your portfolio, it pushes it here. ECS then pulls the image from here when it is time to run it.

### Amazon ECS (Elastic Container Service) with Fargate
ECS is what actually runs your Docker container in the cloud. Fargate is the engine underneath ECS — it means AWS manages the servers for you. You do not provision, patch, or maintain any servers. You just tell ECS what to run (the container) and how much CPU and memory to give it, and Fargate handles the rest.

### IAM (Identity and Access Management)
IAM controls permissions. Every AWS service needs explicit permission before it can interact with another service. For example, CodeBuild needs permission to push images to ECR, and ECS needs permission to pull images from ECR. Without the correct IAM roles, everything will fail with "Access Denied" errors. IAM is not optional — it is fundamental to how AWS security works.

### The Full Picture

```
You push code to GitHub
         │
         ▼
AWS CodePipeline detects the change
         │
         ▼
AWS CodeBuild reads buildspec.yml and:
    1. Logs into ECR
    2. Builds a Docker image of your portfolio
    3. Pushes the image to ECR
    4. Creates a deployment file (imagedefinitions.json)
         │
         ▼
Amazon ECS (Fargate) reads the deployment file,
pulls the new image from ECR, and replaces
the running container with the updated version
         │
         ▼
Your portfolio is live with the latest changes ✅
```

---

## The Two New Files You Are Adding

You have three folders and one HTML file in your portfolio (`index.html`, `assets/`, `images/`). You are adding two new files to make this pipeline work.

### Dockerfile
A Dockerfile is a text file that contains instructions for building a Docker image. An image is a self-contained package that includes your code, a web server, and everything needed to run your site. When Docker reads this file, it follows the instructions one line at a time to create the image.

Your portfolio is plain HTML, CSS, and JavaScript — it does not need a complicated server. Nginx (pronounced "engine-x") is a lightweight, fast web server that is perfect for serving static files. The Dockerfile starts with Nginx, removes its default welcome page, copies all your portfolio files into it, and tells it to listen on port 80.

### buildspec.yml
A buildspec.yml file is the instruction manual for CodeBuild. YAML is a format for writing configuration — it uses indentation to show structure, and it is human-readable. This file has three sections called phases: pre_build (before the main work), build (the main work), and post_build (after the main work is done). Each phase contains a list of shell commands that run in order.

---

## Project Folder Structure

After you add the two new files, your portfolio folder will look like this:

```
rukayat-portfolio/
├── index.html
├── assets/
│   ├── css/
│   │   └── main.css
│   └── js/
│       ├── jquery.min.js
│       ├── jquery.scrollex.min.js
│       ├── jquery.scrolly.min.js
│       ├── browser.min.js
│       ├── breakpoints.min.js
│       ├── util.js
│       └── main.js
├── images/
│   ├── avatar.jpg
│   ├── banner.jpg
│   ├── FinanciaLmodel.png
│   ├── covid-19.jpg
│   ├── Financialanalysis.png
│   ├── Bankloan.png
│   ├── shark.jpg
│   ├── Hotel.jpg
│   └── churnrate.jpg
├── Dockerfile          ← NEW
└── buildspec.yml       ← NEW
```

---

## Prerequisites — What You Need Before Starting

Make sure you have all of these ready before you begin.

**1. An AWS Account**
Go to https://aws.amazon.com and create a free account if you do not have one. You will need a credit card, but this project costs approximately $1 or less.

**2. AWS CLI (Command Line Interface)**
The AWS CLI allows you to run AWS commands from your terminal. You need it to authenticate Docker with ECR in the early steps.

To install on Windows, download the installer from:
https://awscli.amazonaws.com/AWSCLIV2.msi

To install on Mac, run in your terminal:
```sh
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

After installation, verify it worked:
```sh
aws --version
```

Now configure it with your AWS credentials:
```sh
aws configure
```

It will prompt you for four things. Here is what each one means and where to find it:

- **AWS Access Key ID** and **AWS Secret Access Key** — these are like a username and password for programmatic AWS access. To create them: log into AWS Console → click your account name (top right) → Security credentials → Access keys → Create access key.
- **Default region name** — type `us-east-1`. This is the AWS data centre in North Virginia. All your resources will be created here.
- **Default output format** — type `json`.

**3. Docker Desktop**
Docker needs to be installed on your machine so you can build and test the container locally before deploying it.
Download from: https://www.docker.com/products/docker-desktop/

After installing, open Docker Desktop and make sure it is running (you will see a whale icon in your taskbar/menu bar).

**4. Git**
You likely already have this. Verify with:
```sh
git --version
```
If not, download from: https://git-scm.com/

**5. A GitHub Account**
Go to https://github.com and create an account if you do not have one.

---

## Step 1 — Add the Two New Files to Your Portfolio

### 1.1 — Add the Dockerfile

In the root of your portfolio folder (the same level as `index.html`), create a new file named exactly `Dockerfile` with no file extension.

Paste in the following content:

```dockerfile
FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

COPY . /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

Here is what each line does, explained in plain English:

**`FROM nginx:alpine`**
Every Dockerfile starts with FROM. This tells Docker which base image to start with — think of it like choosing a blank template. `nginx:alpine` means we want the official Nginx web server, built on Alpine Linux (a tiny, fast Linux distribution). This single line gives us a fully working web server to build on.

**`RUN rm -rf /usr/share/nginx/html/*`**
RUN executes a shell command inside the image. `/usr/share/nginx/html/` is the folder Nginx uses to serve files. By default it contains a generic "Welcome to Nginx" page. This line deletes everything in that folder so we can replace it with our portfolio files.

**`COPY . /usr/share/nginx/html`**
COPY takes files from your local machine and puts them into the image. The dot on the left means "copy everything in the current folder" — that is your `index.html`, your `assets/` folder, and your `images/` folder. The path on the right is the destination — the Nginx web root. After this line runs, Nginx will serve your portfolio instead of its default page.

**`EXPOSE 80`**
This is a declaration that tells Docker "this container will receive traffic on port 80." Port 80 is the standard port for HTTP traffic — when you visit a website without specifying a port number, your browser is using port 80 by default.

**`CMD ["nginx", "-g", "daemon off;"]`**
CMD defines what happens when the container starts. This starts Nginx. The `daemon off` part keeps Nginx running in the foreground — this is important because Docker watches the main process. If Nginx ran in the background (the default), Docker would think nothing is running and shut the container down immediately.

### 1.2 — Add the buildspec.yml

In the same root folder (same level as `Dockerfile` and `index.html`), create a new file named `buildspec.yml`.

Paste in the following content. Do not change anything yet — you will fill in your ECR URI in Step 2 once you have created the repository.

```yaml
version: 0.2

phases:

  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ECR_URI_HERE

  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t rukayat-portfolio .
      - echo Tagging the Docker image...
      - docker tag rukayat-portfolio:latest YOUR_ECR_URI_HERE:latest

  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image to ECR...
      - docker push YOUR_ECR_URI_HERE:latest
      - echo Creating imagedefinitions.json...
      - echo '[{"name":"portfolio-container","imageUri":"YOUR_ECR_URI_HERE:latest"}]' > imagedefinitions.json
      - echo Done!

artifacts:
  files:
    - imagedefinitions.json
```

Here is a detailed breakdown of what this file does:

**`version: 0.2`**
This tells CodeBuild which version of the buildspec format we are using. Version 0.2 is the current standard.

**`phases`**
The phases block contains three sections that run in sequence. If any command in any phase fails (returns a non-zero exit code), CodeBuild stops and marks the build as failed.

**`pre_build`**
This phase runs before the main build. The only command here logs Docker into ECR. The command uses a pipe (`|`) to pass the ECR login password directly into the `docker login` command without ever displaying it on screen. After this runs, Docker has permission to push images to your ECR repository. You must log in here every time because ECR tokens expire after 12 hours.

**`build`**
This is where the Docker image is created.

`docker build -t rukayat-portfolio .` — This command reads your Dockerfile and builds the image. The `-t` flag gives the image a local name (`rukayat-portfolio`). The dot at the end tells Docker to use the Dockerfile in the current directory.

`docker tag rukayat-portfolio:latest YOUR_ECR_URI_HERE:latest` — Docker images need to be tagged with the destination registry address before they can be pushed. This command creates a second name for the same image that includes your full ECR URI. The `:latest` tag means "this is the most recent version."

**`post_build`**
This runs after the build succeeds.

`docker push YOUR_ECR_URI_HERE:latest` — Uploads the image to your ECR repository. From this point on, ECS can pull it.

`echo '[{"name":"portfolio-container",...}]' > imagedefinitions.json` — Creates a small JSON file that ECS reads during deployment. It tells ECS: "update the container named `portfolio-container` with this new image." The container name here (`portfolio-container`) must exactly match the name you give the container in your ECS Task Definition in Step 3.

**`artifacts`**
This tells CodeBuild which files to pass on to the next stage of the pipeline. ECS needs the `imagedefinitions.json` file to know what to deploy, so we list it here.

### 1.3 — Test Docker Locally First

Before sending anything to AWS, test that Docker can build and serve your portfolio on your machine. This catches errors early, when they are fast and free to debug.

Open a terminal in your portfolio folder and run:

```sh
docker build -t rukayat-portfolio .
```

Docker will pull the Nginx image (this takes a minute the first time) and then copy your files in. When it finishes, you should see:
```
Successfully built <some-id>
Successfully tagged rukayat-portfolio:latest
```

Now run the container:

```sh
docker run -p 8080:80 rukayat-portfolio
```

Open your browser and go to `http://localhost:8080`. Your portfolio should appear exactly as it does locally. The `-p 8080:80` part maps port 8080 on your computer to port 80 inside the container — you are telling your machine to forward any traffic on port 8080 into the container.

Press `Ctrl+C` to stop the container when you are done.

### 1.4 — Push Your Code to GitHub

First, create a repository on GitHub:
1. Go to github.com and click the **+** button in the top right → **New repository**
2. Name it `rukayat-portfolio`
3. Choose Public or Private — either works for this project
4. Do NOT tick "Add a README file" — you already have one
5. Click **Create repository**

GitHub will show you setup instructions. Follow the commands below, which are tailored to your project:

```sh
cd path/to/your/portfolio/folder

git init

git add .

git commit -m "Initial commit: add portfolio with Dockerfile and buildspec.yml"

git branch -M main

git remote add origin https://github.com/rukkylatunde2001/rukayat-portfolio.git

git push -u origin main
```

Refresh your GitHub repository page — you should see all your files including `Dockerfile` and `buildspec.yml`.

---

## Step 2 — Create an ECR Repository

ECR (Elastic Container Registry) is where your Docker images will be stored. Every time the pipeline runs, CodeBuild will push a new image here, and ECS will pull from here to deploy.

### 2.1 — Create the Repository

1. Log into the AWS Console at https://console.aws.amazon.com
2. In the search bar at the top, type **ECR** and click **Elastic Container Registry**
3. Click **Create repository**
4. Configure it:
   - **Visibility settings:** Private. This means only your AWS account can access it.
   - **Repository name:** `rukayat-portfolio`
5. Leave all other settings as default and click **Create repository**

You will see your repository appear in the list.

### 2.2 — Copy Your Repository URI

Click on the repository name you just created. At the top of the page you will see the **URI**. It looks like this:

```
123456789012.dkr.ecr.us-east-1.amazonaws.com/rukayat-portfolio
```

Copy this URI and keep it somewhere handy — a sticky note, a text file, anywhere. You will use it in four places:
- In `buildspec.yml` (three times)
- In your ECS Task Definition (once)

### 2.3 — Update buildspec.yml with Your Real URI

Open `buildspec.yml` on your local machine. Replace every instance of `YOUR_ECR_URI_HERE` with your actual URI. There are four instances in the file. Save the file.

After editing, the pre_build command should look like this (using your actual numbers):
```
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com/rukayat-portfolio
```

Commit and push the updated file:

```sh
git add buildspec.yml
git commit -m "Add real ECR URI to buildspec.yml"
git push
```

### 2.4 — Push Your Initial Docker Image to ECR

Before the pipeline exists, ECS needs at least one image in ECR to run. You will push the first one manually from your local machine. After this, the pipeline will handle all future pushes automatically.

Run these commands one at a time. Replace the URI with yours:

```sh
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com/rukayat-portfolio
```

This authenticates Docker with your ECR registry. You will see `Login Succeeded`.

```sh
docker tag rukayat-portfolio:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/rukayat-portfolio:latest
```

This creates a second tag on your local image that includes the full ECR address, so Docker knows where to push it.

```sh
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/rukayat-portfolio:latest
```

This uploads your image to ECR. You will see progress bars as each layer uploads.

Go back to the AWS Console → ECR → your repository → click **Images**. You should see an image tagged `latest`. This confirms the push worked.

---

## Step 3 — Create an ECS Cluster, Task Definition, and Service

ECS is where your container will run. There are three things to create in ECS and they build on each other:

- The **Cluster** is the environment — it is where your containers live.
- The **Task Definition** is the blueprint — it describes what container to run and with what settings.
- The **Service** is what keeps your container alive — it makes sure the desired number of containers are always running.

### 3.1 — Create the Cluster

1. In the AWS Console, search for **ECS** → click **Elastic Container Service**
2. In the left sidebar, click **Clusters** → **Create cluster**
3. Configure:
   - **Cluster name:** `portfolio-cluster`
   - **Infrastructure:** tick **AWS Fargate (serverless)**

   Fargate means you do not manage any servers. You do not choose an instance type, you do not patch an operating system, you do not worry about capacity. You just define what to run, and AWS handles everything underneath.

4. Click **Create** and wait about 30 seconds for the cluster to be ready.

### 3.2 — Create a Task Definition

A Task Definition is like a job description for your container. It answers: what image should I run? How much CPU and memory should I give it? What port does it use?

1. In ECS → **Task Definitions** (left sidebar) → **Create new task definition**
2. Fill in the configuration:

   **Task definition family:** `portfolio-task`
   This is just a name — ECS tracks revisions of your task definition automatically.

   **Launch type:** AWS Fargate

   **Operating system/Architecture:** Linux/X86_64

   **CPU:** `.25 vCPU`
   This is the smallest option. A static portfolio site needs almost no CPU.

   **Memory:** `0.5 GB`
   Again, the minimum. Your site is lightweight.

3. Scroll down to the **Container details** section:

   **Name:** `portfolio-container`
   This name is critical. It must exactly match the name in the `imagedefinitions.json` file that CodeBuild creates. If they do not match, the deploy stage will fail with a confusing error.

   **Image URI:** paste your full ECR URI with `:latest` on the end:
   ```
   123456789012.dkr.ecr.us-east-1.amazonaws.com/rukayat-portfolio:latest
   ```

   **Port mappings:** click **Add port mapping**
   - Container port: `80`
   - Protocol: `TCP`

   Port 80 is where Nginx inside the container is listening. You are telling ECS to accept traffic on that port and forward it to the container.

4. Click **Create**

### 3.3 — Create a Service

The Service ensures your container keeps running. If the container crashes, the Service restarts it automatically. It is also what the pipeline updates when you deploy — it tells the running container to be replaced with the new image.

1. In ECS → **Clusters** → click `portfolio-cluster` → click the **Services** tab → **Create**
2. Configure:

   **Launch type:** FARGATE

   **Task definition:** select `portfolio-task` — then select the latest revision number from the dropdown.

   **Service name:** `portfolio-service`

   **Desired tasks:** `1`
   This means keep one container running at all times.

3. Scroll to the **Networking** section. This is important:

   **VPC:** select your default VPC. Every AWS account comes with a default VPC (Virtual Private Cloud) — it is the network your resources live in. You do not need to create a new one.

   **Subnets:** select at least two subnets from the list. Subnets are subdivisions of the VPC. Select any that appear.

   **Security group:** click **Create a new security group**
   - Security group name: `portfolio-sg`
   - Description: `Allow HTTP traffic for portfolio`
   - Add an inbound rule:
     - Type: Custom TCP
     - Port range: `80`
     - Source: Anywhere-IPv4 (`0.0.0.0/0`)

   A security group is a virtual firewall. This rule means: allow anyone on the internet to send traffic to port 80 on this container. Without this rule, your portfolio would be running but completely unreachable.

   **Auto-assign public IP:** make sure this is **ENABLED** (turned on). This is how your container gets a public IP address that people can visit in a browser. If this is off, your portfolio will run but will have no public URL.

4. Click **Create**

The service will start and attempt to launch your container. It may take 1–2 minutes to show a **RUNNING** status. You can click the **Tasks** tab to watch it start.

---

## Step 4 — Create IAM Roles

IAM roles are how you grant AWS services permission to talk to each other. Think of it like access badges — CodeBuild needs a badge that says it is allowed into ECR. Without the right badge, the door stays locked.

You need to create one role for CodeBuild. This role will be attached to CodeBuild in Step 5.

### 4.1 — Create the CodeBuild IAM Role

1. In the AWS Console, search for **IAM** → click **Roles** in the left sidebar → **Create role**

2. **Trusted entity type:** AWS service
   This means you are creating a role that an AWS service (CodeBuild) will use.

3. **Use case:** In the search box, type `CodeBuild` → select **CodeBuild** → click **Next**

4. You are now on the permissions page. Search for and tick each of these three policies:

   **`AmazonEC2ContainerRegistryFullAccess`**
   This gives CodeBuild full access to ECR — it can read images, push images, and create repositories. Without this, the `docker push` command in buildspec.yml will fail.

   **`AWSCodeBuildDeveloperAccess`**
   Allows CodeBuild to perform builds and access build-related resources.

   **`AmazonS3FullAccess`**
   CodePipeline uses an S3 bucket to pass files between stages (for example, passing `imagedefinitions.json` from the Build stage to the Deploy stage). CodeBuild needs S3 access for this handoff to work.

5. Click **Next** → give the role a name: `CodeBuildPortfolioRole` → click **Create role**

### 4.2 — Add an Inline Policy for ECS

The three managed policies above cover most of what CodeBuild needs. But to allow CodeBuild to update the ECS service (which it needs to do during deployment), you need one more permission added as an inline policy.

An inline policy is a custom permission attached directly to a specific role, rather than a pre-made policy you choose from a list. It gives you precise control over what is allowed.

1. In IAM → **Roles** → click on `CodeBuildPortfolioRole`
2. Click **Add permissions** → **Create inline policy**
3. Click the **JSON** tab and replace the content with this:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:UpdateService",
                "ecs:DescribeServices"
            ],
            "Resource": "arn:aws:ecs:us-east-1:YOUR_ACCOUNT_ID:service/portfolio-cluster/portfolio-service"
        }
    ]
}
```

Replace `YOUR_ACCOUNT_ID` with your 12-digit AWS account ID. To find it: click your account name in the top-right corner of the AWS Console — your account ID appears there.

This policy grants CodeBuild permission to update and describe exactly one ECS service — your `portfolio-service`. Locking it down to one specific resource is a security best practice: you are granting the minimum permission needed, nothing more.

4. Click **Next** → name the policy `ECSUpdatePolicy` → **Create policy**

---

## Step 5 — Set Up CodeBuild

Now you create the CodeBuild project that reads your `buildspec.yml` and builds the Docker image.

1. In the AWS Console, search for **CodeBuild** → **Build projects** → **Create build project**

2. **Project name:** `portfolio-build`

3. **Source** — where CodeBuild will get your code:
   - Source provider: **GitHub**
   - Click **Connect to GitHub** — a new tab opens asking you to authorise AWS to access your GitHub account. Approve it.
   - Select **Repository in my GitHub account**
   - Repository: select `rukayat-portfolio`
   - Branch: `main`

4. **Environment** — this is the virtual machine CodeBuild will use to run your build:

   - Environment image: **Managed image** (AWS provides and maintains the machine)
   - Compute: **EC2**
   - Operating system: **Ubuntu**
   - Runtime: **Standard**
   - Image: `aws/codebuild/standard:7.0`
   - Image version: Always use the latest image for this runtime version

   - **Privileged mode:** ✅ Enable this
   This setting is critical and easy to miss. Docker builds require elevated system permissions — they need access to the Docker daemon running on the host. Without Privileged mode enabled, the `docker build` command inside CodeBuild will fail with a "Cannot connect to Docker daemon" error. Always enable this whenever CodeBuild needs to run Docker commands.

   - Service role: **Existing service role** → select `CodeBuildPortfolioRole`

5. **Buildspec:**
   - Select **Use a buildspec file**
   - Leave the filename field blank. CodeBuild will automatically look for a file named `buildspec.yml` in the root of your repository. Since that is exactly where you placed it, nothing else is needed.

6. Leave all other settings as default and click **Create build project**

### Test CodeBuild on Its Own

Before connecting everything through the pipeline, test the build project directly. This is a good habit — it isolates the build process so you can debug it independently.

1. In your CodeBuild project → click **Start build**
2. Click on the running build → scroll to the **Build logs** section
3. Watch the logs in real time. You will see each phase execute and each command produce output. This is exactly what will happen every time the pipeline runs.

If the build succeeds, all three phases will show green checkmarks. Go to ECR in the AWS Console, open your repository, and click the **Images** tab — you should see a new image tagged `latest` with a recent push date.

If the build fails, read the logs carefully. The error message will point to the exact command that failed. Common causes are covered in the Troubleshooting section at the end of this guide.

---

## Step 6 — Set Up CodePipeline

This is the final piece. CodePipeline ties everything together and makes the process automatic.

1. In the AWS Console, search for **CodePipeline** → **Create pipeline**

2. **Pipeline settings:**
   - Pipeline name: `portfolio-pipeline`
   - Execution mode: **Superseded** (if a new run starts before the previous one finishes, the old one is cancelled — this is the sensible default)
   - Service role: **New service role** — let AWS create this automatically. AWS knows what permissions CodePipeline needs to orchestrate the other services, so it will create the appropriate role for you.
   - Artifact store: **Default location** — AWS will create an S3 bucket to temporarily store files passed between pipeline stages.
   - Click **Next**

3. **Source stage** — this is where the pipeline gets your code and listens for changes:
   - Source provider: **GitHub (Version 2)**
   - Click **Connect to GitHub** and follow the authorisation flow
   - Repository name: select `rukayat-portfolio`
   - Branch name: `main`
   - Trigger: **Push events on branch main**

   This means the pipeline will trigger automatically every time you push a commit to the main branch. You do not need to run it manually — GitHub sends a webhook notification to CodePipeline the moment you push.

   - Click **Next**

4. **Build stage** — this is where CodeBuild runs:
   - Build provider: **AWS CodeBuild**
   - Region: select your region (e.g., US East (N. Virginia))
   - Project name: select `portfolio-build`
   - Click **Next**

5. **Deploy stage** — this is where ECS gets updated:
   - Deploy provider: **Amazon ECS**
   - Region: select your region
   - Cluster name: `portfolio-cluster`
   - Service name: `portfolio-service`
   - Image definitions file: `imagedefinitions.json`

   This last field is important. CodeBuild produces the `imagedefinitions.json` file during the build, and CodePipeline passes it to the Deploy stage as an artifact. ECS reads this file to know which container to update and which image to use. If you mistype the filename here, the deploy stage will fail.

   - Click **Next**

6. Review everything on the summary page and click **Create pipeline**

The pipeline will start running immediately after creation. Watch the three stage tiles on the screen:

- **Source** — turns orange (running), then green (complete)
- **Build** — turns orange, then green. Click **Details** to watch the build logs live.
- **Deploy** — turns orange, then green. This means ECS has pulled the new image and restarted the container.

If any stage turns red, click the **Details** link in that stage tile to read the error message.

---

## Step 7 — See Your Portfolio Live

Once all three stages in CodePipeline are green:

1. Go to **ECS** in the AWS Console → **Clusters** → `portfolio-cluster`
2. Click the **Tasks** tab
3. Click on the running task (it will have a status of RUNNING)
4. In the task detail page, find the **Network** section
5. Copy the **Public IP** address

Open a new browser tab and go to:
```
http://YOUR_PUBLIC_IP
```

Your portfolio is live on the internet.

### Confirm the Automation Works

Make a visible change to your `index.html` — for example, update a word in your About section. Save it, then push to GitHub:

```sh
git add index.html
git commit -m "Test automated deployment"
git push
```

Open CodePipeline in the AWS Console. Within seconds, you will see the pipeline trigger automatically. Wait 3–5 minutes, refresh your portfolio URL, and you will see your change is live — without any manual steps.

This is the power of a CI/CD pipeline.

---

## Troubleshooting

**CodeBuild fails: "Cannot connect to Docker daemon"**
Privileged mode is not enabled on the CodeBuild environment. Go to CodeBuild → Build projects → `portfolio-build` → Edit → Environment → tick the Privileged checkbox → Update environment.

**CodeBuild fails: "Access Denied" or "not authorized to perform: ecr:InitiateLayerUpload"**
The CodeBuild IAM role is missing the ECR permission. Go to IAM → Roles → `CodeBuildPortfolioRole` → confirm `AmazonEC2ContainerRegistryFullAccess` is listed under Permissions. If it is missing, add it.

**CodeBuild fails: "repository does not exist"**
The ECR URI in your `buildspec.yml` is wrong. Go to ECR, copy the exact URI, and update your `buildspec.yml` — make sure there are no extra spaces or characters.

**Deploy stage fails: "The image definition file imagedefinitions.json does not exist"**
The `post_build` phase in `buildspec.yml` failed before creating the file. Check the CodeBuild logs for the step that failed.

**Deploy stage fails: "The container name in imagedefinitions.json does not match any container"**
The name `portfolio-container` in `buildspec.yml` does not exactly match the container name in your ECS Task Definition. Go to ECS → Task Definitions → `portfolio-task` → check the container name. It must be exactly `portfolio-container` with no typos.

**Pipeline stuck at Source stage**
Your GitHub connection has expired or been revoked. Go to CodePipeline → Settings → Connections → reconnect your GitHub account.

**Portfolio loads but shows no images**
Your `images/` folder was not committed to GitHub. Run `git status` to check if the folder is tracked. If it shows as untracked, run `git add images/` then commit and push again.

**ECS task is not showing a Public IP**
The service was created with Auto-assign public IP turned off. You need to delete the service and recreate it with that setting enabled.

---

## Clean Up — Avoid Ongoing Charges

When you are finished with the project, delete these resources to stop being charged:

**1. ECS Service**
Go to ECS → Clusters → `portfolio-cluster` → Services → tick `portfolio-service` → Delete. Before it lets you delete, it will ask you to set the desired task count to 0.

**2. ECS Cluster**
After the service is deleted → select `portfolio-cluster` → Delete cluster.

**3. ECR Repository**
Go to ECR → Repositories → tick `rukayat-portfolio` → Delete.

**4. CodePipeline**
Go to CodePipeline → Pipelines → tick `portfolio-pipeline` → Delete.

**5. CodeBuild Project**
Go to CodeBuild → Build projects → tick `portfolio-build` → Delete.

**6. IAM Role**
Go to IAM → Roles → search for `CodeBuildPortfolioRole` → Delete.

**7. S3 Bucket**
CodePipeline created an S3 bucket automatically. Go to S3, find the bucket named something like `codepipeline-us-east-1-xxxxxxxxxx`, empty it, and then delete it.

---

## Summary

You have built a production-grade CI/CD pipeline that:
- Watches your GitHub repository for changes
- Automatically builds a Docker image of your portfolio
- Stores every image version in a private ECR registry
- Deploys the updated container to ECS Fargate
- Makes your portfolio live on the internet with a public IP

Every future update to your portfolio is now a three-step process: make your change, commit it, and push to GitHub. AWS handles everything else automatically.

---

*Project by Rukayat Alarape | AWS CodePipeline · ECS Fargate · ECR · CodeBuild · Docker · GitHub*
