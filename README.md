# Quentin's Homeserver

<p><img alt="gitleaks badge" src="https://img.shields.io/badge/protected%20by-gitleaks-blue"></p>

This is a long living DIY homeserver project that I build over the years in my spare time. My end goal is to replace most of my third-party cloud dependencies (Spotify, Netflix, Newsfeeds...) by self-hosted, open source alternatives. I'd also like to try some smart home solutions.

This is the IaC repository for said homeserver, currently using:
- Terraform for insfrastructure provisionning (VMs in Proxmox host)
- Ansible for infrastructure configuration and services setup
- [git-crypt](https://github.com/AGWA/git-crypt) for secrets encryption
- [gitleaks](https://github.com/gitleaks/gitleaks) to detect secrets possibly slipping through the net

Currently, the Terraform states are stored in local files that are pushed after being git-crypted. It's definitely not best practice, but it's enough for my current needs and to start experimenting with Terraform.

## Requirements

Requirements on the host:
- Proxmox installed
- SSH user/password connection enabled (would be better to not rely on that in the long run)

Then, from the control node (typically linux laptop):
- Install Ansible (2.16.2+) 
- Install OpenTofu (1.8.2+), a truly open source Terraform fork
- Install git-crypt
- Make sure you have the GPG key in your keyring (passwords are encrypted via git-crypt)

Then, unlock the repository's secrets with:

```sh
git-crypt unlock
```

Install the Ansible dependencies (in the relevant python venv)

```sh
cd ./ansible
pip install -r requirements.txt
ansible-galaxy install -r requirements.yml
```

## How to install

i.e. in staging env.

Deploy the infrastructure:

```sh
cd ./terraform/staging/downloads
tofu apply
cd ../networking
tofu apply
cd ../opnsense
tofu apply
```

In a dedicated ansible terminal (where you enabled the relevant python venv)
(If there are errors, debug will be easier with the -v(erbose) option)

```sh
cd ./ansible
ansible-playbook -i inventories/staging playbooks/opnsense.yaml
```

From the Terraform terminal, deploy the services infrastructure:

```sh
cd ../legacy
tofu apply
```

One last thing that is not automated (and I'm not sure to automate it because I'm not 100% sure after the network desing yest). Ssh into the proxmox host and configure the route to staging infra:
```sh
ip route replace 10.142.0.0/16 dev vmbr1001 via 10.142.1.1 
```

Finally, from the Ansible Terminal, configure all services:
```sh
ansible-playbook -i inventories/staging playbooks/all_services.yaml
```

Then, if you wanna reach the staging env from your local machine, add the 10.142.1.1 router to your local /etc/resolv.conf
