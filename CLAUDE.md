# Homeserver

This repository is the infrastructure as code (Ansible, Terraform) and nothing else.

- Never SSH into the hosts (`apps_vm`, `dns_vm`…) for live diagnostics: work from the playbooks and templates (`compose.yml.j2`, role defaults, hooks and scripts) and the logs the user pastes; when more live data would help, ask them for it (`docker inspect`, `docker events`, log lines).
