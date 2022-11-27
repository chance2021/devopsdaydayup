# Project Name: 

# Project Goal

# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Post Project](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

# <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Docker(see installation guide [here](https://docs.docker.com/get-docker/))
- Docker Compose(see installation guide [here](https://docs.docker.com/compose/install/))

# <a name="project_steps">Project Steps</a>

## 1. Step 1
vagrant up
Select the network card which is being used to connect to Internet

## 2. Step 2

# <a name="post_project">Post Project</a>

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
