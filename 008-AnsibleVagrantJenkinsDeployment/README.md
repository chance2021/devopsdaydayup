# Lab 8 — Install Jenkins with Ansible on a Vagrant VM

Use Ansible to provision Jenkins on a Vagrant VM, then repeat using an Ansible role for cleaner reuse.

> Replace any default passwords with your own. Do not commit credentials.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Ansible installed locally
- Vagrant and VirtualBox with VT-x/AMD-V enabled

## Architecture

- Vagrant provisions a VM for Jenkins.
- Ansible installs Jenkins (and Java), unlocks, and configures plugins.
- An Ansible role demonstrates reusable installation.

## Setup

1) Create the VM

```bash
vagrant provision
vagrant up
```
Select the network interface that has Internet access when prompted.

2) Prepare SSH trust for Ansible

```bash
ssh-copy-id admin@192.168.33.10
ssh admin@192.168.33.10
exit
```

Verify Ansible connectivity:
```bash
ansible -i hosts.ini jenkins_vm -m ping
```

3) Install Jenkins via playbook

```bash
ansible-playbook install-jenkins.yml -i hosts.ini --ask-pass --ask-become-pass
```
Default Vagrant password for `admin` is `admin123` unless you changed it.

4) Unlock Jenkins

- Browse to `http://192.168.33.10:8080`.
- On the Unlock screen, run inside the VM:
  ```bash
  sudo cat /var/lib/jenkins/secrets/initialAdminPassword
  ```
- Install suggested plugins, then create the first admin user (choose your own credentials).

5) Install Jenkins via Ansible role (optional)

- Remove Jenkins if reusing the same VM:
  ```bash
  ansible-playbook uninstall-jenkins.yml -i hosts.ini --ask-pass --ask-become-pass
  ```
- Install the role:
  ```bash
  ansible-galaxy install geerlingguy.jenkins
  ```
- Apply the role:
  ```bash
  ansible-playbook install-jenkins-role.yml -i hosts.ini --ask-pass --ask-become-pass
  ```

## Validation

- Jenkins UI reachable at `http://192.168.33.10:8080`.
- Initial admin password present at `/var/lib/jenkins/secrets/initialAdminPassword`.
- Playbook output ends with `failed=0`.

## Cleanup

```bash
vagrant destroy -f
```

## Troubleshooting

- **Host-only network IP out of range**: Adjust VirtualBox host-only network ranges per `/etc/vbox/networks.conf`.
- **SSH/Ansible connectivity issues**: Ensure fingerprint accepted and `hosts.ini` IP matches the VM.

## References

- https://www.jenkins.io/doc/book/installing/linux/
- https://galaxy.ansible.com/geerlingguy/jenkins
