# Installation

Install the homeserver infra with ansible.

## How to

Requirements on the hosts:
- Linux OS installed 
- SSH user/password connection enabled
- Python installed (out of the box on most distros)

Then, from the control node (typically linux laptop):
- Install Ansible (2.16.2+) 
- Make sure you have the GPG key in your keyring (passwords are encrypted via git-crypt)
- Simply run the playbook with:

```sh
ansible-playbook -i hosts.yaml playbook.yaml -k
```

If there are errors, debug will be easier with the -v(erbose) option.
