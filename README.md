Build NetApp SnapMirror active sync configuration (SM-AS) with Linux using NetApp Lab On Demand :
--------------------------------------------------
- You can use Lab on Demand ONTAP 9.14.1 : https://labondemand.netapp.com/node/724
- NetApp SnapMirror Business Continutiy (SM-BC): https://docs.netapp.com/us-en/ontap/smbc/index.html

Introduction
------------
Before initiating this lab, it's **imperative to verify** that data aggregates exist on both cluster1 and cluster2 using the System Manager.
- Use the Menu **STORAGE -> Tiers -> Add Local Tier** from ONTAP System Manager:
<img src="Pictures/SystemManagerTiers.png" alt="NetApp System Manager" width="1100" height="350">

The following scripts are avaialbe from [demosmbc](https://github.com/jbnetapp/demosmbc). The scipts automatically build an SM-BC configuration between cluster1 and cluster2 using NetApp Lab on Demande [Early Adopter Lab for ONTAP 9.14.1 v1.1](https://labondemand.netapp.com/node/724). The scripts can work with ONTAP 9.9.1 or later. This section provides a brief overview of all the scripts that are available for use: 
- The  script **0-Setup-Linux-iscsi.sh** is responsible for installing all necessary Linux packages, configuring the kernel variable, and subsequently rebooting the system.
- The script **1-Install-Linux-NetAppTools.sh** is designed to automate the installation of the **NetApp host utilities kit** and the **the NetApp Mediator 1.7** which are available in the [pkg directory](https://github.com/jbnetapp/demosmbc/tree/main/pkg)
- The script **2-Setup-ontapsmbc.sh** is designed to build the full SM-BC configuration with all following steps:
	- Create dedicated Intercluster LIFS on cluster1 and cluster2 
	- Create Cluster peer between cluster1 and cluster2
	- Create vserver SAN with 4 iscsi DATA LIF on cluster1 and cluster2
	- Create vserver peer between vserver SAN of cluster1 and cluster2
	- Create a certificate for the Mediator on cluster1 and cluster2
	- Add a mediator on cluster1 and cluster2
	- Create a new SAN Lun on a new volume on Cluster1
	- Create SnapMirror synchronous *consistency group* replication from this volume to the cluster2 with *AutomatedFailOver* policy
	- Map the LUN to the iqn/igroup from cluster1 and cluster2
	
- The script **3-Linux-LunDiscover.sh** will discover all LUN path.
  
- The script **4-Linux-LVM-create.sh** is designed to establish a Logical Volume Manager (LVM) configuration and mount a Logical Volume file system on the /data directory..

- The script **5-Linux-LVM-create.sh <lun_index_nb>** is designed to append a new Logical Unit Number (LUN) to the existing primary consistency group.
 
- The script **simpleio.sh** can be used to run IOPs on the LUN (using dd).
	
You can reverse all the configuration bye running the following scripts:
- The first script **Reverse-4-Linux-VM-create.sh**  will delete the LVM configuration create by the script  *3-linux-LVM-create.sh*
- The first script **Reverse-3-Linux-LunDiscover.sh** will automatically unmap the LUN and will remove all Linux devices and iscsi targets discoverd by the script *3-Linux-LunDiscover.sh*
- The sceconds script **Reverse-2-Setup-ontapsmbc.sh** will delete all ONTAP LUN and SVM, mediator, certificate etc.. this script **MUST** be run after the script *Reverse-3-Linux-LunDiscover.sh*

- All scripts used the same configuration File **Setup.conf**

# Example
Use putty to logon with ssh on the linux centos01
````
IP: 192.168.0.61 Login root Password: Netapp1! 
````
Use git clone to get all scripts and all required packages
````
[root@centos1 ~]# git clone https://github.com/jbnetapp/demosmbc
[root@centos1 ~]# cd demosmbc/
````

Run the next script to install all required yum package and confirm the grub kernel update for iscsi before to reboot  linux :
````
[root@centos1 demosmbc]# ./0-Setup-Linux-iscsi.sh
...
...
Run: [grubby --args rdloaddriver=scsi_dh_alua --update-kernel /boot/vmlinuz-3.10.0-1160.6.1.el7.x86_64] [y/n]? : y
Reboot Linux now [y/n]? : y

````
After the linux reboot Used putty to logon again with ssh on the linux centos01: 
````
IP: 192.168.0.61 Login root Password: Netapp1! 
````

Check if that the varaible *rdloaddriver=scsi_dh_alua* has been add into the kernel image file
````
[root@centos1 demosmbc]# cat /proc/cmdline
BOOT_IMAGE=/vmlinuz-3.10.0-1160.6.1.el7.x86_64 root=/dev/mapper/centos-root ro crashkernel=auto spectre_v2=retpoline rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet LANG=en_US.UTF-8 rdloaddriver=scsi_dh_alua
````

Run the next script that will install NetApp Linux Package *Host utilities kit* and *NetApp Mediator 1.2*. Check that the script return the string **Terminate** with exit code **0** :
````
[root@centos1 demosmbc]# ./1-Install-Linux-NetAppTools.sh
...
...
...
Terminate
[root@centos1 demosmbc]# echo $?
0
````


Run the third script that will create SVM, Mediator, LUN, and SnapMirror SMBC relation between cluster1 and cluster2. Check that the script return the string **Terminate** with exit code **0** :
````
[root@centos1 demosmbc]# ./2-Setup-ontapsmbc.sh*
...
...
...
Terminate
[root@centos1 demosmbc]# echo $?
0
````

Check the Mediator status is **connected** on both clusters
````
[root@centos1 demosmbc]# ./runallcluster snapmirror mediator show
/usr/bin/sshpass
/usr/sbin/multipath
/usr/bin/rescan-scsi-bus.sh
Init SSH session host
=========================================================================================
cluster1 > snapmirror mediator show
Access restricted to authorized users

Last login time: 12/21/2020 20:55:47
Mediator Address Peer Cluster     Connection Status Quorum Status
---------------- ---------------- ----------------- -------------
192.168.0.61     cluster2         connected         true

=========================================================================================
cluster2 > snapmirror mediator show
Access restricted to authorized users

Last login time: 12/21/2020 20:55:48
Mediator Address Peer Cluster     Connection Status Quorum Status
---------------- ---------------- ----------------- -------------
192.168.0.61     cluster1         connected         true
````

Check SnapMirror status and chech that the same Lun with same serial number is available on both clusters *Example Serial is *wOj7N$QPt5OO* :
````
[root@centos1 demosmbc]# ssh -l admin cluster2 snapmirror show
Access restricted to authorized users
Password:
Last login time: 12/21/2020 20:44:24
                                                                       Progress
Source            Destination Mirror  Relationship   Total             Last
Path        Type  Path        State   Status         Progress  Healthy Updated
----------- ---- ------------ ------- -------------- --------- ------- --------
SVM_SAN_P:/cg/cg_p XDP SVM_SAN_S:/cg/cg_s Snapmirrored InSync - true   -

[root@centos1 demosmbc]# ./runallcluster lun show -fields serial
/usr/bin/sshpass
/usr/sbin/multipath
/usr/bin/rescan-scsi-bus.sh
Init SSH session host
=========================================================================================
cluster1 > lun show -fields serial
Access restricted to authorized users

Last login time: 12/21/2020 20:44:23
vserver   path               serial
--------- ------------------ ------------
SVM_SAN_P /vol/LUN01_P/LUN01 wOj7N$QPt5OO

=========================================================================================
cluster2 > lun show -fields serial
Access restricted to authorized users

Last login time: 12/21/2020 20:46:56
vserver   path               serial
--------- ------------------ ------------
SVM_SAN_S /vol/LUN01_S/LUN01 wOj7N$QPt5OO
````

Run the script to discover the LUN on Linux with all path and LVM (Logical Volume Manager) with a file system ,using this LUN. Check that the script return the string **Terminate** with exit code **0**  :
````
[root@centos1 demosmbc]# ./3-Linux-LunDiscover.sh
....
Terminate
[root@centos1 demosmbc]# echo $?
0

````
Verify you have 8 available paths for the LUN (4 on each cluster)
````
[root@rhel1 demosmbc]# multipath -ll
3600a0980774f6a34663f57396c4f6b37 dm-2 NETAPP,LUN C-Mode
size=12G features='3 queue_if_no_path pg_init_retries 50' hwhandler='1 alua' wp=rw
|-+- policy='service-time 0' prio=50 status=active
| |- 34:0:0:0 sdc 8:32  active ready running
| `- 36:0:0:0 sdd 8:48  active ready running
`-+- policy='service-time 0' prio=10 status=enabled
  |- 33:0:0:0 sdb 8:16  active ready running
  |- 35:0:0:0 sde 8:64  active ready running
  |- 39:0:0:0 sdh 8:112 active ready running
  |- 37:0:0:0 sdf 8:80  active ready running
  |- 38:0:0:0 sdg 8:96  active ready running
  `- 40:0:0:0 sdi 8:128 active ready running

[root@rhel1 demosmbc]# sanlun lun show
controller(7mode/E-Series)/                                  device          host                  lun
vserver(cDOT/FlashRay)        lun-pathname                   filename        adapter    protocol   size    product
---------------------------------------------------------------------------------------------------------------
SVM_SAN_S                     /vol/LUN01_dst/LUN01           /dev/sdh        host39     iSCSI      12g     cDOT
SVM_SAN_S                     /vol/LUN01_dst/LUN01           /dev/sdi        host40     iSCSI      12g     cDOT
SVM_SAN_S                     /vol/LUN01_dst/LUN01           /dev/sdg        host38     iSCSI      12g     cDOT
SVM_SAN_S                     /vol/LUN01_dst/LUN01           /dev/sdf        host37     iSCSI      12g     cDOT
SVM_SAN_P                     /vol/LUN01/LUN01               /dev/sdd        host36     iSCSI      12g     cDOT
SVM_SAN_P                     /vol/LUN01/LUN01               /dev/sde        host35     iSCSI      12g     cDOT
SVM_SAN_P                     /vol/LUN01/LUN01               /dev/sdc        host34     iSCSI      12g     cDOT
SVM_SAN_P                     /vol/LUN01/LUN01               /dev/sdb        host33     iSCSI      12g     cDOT
````

Run the script to create LVM (Logical Volume Manager) configuration with a file system ,using this LUN. Check that the script return the string **Terminate** with exit code **0**  :
````
[root@centos1 demosmbc]# ./4-Linux-LVM-create.sh
....
Terminate
[root@centos1 demosmbc]# echo $?
0

````
Verfiy file system on LVM device
````
[root@centos1 demosmbc]# df -h /data
Filesystem               Size  Used Avail Use% Mounted on
/dev/mapper/vgdata-lv01  8.8G   37M  8.3G   1% /data

[root@centos1 demosmbc]# vgdisplay vgdata -v |grep "PV Name"
  PV Name               /dev/mapper/3600a0980774f6a374e24515074354f4f
````

Create Simple IO activity for your test and crash on cluster to check SM-BC behavior 
````
[root@centos1 demosmbc]# ./simpleio.sh
Single Write
2000+0 records in
2000+0 records out
2097152000 bytes (2.1 GB) copied, 20.3844 s, 303 MB/s
Fri Jul  2 16:37:01 UTC 2021
Single Read/Write
2000+0 records in
2000+0 records out
2097152000 bytes (2.1 GB) copied, 5.21003 s, 403 MB/s
Fri Jul  2 16:38:54 UTC 2021
````
**Remarque**: The two ONTAP clusters are virtual  runing in an hypervisor so we can not expect to have high throughput performance. 

Now you are ready to play with SM-BC in real life To demonstrate the SAN LUN  transparent application failover so you could:
- Put all Data LIF down from primary cluster1 *network interface modify -status-admin down -lif <>*
- Failover or Reboot cluster1 or cluster2 during IO activity  
- etc..
<img src="Pictures/SystemManagerSMBC.png" alt="NetApp System Manager" width="1100" height="500">

NetApp SMBC Documentation is available here:
--------------------------------------------
- Doc: https://docs.netapp.com/us-en/ontap/smbc

