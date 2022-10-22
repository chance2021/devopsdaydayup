# Project Name: Gitlab CICD Pipeline
This project will show how to setup a Gitlab CICD pipeline, which will build the source code to a docker image and push it to the container registory in Gitlab and then re-deploy the docker container with the latest image in your local host.

# Project Goal
Understand how to setup/configure Gitlab as CICD pipeline. Familarize with gitlab pipeline.

# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Post Project](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

# <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Docker
- Docker Compose

# <a name="project_steps">Project Steps</a>

## 1. Setup a bastion VM in Oracle Cloud
You can refer to [here](https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/helidon-on-ubuntu/01oci-ubuntu-helidon-summary.htm#create-ubuntu-vm) for the detail steps to setup your bastion VM in your Oracle Cloud account.

## 2. Install Terraform in the bastion VM
SSH to the bastion VM and run below commands:
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Once it is done, you should be able to see the terraform version installed in your bastion host
terraform -v
```

> Refer to https://www.terraform.io/downloads

## 3. Create RSA Keys for Terraform used
```bash
mkdir $HOME/.oci
openssl genrsa -out $HOME/.oci/terraform_private.pem 2048
chmod 600 $HOME/.oci/terraform_private.pem
openssl rsa -pubout -in $HOME/.oci/terraform_private.pem -out $HOME/.oci/terraform_public.pem
$HOME/.oci/terraform_public.pem
```

## 4. Add the public key to your user account
- From your user avatar, go to User Settings (My Profile).
- Click API Keys.
- Click Add API Key.
- Select Paste Public Keys.
- Paste value from previous step, including the lines with BEGIN PUBLIC KEY and END PUBLIC KEY
- Click Add and you will get a configuration setting
- Paste the contents of the text box into your ~/.oci/config file and make sure to replace <path to your private keyfile> with actual path to your private keyfile generated in previous step.
You have now set up the RSA keys to connect to your Oracle Cloud Infrastructure account.


# <a name="post_project">Post Project</a>

# <a name="troubleshooting">Troubleshooting</a>



# <a name="reference">Reference</a>
[Terraform: Create a Compute Instance](https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/tf-compute/01-summary.htm)
