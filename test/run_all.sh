#!/bin/zsh

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="$SCRIPT_DIR/.."

cd "$SCRIPT_DIR"

vagrant destroy -f --no-tty

vagrant up --no-tty && \
ssh-keygen -R 192.168.121.101 && \

ansible-playbook -e 'host_key_checking=False' -i "$PROJECT_DIR/inventories/test" "$PROJECT_DIR/playbooks/all.yaml" --ssh-common-args='-o StrictHostKeyChecking=no'

vagrant destroy -f --no-tty
