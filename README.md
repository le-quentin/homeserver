# Quentin's Homeserver

<p><img alt="gitleaks badge" src="https://img.shields.io/badge/protected%20by-gitleaks-blue"></p>

This is a long living DIY homeserver project that I build over the years in my spare time. My end goal is to replace most of my third-party cloud dependencies (Spotify, Netflix, Newsfeeds...) by self-hosted, open source alternatives. I'd also like to try some smart home solutions.

This is the IaC repository for said homeserver, currently using:
- Terraform for infrastructure provisioning (actually, its 100% open source fork OpenTofu)
- Ansible for infrastructure deployment and setup
- [git-crypt](https://github.com/AGWA/git-crypt) for secrets encryption
- [gitleaks](https://github.com/gitleaks/gitleaks) to detect secrets possibly slipping through the net

Requirements:
- Install OpenTofu (1.8.2+)
- Install Ansible (2.16.2+) 
- Install git-crypt
- Make sure you have the GPG key in your keyring (passwords are encrypted via git-crypt)

Unlock the repository's secrets with:

```sh
git-crypt unlock
```
## Initial setup

Install ProxmoxVE on the host.

SSH into it and disable ipv6 (reduce attack surface):
```sh
vi /etc/default/grub
```
Add `ipv6.disable=1` to the end of `GRUB_CMDLINE_LINUX_DEFAULT` and `GRUB_CMDLINE_LINUX` line. Don't change the other values at those lines.

```sh
update-grub
```

Then reboot. Check ipv6 addresses are not shown anymore with `ip a`.

## Provisioning

i.e. in staging

```sh
cd terraform/staging/downloads
tofu init
tofu apply
cd ../networking
tofu init
tofu apply
cd ../dns
tofu init
tofu apply
cd ../legacy
tofu init
tofu apply
```

## Deployment

Then, install the dependencies and run the overall playbook, i.e. in staging:
```sh
cd ansible
ansible-galaxy install -r requirements.yaml
ansible-playbook -i inventories/staging playbooks/all.yaml
```

If there are errors, debug will be easier with the -v(erbose) option.

## TODO

- [ ] Setup the Home-Assistant recorder, to control what's stored for how long
- [ ] Migrate Home-Assistant DB to MySQL
- [ ] Use Packer to produce base linux image with Docker and initial setup
- [ ] Logstash for log aggregation and Kibana for reading logs in web UI
- And many more things I'll list soon

