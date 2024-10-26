# Quentin's Homeserver

<p><img alt="gitleaks badge" src="https://img.shields.io/badge/protected%20by-gitleaks-blue"></p>

This is a long living DIY homeserver project that I build over the years in my spare time. My end goal is to replace most of my third-party cloud dependencies (Spotify, Netflix, Newsfeeds...) by self-hosted, open source alternatives. I'd also like to try some smart home solutions.

This is the IaC repository for said homeserver, currently using:
- Ansible for infrastructure deployment and setup
- [git-crypt](https://github.com/AGWA/git-crypt) for secrets encryption
- [gitleaks](https://github.com/gitleaks/gitleaks) to detect secrets possibly slipping through the net

## Hardware configuration

Currently my needs are met with a very cheap solution: a Raspberry Pi 4 (ARM).

At some point, I'll opt for a more powerfull machine, and at that time I think I will migrate the infrastructure to a type 1 hypervisor (probably [proxmox](https://www.proxmox.com/en/), which I cannot use at the time because it doesn't work properly on RaspberryPi). I'll then be able to use the Proxmox Terraform provider to easily set it up. Until then, everything runs on the Pi's bare metal, via docker containers.

## How to install

Requirements on the hosts:
- Linux OS installed 
- SSH user/password connection enabled
- Python installed (out of the box on most distros)

Then, from the control node (typically linux laptop):
- Install Ansible (2.16.2+) 
- Install git-crypt
- Make sure you have the GPG key in your keyring (passwords are encrypted via git-crypt)

Then, unlock the repository's secrets with:

```sh
git-crypt unlock
```

Then, install the dependencies and run the desired playbook in the desired environement. `all.yaml` playbook deploys everything:
```sh
ansible-galaxy install -r requirements.yml
ansible-playbook -i inventories/[prod|staging] playbooks/all.yaml -kK
```

If there are errors, debug will be easier with the -v(erbose) option.
