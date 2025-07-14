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

    - name: "Deploy qbittorrent"
      hosts: servarr
      roles:
        - homelab-app
      vars:
        homelab_app_name: qbittorrent
        homelab_app_cpus: 1.5
        homelab_app_traefik_network: traefik
        homelab_app_apps_domain: "{{ homeserver_domain }}"
        homelab_app_internal_port: 8080
        homelab_app_compose_template: "resources/qbittorrent/compose.yml.j2"
        homelab_app_volume_names:
          - config
        homelab_app_backups:
          - volume: config
            cron: "35 6 * * *"

License
-------

MIT

Author Information
------------------

Quentin Bonnet, software engineer, Q.Bonnet Software&IT ([website](https://bonnet.software)).
