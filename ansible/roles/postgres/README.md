Ansible Role: Postgres
=========

Setup and manage a postgres instance listening on your private network: install, setup automatic backups, restore from backup.

geerlinguy has made a great job at providing a cross-distro setup of postgres. For my home server, I wanted something a little more feature-rich, while not having to redo all the setup logic. So I made this role, which is an encapsulation of geerlinguy's work. 

This is opinionated, tilted towards my homeserver use case; if you're in a similar use case you should be able to use it out of the box. If not, it should not be too hard to tweak a little.

Assumptions:
  - The postgres instance is on a private network and listens for TCP connections on its network interface
  - Each database has *one* user, which can do anything to the database and nothing on other databases
  - Each database can be reached from the local lan, and from one additional subnet
  - Your backup folder can be accessed rwx by `postgres` user, or you can provide a user that can with the `postgres_backup_user=username` variable

By default, it will install postgres and set it up with your databases. You can run other operations with tags (see "Role Variables" section below). 

Requirements
------------

Uses geerlinguy.postgresql and therefore has the same requirements.

Role Variables
--------------

On top of the required vars shown in the example playbook, there can be some expectations depending on tags. Tags are used to run some specific operations.

By default the role installs postgres and setups your databses. See the example playbook below for a full example.

Then, with tags, you can do the following:

### Run a backup manually
```
ansible-playbook yourplaybook.yml --tags "backup" --extra-vars "db=mydb"
```

### Restore from a backup
Latest backup in the backups folder:
```
ansible-playbook yourplaybook.yml --tags "restore" --extra-vars "db=mydb" 
```

Specific backup in the backups folder:
```
ansible-playbook yourplaybook.yml --tags "restore" --extra-vars "db=mydb" --extra-vars "backup=my_backup_filename"
```
Only give the base filename, not the path to it (so "dump-db-date.tar.gz", not "/my/backup/dir/dump-db-date.tar.gz").

Dependencies
------------

geerlinguy.postgresql

Example Playbook
----------------

    - hosts: postgresservs
      roles:
        - role: postgres
          vars:
            postgres_host_ip: "{{ ansible_host }}"
            postgres_client_cidr: "{{ k3s_controller_ip }}/32"
            postgres_lan_cidr: "{{ lan_cidr }}"
            postgres_no_log: false # Optional, defaults to true. Useful in testing.
            postgres_backup_user: nfs # Optional, defaults to postgres user. Useful if, like me, your backups folder is on a network mounted folder with specific user.
            postgres_databases:
              - name: my-db
                user: db-user
                password: apassword
                backup_cron:
                  # Dump the database on NFS share everyday at 5
                  # Uses the builtin ansible cron module, so you can use all cron parameters 
                  hour: 5
                  minute: 0

License
-------

MIT

Implementation details
-------

I wanted to use the same role interface for creation/backup/restore operations, in order to guarantee that dbs are always setup the exact same. The use of tags achieves that, however it makes the code a little spaghetti-esque (following the exact run path for a given tag is not the easiest thing).

After comparing the various `pg_dump` methods, I settled on tar dump with explicit call of gzip, which lets me specify the compression level. I settled on `-6`, which seems to be a sweet spot between compression ratio and time.
