#!/bin/bash
set -x
sudo sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/subscription-manager.conf
sudo sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/product-id.conf
# 
ls /etc/yum.repos.d
yum install dnf -y
dnf repolist


sudo curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial  https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-rockyofficial
sudo curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-8 https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-8

sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-8
