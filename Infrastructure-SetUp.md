# FINAL PROJECT DOCUMENTATION - Engr Smart

## 1. Project overview

This project is a cloud-native application infrastructure built on AWS with a 2-tier architecture and high availability.

### Core architecture

- VPC
- 2 Availability Zones (AZs)
- 2 public subnets
- 2 private subnets
- EKS cluster placed in the public subnets
- Worker nodes placed in the private subnets
- NAT gateway used so private resources can access the internet while staying private

### Why this design

- Public subnets host internet-facing services and Kubernetes control plane access patterns
- Private subnets host the worker nodes and workloads, reducing direct exposure to the internet
- NAT allows outbound internet access for private workloads without exposing them directly
- High availability is achieved by spreading resources across two AZs

---

## 2. Infrastructure design and components

### Networking

- Main route table is attached to the public subnets
- Internet Gateway connects the public subnets to the internet
- Private route table routes traffic through the NAT Gateway
- Security groups allow inbound traffic on ports 22, 80, 443, and 3000
- Outbound traffic is allowed for all ports

### Kubernetes cluster

- Amazon EKS is used for container orchestration
- The Kubernetes worker nodes sit in private subnets
- The cluster is fronted by a load balancer and ingress controller

### Node groups

The worker nodes are configured with autoscaling.

Node group sizing options used in the project:

- Option A: t2.medium
  - Min: 2
  - Desired: 4
  - Max: 8

- Option B: t2.small
  - Min: 2
  - Desired: 6
  - Max: 12

These values help balance cost with workload demand and scalability.

### EFS (Elastic File System)

- EFS is attached to the Kubernetes cluster
- It provides shared persistent storage for workloads
- The EFS mount target is connected to the worker nodes or cluster networking layer
- This allows containers to mount volumes and share data reliably

### IAM roles

The project uses IAM roles for:

- Elastic service access
- EKS node group permissions
- GitHub Actions deployment access

This is important because AWS resources should not be managed with long-lived root credentials or personal access keys where possible.

### EC2 key pair

- An EC2 key pair is associated with the private subnet resources
- This is used mainly for secure access when needed

### Certificate management

- Let’s Encrypt is connected to cert-manager
- This is used to issue and manage TLS certificates
- HTTPS is served on port 443

---

## 3. AWS infrastructure and DevOps flow

### Terraform + GitHub Actions deployment pipeline

The project uses Terraform to provision AWS infrastructure and GitHub Actions to automate deployment.

### Short-lived credentials for GitHub Actions

A DevOps engineer needs an IAM token that is short-lived for GitHub Actions use.

Instead of storing long-term AWS credentials in GitHub, the project uses OIDC (OpenID Connect) to allow GitHub to securely request temporary AWS credentials.

This is much safer because:

- the identity is temporary
- it expires automatically after a short time
- it reduces the risk of stolen long-term secrets

---

## 4. OIDC setup for GitHub Actions

### Why OIDC is used

OIDC allows AWS to trust GitHub as an identity provider.

The process works like this:

1. AWS is told once to trust GitHub’s OIDC identity.
2. When a GitHub Actions workflow runs, GitHub issues a temporary ID token.
3. AWS validates that token.
4. AWS gives the workflow a short-lived role session.
5. After a few hours, the session expires automatically.

This avoids storing permanent AWS credentials in GitHub secrets.

### Step 1: Create the identity provider

In AWS IAM:

- Go to IAM
- Select Add provider
- Provider type: OpenID Connect
- Provider URL: https://token.actions.githubusercontent.com
- Audience: sts.amazonaws.com

Click Add provider.

The provider ARN is:

`arn:aws:iam::191611156690:oidc-provider/token.actions.githubusercontent.com`

### Step 2: Create the IAM role for GitHub Actions

In AWS IAM:

- Go to Roles
- Click Create role
- Trusted entity type: Web identity
- Choose the GitHub OIDC provider
- Audience: sts.amazonaws.com
- Set GitHub organization, you casn use your own username as the organisation name and IaC repository to the project repo
- For now, leave the branch unrestricted or allow all branches

