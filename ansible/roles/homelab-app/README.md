Role Name
=========

An opinionated role to deploy a simple in my homelab setting. Used to easily install and manage new apps.

Requirements
------------

None.

Role Variables
--------------

Dependencies
------------

None.

Example Playbook
----------------

    - name: Deploy uptime-kuma
      hosts: uptime-kuma
      roles:
        - homelab-app
      vars:
        homelab_app_name: uptime-kuma
        homelab_app_traefik_network: traefik
        homelab_app_apps_domain: "{{ homeserver_domain }}"
        homelab_app_internal_port: 3001
        homelab_app_compose_template: "resources/uptime-kuma/compose.yml.j2"

License
-------

MIT

Author Information
------------------

Quentin Bonnet, software engineer, Q.Bonnet Software&IT ([website](https://bonnet.software)).
