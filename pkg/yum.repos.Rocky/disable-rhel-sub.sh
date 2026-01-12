#!/bin/bash
set -x
sudo sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/subscription-manager.conf
sudo sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/product-id.conf
# 
ls /etc/yum.repos.d
yum install dnf -y
dnf repolist