Then attach a broad permission set such as AdministratorAccess for the learning stage.

Role name used in the project:

`github-actions-terraform`

### Trust policy example

Go to = <https://github.com/POD5-DevOps-Team-DGWIT/Ecommerce-Project-IaC-DGWI/settings/actions/oidc-configuration

Copy this <repo:Org_Name@Token/Repo_Name@Token

Go to your AWS IAM role you created and paste the repo line to edit the `Role  Trust policy:` which tells AWS which repo is to be trusted.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::191611156690:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ORG-NAME/REPO_NAME:*" 
        }
      }
    }
  ]
}
```

change the `StringLike` Block to this
>"token.actions.githubusercontent.com:sub": "repo:POD5-DevOps-Team-DGWIT@340990885/Ecommerce-Project-IaC-DGWI@1454500340:*"

### What this policy does

- `Principal`: only the GitHub OIDC provider is trusted
- `Action`: allows AWS role assumption using web identity
- `aud`: ensures the token is meant for AWS
- `sub`: ensures the token comes from the correct GitHub repo

This is crucial. Without the repo restriction, any GitHub repo could potentially assume the role.

### Role ARN

After creation, save the role ARN and add it to GitHub repository secrets or variables as:

- Name: `AWS_OIDC_ARN`
- Value: `arn:aws:iam::916657620282:role/iam_name_used`

---

## 5. Local setup and required tools

To work from a local machine, the following tools are needed:

### List Of Install i did on the infrastucture 

<winget install -e --id Git.Git	
git --version                       #Saves your project history and talks to GitHub

<winget install Amazon.AWSCLI
aws --version                       #Lets your terminal talk to your AWS account

<winget install -e --id Hashicorp.Terraform	
terraform -v                        #Builds the AWS setup from your code files

<winget install -e --id Kubernetes.kubectl	
kubectl version --client            #The remote control for your Kubernetes cluster

<winget install -e --id Helm.Helm   #Only to inspect or debug the installs inside the cluster, since Terraform already drives it

<winget install -e --id Docker.DockerDesktop  #To build and test images on your laptop. The pipeline builds the real ones.

```bash
aws --version
aws configure

# enter your IAM user's key, your region, output json i created another IAM role and create an access key
```

Example configuration used:

- AWS Access Key ID: provided IAM user key
- AWS Secret Access Key: provided secret
- Default region: `eu-west-2`
- Output format: `json`

Verify identity:

```bash
aws sts get-caller-identity
    {                                                             
        "UserId": "xxxxxxxxxxxxxxxx",
        "Account": "191611156690",
        "Arn": "arn:aws:iam::916657620282:role/role/iam_name_used"
    }
