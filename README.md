# Installation

Install the homeserver infra with ansible.

## How to

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

Then, install the dependencies and run the playbook:
```sh
ansible-galaxy install -r requirements.yml
ansible-playbook -i hosts.yaml playbook.yaml -k
```

If there are errors, debug will be easier with the -v(erbose) option.

You can also run some specific steps of the playbook with tags:
```sh
ansible-playbook -i hosts.yaml playbook.yaml -k --tags services
```

## TODO

- [ ] Logstash for log aggregation and Kibana for reading logs in web UI
- [ ] Open source smart home server (HomeAssistant?)
- [ ] Test it with a first device (temperature sensor in office?)

## Proxmox PoC

Install proxmox as an OS.

Log into proxmox http interface as an admin, and:
1. Create an API token for the admin user, with all privileges (uncheck "privilege separation"); TODO: find the minimal set of privileges, define a role with those, and attribute it to the token
2. Pull the iso image for VMs, can't be done with terraform proxmox provider yet (double click the storage>ISO Images>Download from URL>https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-standard-3.19.0-x86_64.iso)
3. Create a default bridge network (double click the node>System>Network>Create>Linux bridge, should create vmbr0)

Then, the terraform config can be applied:
```sh
cd proxmox
terraform init
terraform plan
terraform apply
```
