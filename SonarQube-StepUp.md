# SonarQube Setup Guide

This guide explains how to set up a SonarQube server in a DevSecOps environment and connect it to your GitHub workflow. 

Search for; DOD American devesecops framework pdf to learn more

## 1. Create the VPC and networking

Create the following resources in AWS:

- VPC
- Public subnet
- Route table
- Internet Gateway
- Security group

Security group inbound rules to open:

- SSH: 22
- HTTP: 80
- HTTPS: 443

## 2. Launch the EC2 instance

Create an EC2 instance and configure it as follows:

- Name: use a meaningful name such as `sonarqube-server`
- AMI: Ubuntu 24.04
- Instance type: `t2.large` or `m7i.flex` (minimum 8 GB RAM is recommended for SonarQube)
- VPC: attach the VPC you created
- Subnet: choose the public subnet
- Availability zone: select the correct AZ for the subnet
- Security group: use the one created above
- Auto-assign Public IP: enable it
- Key pair: create a new key pair and save it securely
- Storage: increase the root volume to at least 20 GB

After launch, connect to the server using Mobaxterm or any SSH client with the private key.

## 3. Perform the initial server setup

## 4. Install Docker

Follow the official Docker installation guide for Ubuntu:

https://docs.docker.com/engine/install/ubuntu/ `copy the code block`

Then install Docker Cli with one of the following options:

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

Check Docker status:

```bash
sudo docker ps
```

## 5. Prepare the SonarQube directory

Add the `ubuntu` user to the Docker group and verify access:

```bash
sudo usermod -aG docker ubuntu
sudo su - ubuntu
sudo cat /etc/group #To check if the 
mkdir sonarqube
cd sonarqube
```

## 6. Configure DNS for SonarQube

In Namecheap or Route 53  provider), create a CNAME or A record Respectively:

- Type: CNAME
- Host: `sast` (static application security testing)
- Value: your EC2 public IP address
- TTL: automatic

Example:

- `sast.yourdomain.com` or `sonar.yourdomain.com` -> `your.ec2.public.ip`

Then check propagation using a DNS checker.

## 7. Edit the Docker Compose file

Go to the configuration management section in your repo and locate the `docker-compose.yaml` file.

Update the file with your own values such as:

- email address
- domain name
- SonarQube settings

Open the file in the server using nano:

```bash
nano docker-compose.yaml
```

Paste the edited configuration, then save:

- `Ctrl + O`
- `Enter`
- `Ctrl + X`

## 8. Start SonarQube

Run the Compose file:

```bash
docker compose up -d
```

If your environment uses the older command, you can also use:

```bash
docker-compose up -d
```

Check the logs:

```bash
docker logs ngnix-proxy -le
docker compose logs -f
```
sudo systemctl status ngnix

or

```bash
docker-compose logs -f
```

Wait until the container is fully started.

## 9. Access the SonarQube UI

Open the browser and go to:

```text
https://sast.yourdomain.com
```

The SonarQube login page should load.

Default credentials:

- Username: `admin`
- Password: `admin` change this to your own

After logging in, change the default password immediately.

## 10. Quality Gate 

Quality Gate is the conditions your code to what terraform must meet

Search On Google:SonarQube gate security best for terraform deployment.

Name:`Terraform-benchmark-quality-gate`
Add condition:`On-New code`
Search
`Security Rating` = A
`maintainability Rating`= A 
`Low severity Issues`= 5
`Security Review Rating` = A 

Go to the 3 dot and turn the 'One you created' as the default

## Quality Profile
Scroll down and get to Terraform that is the one we are interested in
G to the '51' sonar way comprehensive. 
Because it has more rules.
Make it default from the 3 dots.

## Create your Token

Go to:Administration
Generate Token 
Name: `Sonar-pipeline-token`
Type: `Global Analysis Token`
Expires in: `30 days`
Click Generate

Copy the token and store it securely.

Then add the token to GitHub repository secrets, for example:

- `SONAR_TOKEN=XXXXXXXXXXXX`
- `SONAR_HOST_URL=https://sast.yourdomain.com`

## 11 Final check

## Useful command summary

```bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo usermod -aG docker ubuntu
sudo su - ubuntu
mkdir sonarqube
cd sonarqube
nano docker-compose.yaml
docker compose up -d
docker compose logs -f
```

This completes the SonarQube server setup and configuration process.