```

This should show your IAM user and account, not the root user.

### Terraform

```bash
terraform -v
```

Terraform version should be 1.10 or newer.

### kubectl

```bash
winget install -e --id Kubernetes.kubectl
kubectl version --client
```

### Helm

```bash
winget install -e --id Helm.Helm
helm version
```

### Git

```bash
git --version
```

### Docker

```bash
winget install -e --id Docker.DockerDesktop
```

Docker is useful for local image builds and debugging, while the CI/CD pipeline handles production builds.

---

## 6. EKS cluster access and verification

### Configure kubectl to reach the cluster

```bash
aws eks update-kubeconfig --region eu-west-2 --name Internship-Project-EKS
```

This configures your local machine to talk to the EKS cluster.

### Check cluster nodes

```bash
kubectl get nodes
```

You should see the worker nodes in Ready state.

### Check running workloads

```bash
kubectl get pods -A
```

Look for pods in:

- Running
- Completed

Short periods of Pending or ContainerCreating are normal while the cluster is still starting up.

---

## 7. DNS and Route 53 setup

The project uses a custom domain, and the DNS records are created in Route 53.

### Objective

Right now, the domain `argocd.cloudbinocular.online` needs to point to the Kubernetes load balancer front door.

The general flow is:

1. Terraform deploys NGINX ingress inside the cluster
2. AWS creates a Network Load Balancer (NLB)
3. Terraform outputs the load balancer hostname
4. Route 53 is configured to point the subdomain to that load balancer

### Why a CNAME is used

A CNAME record says:

> “This name is another name for another hostname.”

This is useful because the load balancer hostname is not a fixed IP address. AWS may change the underlying IPs over time.

If we created an A record with one IP, the website could break when AWS changes that IP.

A CNAME is simpler and works well for subdomains like:

- `argocd.cloudbinocular.online`

### Why an Alias record is better in Route 53

AWS Route 53 supports an Alias record that behaves similarly to a CNAME but is designed for AWS resources.

Advantages of Alias over CNAME:

- works for the root domain and subdomains
- integrates directly with AWS services
- recommended for load balancers
- avoids many DNS limitations

### Route 53 record creation example

In Route 53, open the hosted zone for `cloudbinocular.online` and create a record.

Example values:

- Record name: `argocd`
- Record type: `A` (or Alias depending on the setup)
- Alias: enabled
- Route traffic to: Alias to Network Load Balancer
- Region: `eu-west-2`
- Choose the NLB from the dropdown
- Evaluate target health: `No`
- Routing policy: `Simple routing`

The value used for the target is the load balancer hostname, for example:

```text
a0db7659bd17d4b26a30fc68cf80c440-bde6e852c6bf4758.elb.eu-west-2.amazonaws.com
```

### Check that DNS works

```bash
nslookup argocd.cloudbinocular.online 8.8.8.8
```

This should resolve to the AWS load balancer endpoint when the DNS propagation is complete.

---

## 8. Argo CD and certificate validation

After the cluster is set up and DNS is configured, Argo CD is installed and exposed through the ingress.

### Check certificates

```bash
kubectl get certificate -A
```

You want to confirm that the certificate issued by Let’s Encrypt is ready and valid.

The target state is:

- `READY = True`

### Get the initial Argo CD admin password

```bash
terraform output -raw argocd_initial_admin_password
```

This value is sensitive. It should be kept private.

The default admin username is:

- `admin`

---

## 9. Terraform workflow

The project uses a standard Terraform lifecycle.

### Initialize Terraform

```bash
terraform init
```

This connects Terraform to the remote S3 state bucket.

### Format files

```bash
terraform fmt -recursive
```

This cleans up formatting automatically.

### Validate configuration

```bash
terraform validate
```

This catches typos before anything is built, validate checks your syntax and references without touching AWS, so it catches typos for free.

### Create an execution plan

```bash
terraform plan -out=tfplan
```

This compares the current state with the desired state and prepares a plan. It reads every "will be created" line plan asks AWS what exists now, compares it with your code, and writes the list of changes to tfplan. It builds nothing and costs nothing.

To review only the created resources:

```bash
terraform show -no-color tfplan | grep "will be created"
```

### Apply the plan

```bash
terraform apply tfplan
```

### Example success output:

```text
Apply complete! Resources:  56 added, 0 changed, 0 destroyed.
```
On successful deployment, Terraform output includes values such as:

```text
argocd_admin_username = "admin"
argocd_initial_admin_password = <sensitive>
argocd_url = "https://argocd.cloudbinocular.online"
efs_file_system_id = "fs-02f3327c26476ee52"
efs_storage_class = "efs-sc"
eks_cluster_endpoint = "https://99A3EC8767A15968A907243DA4118B8B.gr7.eu-west-2.eks.amazonaws.com"
eks_cluster_name = "Internship-Project-EKS"
eks_cluster_version = "1.37"
eks_node_group_name = "Internship-Project-EKS-nodes"
kubeconfig_command = "aws eks update-kubeconfig --region eu-west-2 --name Internship-Project-EKS"
kubeconfig_download_command = "aws s3 cp s3://my-private-kubeconfig-191611156690/eks/kubeconfig ~/.kube/config"
kubeconfig_s3_uri = "s3://my-private-kubeconfig-191611156690/eks/kubeconfig"
load_balancer_hostname = "a0db7659bd17d4b26a30fc68cf80c440-bde6e852c6bf4758.elb.eu-west-2.amazonaws.com"
```

These values are critical for:

- cluster access
- app access
- storage identification
- Argo CD login

---

## Destroy infrastructure

```bash
terraform destroy -auto-approve
```
This removes all resources created by Terraform.

---

## 11. Important cloud resources created outside Terraform

These are resources created manually in AWS and not removed by a local destroy command:

- S3 state bucket
- S3 kubeconfig bucket
- IAM OIDC provider
- GitHub Actions IAM role
- Route 53 hosted zone for the domain
- Argo CD Alias/DNS record
- IAM user and access key used for setup

### State bucket

This stores Terraform’s state file and holds the “memory” of the infrastructure.

Why it matters:

- Terraform uses the state file to know what it already created
- If the state file is lost, Terraform may recreate or mismanage infrastructure
- It may also contain sensitive values and resource IDs

### Kubeconfig bucket

This stores the kubeconfig file used by developers and automation to access the cluster.

This data is useful but does not contain the same level of risk as the Terraform state file.

---

### Bucket 1: Terraform state bucket

Purpose:

- stores Terraform state
- tracks all built resources
- includes critical metadata and values

Access restrictions:

- only you and the CI/CD pipeline should be able to read it

Why separate:

- this bucket is sensitive
- state files may include secrets
- it should not be mixed with developer access or general config files

### Bucket 2: Kubeconfig bucket

Purpose:

- stores the kubeconfig used to access the cluster
- used by developers who need kubectl access

Why separate:

- easier to control access
- limited blast radius if something is accidentally deleted or misconfigured
- avoids mixing cluster access data with Terraform state

### Two buckets are safer

The documentation highlights several reasons:

- separate permissions are easier to manage
- a mistake in the kubeconfig bucket does not affect the state bucket
- versioning makes recovery simpler
- state files are more sensitive than kubeconfig data

---

## 13. The Terraform state file: why it is critical

Think of Terraform state as the project’s ledger.

Your code defines what should exist. The state file records what actually exists in AWS.

Terraform compares the two every time you run a plan.

### What is stored in the state file

- VPCs, subnets, NAT gateways, clusters, nodes, ALBs/NLBs, IAM objects
- resource IDs and settings
- account IDs and role ARNs
- secrets such as generated private keys and Argo CD admin password

Important:

- marking an output as sensitive hides it on screen
- it does not remove the value from the state file itself

### Why it is high-value data

If the state file is lost:

- Terraform no longer knows what exists
- infrastructure may be recreated incorrectly or drift
- old AWS resources may keep running and cost money

If the state file is leaked:

- private keys and cluster information can be exposed
- attackers may learn the structure of the environment and its credentials

This is why the state bucket must be tightly secured.

---

## 14. Useful Terraform commands

Some useful commands from the project are:

```bash
terraform state list
```

This lists the resources Terraform is tracking.

Important warning:

- do not paste `terraform show` or `terraform state pull` output into shared places
- those outputs can include secrets

---

## 15. Security lessons from the project

This project demonstrates a few important cloud security principles:

- Use OIDC instead of static AWS credentials for GitHub Actions
- Keep Terraform state in a protected bucket
- Minimize permissions using least privilege later
- Use private subnets for worker nodes where practical
- Use NAT instead of exposing private workloads directly
- Use TLS certificates and HTTPS for external services
- Keep secrets out of source control

---

## 16. Summary

This project combines:

- AWS VPC and networking design
- EKS for container orchestration
- EFS for persistent storage
- Terraform for infrastructure as code
- GitHub Actions with OIDC for secure deployment
- Route 53 for custom DNS
- Let’s Encrypt cert-manager for HTTPS certificates
- Argo CD for GitOps deployment

The core idea is simple:

- deploy the infrastructure with Terraform
- secure access with IAM and OIDC
- connect a custom domain to the cluster through Route 53
- expose apps through ingress and SSL certificates
- manage workloads with Kubernetes and Argo CD


## TO RUN TERRAFORM AGAIN DO THE FOLLOWING

<aws sts get-caller-identity>               #Check you’re still signed in.

<aws s3 ls | grep -E "internshipstate|kubeconfig"> #Check if your S3 buckets still exist. The one you created and the one you dont't have to create

<terraform init>                            #Connect to the state box

<aws eks update-kubeconfig --region eu-west-2 --name Internship-Project-EKS>                                        #Connect to the new cluster.

<kubectl get nodes 

<terraform plan -out=tfplan>                #Make a new plan. Never reuse the old tfplan file

<terraform apply "tfplan">                  #Build into your S3 bucket

<terraform output load_balancer_hostname>   #Get the new front door address. Remember you have to use the aws name to update the DNS record.

Steps: In Route 53 → Hosted zones → cloudbinocular.online, edit the argocd Alias record and pick the new load balancer in the dropdown. Why: it still points at the deleted one, so the site won’t open until you change it.

<kubectl apply -f manifests/argocd-ingress.yaml>   #Add the ingress again.I added this with kubectl, not with Terraform, so Terraform doesn’t remember it and the destroy removed it. I have to add it again every time you rebuild.

<nslookup argocd.cloudbinocular.online 8.8.8.8

<kubectl get certificate -A>                    #Wait for READY True, then open https://argocd.cloudbinocular.online. The password is new each time.

<terraform output -raw argocd_initial_admin_password>      #

<terraform apply tfplan

<terraform destroy -auto-approve

<terraform force-unlock e9e20f0e-34b2-66af-9de5-d975cecf31ba> #incase it doesn't destroy and the S3 lock the file, (The scary “412 PreconditionFailed” is just how S3 says “that lock file already exists.”

<terraform state list>      #If the list is long, an earlier apply got partway through, so some resources may be running and costing money right now. If it’s empty or just a few lines, little was built.

<terraform destroy>         #Run this finally

## ADD VPC FLOW LOG TO MY INFRASTRUCTURE

<What a VPC flow log is, in plain words

Your VPC is the private network that holds your cluster. A flow log is a record of every connection going in, out and around that network. Each line says who talked to whom, on which port, how much data was sent, and whether the connection was allowed or blocked. It records the envelope, not the letter: you see who sent something and where, but never the contents.

<Why it matters, especially for a DevSecOps role:

Security: you can spot strangers probing your servers, or a server suddenly sending data to an address it never used before. That is often the first sign of a break-in.
Troubleshooting: when one app can’t reach another, a REJECT line shows that a firewall rule blocked it, and it tells you which one.
Proof for audits: many security standards require network logging, and an interviewer will like to see it.
Cost: it shows what is using the NAT gateway, which is one of your more expensive items.
How to add it

<You add four new pieces in a new file. You don’t need to change any existing file.

A log group named Internship_flow_log: the folder in CloudWatch where the records go.
A role: permission that lets the flow log service write into that folder.
A policy on the role: the exact things it may do.
The flow log itself: the switch that attaches all of this to your VPC.

From the terraform documentation registry \

<https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log.html

    <!-- resource "aws_flow_log" "example" {
  iam_role_arn    = aws_iam_role.example.arn
  log_destination = aws_cloudwatch_log_group.example.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.example.id
}

resource "aws_cloudwatch_log_group" "example" {
  name = "example"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example" {
  name               = "example"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "example" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "example" {
  name   = "example"
  role   = aws_iam_role.example.id
  policy = data.aws_iam_policy_document.example.json
} -->

<grep -rn "flow_log" *.tf

<terraform fmt

<terraform validate>

<terraform plan -out=tfplan

<terraform apply tfplan

Go to cloudwatch console on your AWS -> Log Management


Here is the full sequence, in order. It starts with a safety check, because of the stuck lock from your last message. Run one command at a time, and read the result before moving on.

Part A: Make sure you’re starting clean

1. Confirm who you are.

bash
<aws sts get-caller-identity

It should show account 191611156690 and Intershipstateadmin.


2. See what Terraform thinks exists.

bash
<terraform state list

Empty: you’re starting fresh, so go to Part B.

if not empty run this:
bash
<terraform force-unlock e9e20f0e-34b2-66af-9de5-d975cecf31ba

Has lines: an earlier build got part of the way. You can simply continue, because the plan in Step 7 will show only what’s left. But also check the AWS console (EKS, EC2, VPC) for anything running, since you’re paying for it.
Part B: Build

4. Check your two storage boxes exist.

bash
<aws s3 ls | grep -E "internshipstate|kubeconfig"

You should see both. If the kubeconfig one is missing, create it first as we did before, or the build fails at the end.

5. Connect to the state box.

bash
<terraform init

6. Tidy and check your files, including the new flow log file.

bash
<terraform fmt -recursive

<terraform validate

You want Success! The configuration is valid.

7. Make a new plan.

bash
<terraform plan -out=tfplan

From empty, it should say Plan: 56 to add, 0 to change, 0 to destroy. That’s the 52 from before plus 4 for the flow log. If the number is different, or you see any “to destroy”, stop and send me the plan.

A. A. Step 1: Fix the log group, so it stops showing up.

Pick one:

bash
<terraform import aws_cloudwatch_log_group.flow_log Internship_flow_log

B. This tells Terraform “that one is yours, add it to your records.” Or, if you’d rather start the folder fresh:

bash
<aws logs delete-log-group --log-group-name Internship_flow_log --region eu-west-2

8. Build. Billing starts now.

bash
<terraform apply "tfplan"

It takes about 20 minutes. Keep the window open.

Part C: Connect and get the website working

9. Connect your laptop to the new cluster.

bash
<aws eks update-kubeconfig --region eu-west-2 --name Internship-Project-EKS

10. Check the servers and programs.

bash
<kubectl get nodes

<kubectl get pods -A

You should see 5 nodes as Ready.

11. Get the new front door address.

bash
<terraform output load_balancer_hostname

12. Update DNS (in the AWS console).

Open Route 53 → Hosted zones → cloudbinocular.online. Edit the argocd Alias record and pick the new load balancer in the dropdown. Why: the old one was deleted, so the record points at nothing.

13. Check the DNS.

bash
<nslookup argocd.cloudbinocular.online 8.8.8.8

It should show IP numbers.

14. Add the Argo CD ingress.

bash
<kubectl apply -f manifests/argocd-ingress.yaml

Why: you add this by hand, so a destroy removes it, and it has to be added again each time.

15. Wait for the HTTPS certificate.

bash
<kubectl get certificate -A

Run it every minute until READY is True (2 to 10 minutes).

16. Get the new Argo CD password.

bash
<terraform output -raw argocd_initial_admin_password

Then open https://argocd.cloudbinocular.online, user admin. Don’t share the password.

Part D: Check your flow log is working

17. Confirm it exists.

bash
<aws ec2 describe-flow-logs --region eu-west-2

You should see Internship_flow_log with FlowLogStatus: ACTIVE.

18. Wait 10 to 15 minutes, then check records are arriving.

bash
<aws logs describe-log-streams --log-group-name Internship_flow_log --region eu-west-2

You should see log streams listed. In the console, open CloudWatch → Log groups → Internship_flow_log to read them.

Why wait: flow logs deliver in batches, so they don’t appear instantly.

Part E: Stop for the day

19. Delete everything, so the charges stop.

bash
<terraform destroy

Check the count (about 56), then type yes. The flow log’s records are deleted with the log group, so look at them before destroying if you want to keep any (a screenshot is enough for LinkedIn).

20. Check the console is empty for EKS, Load Balancers, NAT gateways and Elastic IPs.

If anything goes wrong

Copy the whole error and send it to me. Don’t re-run the command first, and don’t delete things by hand in AWS.

Tell me what Part A shows, especially the result of terraform state list.

git add . ; git commit -m "Update 1" ; git push origin main -f