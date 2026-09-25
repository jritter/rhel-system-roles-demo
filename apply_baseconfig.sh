#!/bin/bash
ansible-navigator run -i inventory -m stdout \
    --eei registry.redhat.io/ansible-automation-platform-27/ee-supported-rhel9:latest \
    baseconfig.yml
