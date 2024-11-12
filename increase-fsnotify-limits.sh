#!/bin/bash
line1="fs.inotify.max_user_watches=524288"
line2="fs.inotify.max_user_instances=512"

# Check if the lines already exist in /etc/sysctl.conf, and add them if they don't
grep -qxF "$line1" /etc/sysctl.conf || echo "$line1" | sudo tee -a /etc/sysctl.conf
grep -qxF "$line2" /etc/sysctl.conf || echo "$line2" | sudo tee -a /etc/sysctl.conf

# Reload sysctl settings
sudo sysctl -p