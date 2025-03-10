backups
=========

Perform backups of directories, ZFS snapshots, and rclone remote storage.

Requirements
------------
Role Variables
--------------

### Run a backup manually
```
ansible-playbook yourplaybook.yml --tags "run-local"
```

### Restore from a local backup
Restore from latest local backups:
```
ansible-playbook yourplaybook.yml --tags "restore-local" --extra-vars "backups_restore_directory_regex=.*"
```
This will restore from all configs, but any regex can be used to restore specific directories.

### Restore from a ZFS snapshot
Restore from latest snapshots:
```
ansible-playbook yourplaybook.yml --tags "restore-snapshot" --extra-vars "backups_restore_snapshot_regex=.*"
```
This will restore from all configs, but any regex can be used to restore specific snapshot.

### Pull from distant storage (rclone)
After a disaster or a migration, it can be useful to pull all latest backups from distant storage (with rclone):
```
ansible-playbook yourplaybook.yml --tags "pull-rclone"
```
This will pull the most recent (from the timestamp in names) archive for each backup, in their expected location as defined in the `backups_rclone` config

Dependencies
------------

Example Playbook
----------------

Setup local backups with tar:

    - name: Setup backups
      hosts: backupservs
      roles:
        - role: backups
          vars:
            backups_local:
              - default_compression_level: 6
                default_cron:
                  hour: 13
                  minute: 54
                src_root: /srv/nfs/k3s/volumes
                target_root: /srv/nfs/backups
                directories:
                  - path: home-assistant/all-data # can begin with a '/', in which case it is an absolute path ignoring the target_root property; or not begin with a '/', in which case it is a relative path added to the root.

            backups_snapshots:
              - default_cron:
                  hour: 6
                  minute: 0
                zfs_pool: nfs_pool
                filesystems:
                  - name: home-assistant

            backups_rclone:
              - default_cron:
                  hour: 7
                  minute: 0
                conf_template_path: ./resources/backups/rclone.conf
                src_root: /srv/nfs/backups
                target_root: /backups/homeserver-staging

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
