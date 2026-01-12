Build NetApp SnapMirror active sync configuration (SM-AS) with Linux using NetApp Lab On Demand :
--------------------------------------------------
- You can use Lab on Demand ONTAP 9.18.1 : https://labondemand.netapp.com
- NetApp SnapMirror Active Sync (SM-AS): https://docs.netapp.com/us-en/ontap/snapmirror-active-sync/index.html

Introduction
------------
Before initiating this lab, it's **imperative to verify** that data aggregates exist on both cluster1 and cluster2 using the System Manager.
- Use the Menu **STORAGE -> Tiers -> Add Local Tier** from ONTAP System Manager:
<img src="Pictures/SystemManagerTiers.png" alt="NetApp System Manager" width="1100" height="350">

Before initiating this lab, you have to manually install the mediator package on the Linux Host.

The following scripts are avaialbe from [demosmas](https://github.com/jbnetapp/demosmas). The scipts automatically build an SM-BC configuration between cluster1 and cluster2 using NetApp Lab on Demande [Early Adopter Lab for ONTAP 9.18.1](https://labondemand.netapp.com). The scripts can work with ONTAP 9.15.1 or older. This section provides a brief overview of all the scripts that are available for use: 
- The **0-Setup-Linux-iscsi.sh** script is responsible for installing all necessary Linux packages, configuring the kernel variable, and subsequently rebooting the system.
- The **1-Install-Linux-NetAppTools.sh** script automates the deployment of the **NetApp Host Utilities Kit** and performs a validation check to confirm that the **NetApp Mediator** is properly installed. If the Mediator is not present, it must be installed manually. An installation example is provided below.
- The  **2-Setup-ontap-sm-as-duplex.sh** script is designed to build the full SM-BC configuration with all following steps:
	- Create dedicated Intercluster LIFS on cluster1 and cluster2 
	- Create Cluster peer between cluster1 and cluster2
	- Create vserver SAN with 4 iscsi DATA LIF on cluster1 and cluster2
	- Create vserver peer between vserver SAN of cluster1 and cluster2
	- Create a certificate for the Mediator on cluster1 and cluster2
	- Add a mediator on cluster1 and cluster2
	- Create a new SAN Lun on a new volume on Cluster1
	- Create SnapMirror synchronous *consistency group* replication from this volume to the cluster2 with *AutomatedFailOver* policy
	- Map the LUN to the iqn/igroup from cluster1 and cluster2
	
- The **3-Linux-LunDiscover.sh** script will discover all LUN path.
  
- The **4-Linux-LVM-create.sh** script  is designed to establish a Logical Volume Manager (LVM) configuration and mount a Logical Volume file system on the /data directory..

- The **5-Linux-LVM-create.sh <lun_index_nb>** script is designed to append a new Logical Unit Number (LUN) to the existing primary consistency group.
 
- The  **simpleio.sh** script can be used to run IOPs on the LUN (using dd).
	
You can reverse all the configuration bye running the following scripts:
- The first script **Reverse-4-Linux-VM-create.sh**  will delete the LVM configuration create by the script  *3-linux-LVM-create.sh*
- The first script **Reverse-3-Linux-LunDiscover.sh** will automatically unmap the LUN and will remove all Linux devices and iscsi targets discoverd by the script *3-Linux-LunDiscover.sh*
- The sceconds script **Reverse-2-Setup-ontap-sm-as.sh** will delete all ONTAP LUN and SVM, mediator, certificate etc.. this script **MUST** be run after the script *Reverse-3-Linux-LunDiscover.sh*

- All scripts used the same configuration File **Setup.conf**

# Example
Download the NetApp mediator from Windows and copy to /var/tmp using scp from Windows cmd terminal:
````
C:\Users\Administrator.DEMO>cd Downloads
C:\Users\Administrator.DEMO\Downloads>scp ./ontap-mediator-1.11.0.tgz root@192.168.0.61:/var/tmp
root@192.168.0.61's password:
````

Use putty to logon with ssh on the linux rhel1
````
IP: 192.168.0.61 Login root Password: Netapp1! 
````
Install the mediator and enter the Mediator login and Password enter Y to all question
````
[root@rhel1 ~]# cd /var/tmp
[root@rhel1 tmp]# tar xvf ontap-mediator-1.11.0.tgz
[root@rhel1 tmp]# cd ontap-mediator-1.11.0
[root@rhel1 ontap-mediator-1.11.0]# ./ontap-mediator-1.11.0
ONTAP Mediator: Self Extracting Installer
+ Extracting the ONTAP Mediator installation/upgrade archive
+ Performing the ONTAP Mediator run-time code signature check

ONTAP Mediator requires two user accounts. One for the service (netapp), and one for use by ONTAP to the mediator API (mediatoradmin).
Would you like to use the default account names: netapp + mediatoradmin? (Y(es)/n(o)): Y
Enter ONTAP Mediator user account (mediatoradmin) password:  NetApp1!
Re-Enter ONTAP Mediator user account (mediatoradmin) password: NetApp1!
...
...
Allow SELinux context change?  Y(es)/n(o): Y
...
...
Do you wish to continue? Y(es)/n(o): Y
...
...
Installing ONTAP Mediator. (Log: /var/tmp/ontap-mediator-1.11.0/ontap_mediator.vCkGN7/ontap-mediator-1.11.0/ontap-mediator-1.11.0/install_20260112132318.log)
This step will take several minutes. Use the log file to view progress.
````

Use git clone to get all scripts and all required packages
````
[root@rhel1 ~]# git clone https://github.com/jbnetapp/demosmas
[root@rhel1 ~]# cd demosmas/
````

Check script Configuration File and verifiy if the Mediator Password you enter is correct
````
[root@rhel1 demosmas]# more ./Setup
...
...
MEDIATOR_PORT=31784
MEDIATOR_IP=192.168.0.61
MEDIATOR_PASSWD=$PASSWD
...
...
````

Run the next script to install all required yum package and confirm the grub kernel update for iscsi before to reboot  linux :
````
[root@rhel1 demosmas]# ./0-Setup-Linux-iscsi.sh
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
[root@rhel1 demosmas]# cat /proc/cmdline
BOOT_IMAGE=/vmlinuz-3.10.0-1160.6.1.el7.x86_64 root=/dev/mapper/centos-root ro crashkernel=auto spectre_v2=retpoline rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet LANG=en_US.UTF-8 rdloaddriver=scsi_dh_alua
````

Run the next script that will install NetApp Linux Package *Host utilities kit* and *NetApp Mediator 1.2*. Check that the script return the string **Terminate** with exit code **0** :
````
[root@rhel1 demosmas]# ./1-Install-Linux-NetAppTools.sh
...
...
...
Terminate
[root@rhel1 demosmas]# echo $?
0
````


Run the third script that will create SVM, Mediator, LUN, and SnapMirror Active Sync relation between cluster1 and cluster2. Check that the script return the string **Terminate** with exit code **0** :
````
[root@rhel1 demosmas]# ./2-Setup-ontap-sm-as-duplex.sh.sh*
...
...
...
Terminate
[root@rhel1 demosmas]# echo $?
0
````

Check the Mediator status is **connected** on both clusters
````
[root@rhel1 demosmas]# ./runallcluster snapmirror mediator show
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
[root@rhel1 demosmas]# ssh -l admin cluster2 snapmirror show
Access restricted to authorized users
Password:
Last login time: 12/21/2020 20:44:24
                                                                       Progress
Source            Destination Mirror  Relationship   Total             Last
Path        Type  Path        State   Status         Progress  Healthy Updated
----------- ---- ------------ ------- -------------- --------- ------- --------
SVM_SAN_P:/cg/cg_p XDP SVM_SAN_S:/cg/cg_s Snapmirrored InSync - true   -

[root@rhel1 demosmas]# ./runallcluster lun show -fields serial
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
[root@rhel1 demosmas]# ./3-Linux-LunDiscover.sh
....
Terminate
[root@rhel1 demosmas]# echo $?
0

````
Verify you have 8 available paths for the LUN (4 on each cluster)
````
[root@rhel1 demosmas]# multipath -ll
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

[root@rhel1 demosmas]# sanlun lun show
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
[root@rhel1 demosmas]# ./4-Linux-LVM-create.sh
....
Terminate
[root@rhel1 demosmas]# echo $?
0

````
Verfiy file system on LVM device
````
[root@rhel1 demosmas]# df -h /data
Filesystem               Size  Used Avail Use% Mounted on
/dev/mapper/vgdata-lv01  8.8G   37M  8.3G   1% /data

[root@rhel1 demosmas]# vgdisplay vgdata -v |grep "PV Name"
  PV Name               /dev/mapper/3600a0980774f6a374e24515074354f4f
````

Create Simple IO activity for your test and crash on cluster to check SM-BC behavior 
````
[root@rhel1 demosmas]# ./simpleio.sh
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

NetApp Documentation is available here:
--------------------------------------------
- Doc: https://docs.netapp.com/us-en/ontap/snapmirror-active-sync/index.html

