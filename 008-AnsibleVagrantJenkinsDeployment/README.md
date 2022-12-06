# Project Name: Install Jenkins Using Ansible

# Project Goal
In this lab, you will learn how to use Ansible to install Jenkins 
# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Post Project](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

# <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Ansible (see installation guide [here](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html))
- Vagrant(see installation guide [here](https://developer.hashicorp.com/vagrant/downloads))
- Vbox(see installation guide [here](https://www.virtualbox.org/wiki/Linux_Downloads))
# <a name="project_steps">Project Steps</a>

## 1. Create a VM to Install Jenkins
We are using **Vagrant** to create a VM to install the Jenkins application
```
vagrant provision
vagrant up
```
> Note: Select the network card which is being used to connect to Internet

## 2. Run Ansible Playbook
> Note: Before you run the Ansible Playbook, you need to SSH into the Vagrant VM created above and accept the finger print. If you don't do this, then you may encounter errors when you try and run the Ansible Playbook
```
ssh-copy-id admin@192.168.33.10
ssh admin@192.168.33.10 
exit
```
You can run below **ad-hoc** command to make sure the Ansible is able to talk to the VM:
```
ansible -i hosts.ini jenkins_vm -m ping 
```
> Note: If you are using other VM instead of Vagrant, you need to update the IP in `hosts.ini`
You should get below response if it is successful
```
jenkins_vm | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```
Then, in your **local host**, run below Ansible playbook script:
```
ansible-playbook install-jenkins.yml -i hosts.ini --ask-pass --ask-become-pass
``` 
> Note: The password is stored in `Vagrantfile` for `admin` user if you are using Vagrant as VM. The default is `admin123`. You should see below output if the installation is successful.
Below output when the deployment is done:
```
SSH password: 
BECOME password[defaults to SSH password]: 

PLAY [jenkins_vm] **************************************************************************************
...
PLAY RECAP *********************************************************************************************
jenkins_vm                 : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```

## 3. Unlocking Jenkins
When you first access the new Jenkins install, you are asked to unlock it using an automatically-generated password. </br>
a. **Browse** to http://192.168.33.10 (or whichever port you configured for Jenkins when installing it) and wait until the Unlock Jenkins page appears. </br>
b. Run `sudo cat /var/lib/jenkins/secrets/initialAdminPassword` in the Vagrant VM or any other VM you installed the Jenkins and enter the password showed and click "Next". </br>
c. Click **"Install suggested plugins"** and wait for all plugins are installed.</br>
d. Fill out the info for your First **Amdin User**. </br>
- **Username:** admin </br>
- **Password:** test123</br>  
- **Confirm password:** test123</br>
- **Full name:** Jenkins</br>
- **E-mail address:** jenkins@gmail.com</br>
Click **"Save and Continue"**</br>
e. Click **"Save and Finish"** and click **"Start using Jenkins"**. Then you should login as the admin user you just created previously

## 4. Using Ansibel Role 
You are **done** with the Jenkins via Ansible. </br>
Now, we are going to use **Ansible Role** to install the Jenkins instead. **Ansible Role** are consists of many playbooks and it is a way to group multiple tasks together into one container to do automation in very effective manner with clean directory structures. It can be easily reuse the codes by anyone if it it is suitable. </br>
Before that, you can uninstall the Jenkins/Java package in the Vagrant VM, if you are going to use the same VM. </br>
We are going to apply the Ansible Playbook `uninstall-jenkins.yaml` to remove the related packages before we start the new deployment:
```
ansible-playbook uninstall-jenkins.yml -i hosts.ini --ask-pass --ask-become-pass
```
Run below command to download the Jenkins Role from **Ansible Galaxy**:
```
ansible-galaxy install geerlingguy.jenkins
```
The Role will be installed under `~/.ansible/roles`
``` 
cd ~/.ansible/roles/geerlingguy.jenkins
ls
defaults  handlers  LICENSE  meta  molecule  README.md  tasks  templates  tests  vars
```
Roles expect files to be in certain directory names. Each directory must contain a `main.yml` file. Below is a describption of each directory.</br>
**tasks** - Contains the main list of tasks to be executed by the role</br>
**handlers** - contains handlers, which may be used by this role or even anywhere outside this role</br>
**defaults** - default variables for the role</br>
**vars** - other variables for the role.</br>
**files** - containers file which can be deployed via this role</br>
**templates** - contains templates which can be deployed via this role.</br>
**meta** - defines some meta data for this role.</br>
Run below command to apply the **Ansible Role**:
```
ansible-playbook install-jenkins-role.yml -i hosts.ini --ask-pass --ask-become-pass
```

# <a name="post_project">Post Project</a>
Destroy Vagrant VM
```
vagrant destroy
```

# <a name="troubleshooting">Troubleshooting</a>
## Issue 1: The IP address configured for the host-only network is not within the
allowed ranges.
When running `vagrant up`, showing below error:
```
The IP address configured for the host-only network is not within the
allowed ranges. Please update the address used to be within the allowed
ranges and run the command again.

  Address: 192.168.33.10
  Ranges: 192.168.56.0/21

Valid ranges can be modified in the /etc/vbox/networks.conf file. For
more information including valid format see:

  https://www.virtualbox.org/manual/ch06.html#network_hostonly
```
**Solution:**
ref: https://stackoverflow.com/questions/70704093/the-ip-address-configured-for-the-host-only-network-is-not-within-the-allowed-ra

# <a name="reference">Reference</a>
[Install Jenkins in Linux](https://www.jenkins.io/doc/book/installing/linux/)</br>
[Install Jenkins Using Ansible On Ubuntu](https://blog.knoldus.com/how-to-install-jenkins-using-ansible-on-ubuntu/)</br>
[Installing Jenkins using an Ansible Playbook](https://medium.com/nerd-for-tech/installing-jenkins-using-an-ansible-playbook-2d99303a235f)</br>
[Jenkins Role](https://galaxy.ansible.com/geerlingguy/jenkins)</br>
