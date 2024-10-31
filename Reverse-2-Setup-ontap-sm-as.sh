#!/bin/bash
#
set -x
VERSION=1.0
DIRNAME=`dirname $0`
CONFIG_FILE=${DIRNAME}/Setup.conf
FUNCTIONS_FILE=${DIRNAME}/functions.sh
OPT=$1

if [ ! -f $CONFIG_FILE ] ; then
        echo "ERROR: Unable to read $CONFIG_FILE"
        exit 1
fi

. $CONFIG_FILE
. $FUNCTIONS_FILE

check_var
check_linux_bin

echo Init SSH session host 
check_ssh_keyhost cluster1
check_ssh_keyhost cluster2


echo Unmap LUN
sshpass -p $PASSWD ssh -l admin cluster1 lun unmap -vserver $SVM_NAME_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -igroup centos01
sshpass -p $PASSWD ssh -l admin cluster2 lun unmap -vserver $SVM_NAME_S -path /vol/${VOL_NAME_S}/${LUN_NAME} -igroup centos01

echo Delete iGroup
sshpass -p $PASSWD ssh -l admin cluster1 igroup delete -igroup centos01 -vserver $SVM_NAME_P
igroup=`sshpass -p $PASSWD ssh -l admin cluster1 igroup show -igroup centos01 -vserver $SVM_NAME_P |grep centos01 |tr -d '\r'`
[ ! -z "$igroup" ] && clean_and_exit "Error Unable to delete igroup centos01 exit " 255

sshpass -p $PASSWD ssh -l admin cluster2 igroup delete -igroup centos01 -vserver $SVM_NAME_S
igroup=`sshpass -p $PASSWD ssh -l admin cluster2 igroup show -igroup centos01 -vserver $SVM_NAME_S |grep centos01 |tr -d '\r'`
[ ! -z "$igroup" ] && clean_and_exit "Error Unable to delete igroup centos01 exit " 255

echo Delete SnapMirror SMBC
sshpass -p $PASSWD ssh -l admin cluster2 snapmirror delete -destination-path $SMBC_DST_PATH -source-path $SMBC_SRC_PATH
smr=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -source-path $SMBC_SRC_PATH -fields status,state | grep $SMBC_DST_PATH |tr -d '\r'`
[ ! -z "$smr" ] && clean_and_exit "Error Unable to delete snapmirror relation destination-path $SMBC_DST_PATH" 255

sshpass -p $PASSWD ssh -l admin cluster1 snapmirror release -destination-path $SMBC_DST_PATH -source-path $SMBC_SRC_PATH
smr=`sshpass -p $PASSWD ssh -l admin cluster1 snapmirror list-destinations -destination-path $SMBC_DST_PATH -source-path $SMBC_SRC_PATH -fields status | grep $SMBC_DST_PATH`
[ ! -z "$smr" ] && clean_and_exit "Error Unable to delete snapmirror relation destination-path $SMBC_DST_PATH" 255


echo Delete Mediator
sshpass -p $PASSWD ssh -l admin cluster1 snapmirror mediator remove -mediator-address $MEDIATOR_IP -peer-cluster cluster2
sleep 10 
med=`sshpass -p $PASSWD ssh -l admin cluster1 snapmirror mediator show -mediator-address $MEDIATOR_IP -peer-cluster cluster2 |grep $MEDIATOR_IP |tr -d '\r'`
[ ! -z "$med" ] && clean_and_exit "Error Unable to delete mediator" 255

sshpass -p $PASSWD ssh -l admin cluster2 snapmirror mediator remove -mediator-address $MEDIATOR_IP -peer-cluster cluster1
sleep 10 
med=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror mediator show -mediator-address $MEDIATOR_IP -peer-cluster cluster1 |grep $MEDIATOR_IP |tr -d '\r'`
[ ! -z "$med" ] && clean_and_exit "Error Unable to delete mediator" 255

CERT=`sshpass -p $PASSWD ssh -l admin cluster1 security certificate show  -cert-name ONTAPMediatorCA -field serial,ca,type | grep ONTAPMediatorCA |tr -d '\r'`
CERT_VSERVER=`echo $CERT |awk '{print $1}'`
CERT_SERIAL=`echo $CERT |awk '{print $3}'`
CERT_TYPE=`echo $CERT |awk -F'"' '{print $3}'| awk '{print $1}'`
[ ! -z "$CERT_SERIAL" ] && sshpass -p $PASSWD ssh -l admin cluster1 "security certificate delete -common-name ONTAPMediatorCA -serial ${CERT_SERIAL} -type ${CERT_TYPE} -ca *"
cert=`sshpass -p $PASSWD ssh -l admin cluster1 security certificate show -common-name ONTAPMediatorCA -serial ${CERT_SERIAL} -field serial |grep ${CERT_SERIAL} |tr -d '\r'`
[ ! -z "$cert" ] && clean_and_exit "Error Unable to delete certificate $CERT_SERIAL" 255


CERT=`sshpass -p $PASSWD ssh -l admin cluster2 security certificate show  -cert-name ONTAPMediatorCA -field serial,ca,type | grep ONTAPMediatorCA |tr -d '\r'`
CERT_VSERVER=`echo $CERT |awk '{print $1}'`
CERT_SERIAL=`echo $CERT |awk '{print $3}'`
CERT_TYPE=`echo $CERT |awk -F'"' '{print $3}'| awk '{print $1}'`
[ ! -z "$CERT_SERIAL" ] && sshpass -p $PASSWD ssh -l admin cluster2 "security certificate delete -common-name ONTAPMediatorCA -serial ${CERT_SERIAL} -type ${CERT_TYPE} -ca *"
cert=`sshpass -p $PASSWD ssh -l admin cluster2 security certificate show -common-name ONTAPMediatorCA -serial ${CERT_SERIAL} -field serial |grep ${CERT_SERIAL} |tr -d '\r'`
[ ! -z "$cert" ] && clean_and_exit "Error Unable to delete certificate $CERT_SERIAL" 255




echo Delete LUN 
sshpass -p $PASSWD ssh -l admin cluster1 lun offline -path /vol/$VOL_NAME_P/$LUN_NAME -vserver $SVM_NAME_P
sshpass -p $PASSWD ssh -l admin cluster1 lun delete -path /vol/$VOL_NAME_P/$LUN_NAME -vserver $SVM_NAME_P
lun=`sshpass -p $PASSWD ssh -l admin cluster1 lun show -path /vol/$VOL_NAME_P/$LUN_NAME -vserver $SVM_NAME_P -field path | grep $LUN_NAME |tr -d '\r'`
[ ! -z "$lun" ] && clean_and_exit "Error Unable to delete LUN $/vol/$VOL_NAME_P/$LUN_NAME" 255

sshpass -p $PASSWD ssh -l admin cluster1 volume offline -volume $VOL_NAME_P -vserver $SVM_NAME_P
sshpass -p $PASSWD ssh -l admin cluster1 volume delete -volume $VOL_NAME_P -vserver $SVM_NAME_P
vol=`sshpass -p $PASSWD ssh -l admin cluster1 volume show -volume $VOL_NAME_P -vserver $SVM_NAME_P -field volume |grep $VOL_NAME_P |tr -d '\r'`
[ ! -z "$vol" ] && clean_and_exit "Error Unable to delete volume $VOL_NAME_P" 255

sshpass -p $PASSWD ssh -l admin cluster2 volume offline -volume $VOL_NAME_S -vserver $SVM_NAME_S
sshpass -p $PASSWD ssh -l admin cluster2 volume delete -volume $VOL_NAME_S -vserver $SVM_NAME_S
vol=`sshpass -p $PASSWD ssh -l admin cluster2 volume show -volume $VOL_NAME_S -vserver $SVM_NAME_S -field volume |grep $VOL_NAME_S |tr -d '\r'`
[ ! -z "$vol" ] && clean_and_exit "Error Unable to delete volume $VOL_NAME_S" 255

[ "$OPT" == "partial" ] && clean_and_exit "Partial reverse: Do Not delete SVM: exit" 1

echo Delete Vserver peer 
sshpass -p $PASSWD ssh -l admin cluster1 vserver peer delete -vserver $SVM_NAME_P -peer-vserver $SVM_NAME_S
sleep 8 
vpr=`sshpass -p $PASSWD ssh -l admin cluster1 vserver peer show -vserver $SVM_NAME_P -peer-vserver $SVM_NAME_S -fields peer-vserver |grep $SVM_NAME_S |tr -d '\r'`
[ ! -z "$vpr" ] && clean_and_exit "Error Unable to delete vserver peer relation" 255

echo Delete Vserver $SVM_NAME_S
sshpass -p $PASSWD ssh -l admin cluster2 network interface modify -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_* -status-admin down
sshpass -p $PASSWD ssh -l admin cluster2 network interface delete -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_* 
sshpass -p $PASSWD ssh -l admin cluster2 vserver delete -vserver $SVM_NAME_S
svm=`sshpass -p $PASSWD ssh -l admin cluster2 vserver show  -vserver $SVM_NAME_S -fields vserver |grep $SVM_NAME_S |tr -d '\r'` 
[ ! -z "$svm" ] && clean_and_exit "Error Unable to delete vserver $SVM_NAME_S" 255

echo Delete Vserver $SVM_NAME_P
sshpass -p $PASSWD ssh -l admin cluster1 network interface modify -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_* -status-admin down
sshpass -p $PASSWD ssh -l admin cluster1 network interface delete -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_* 
sshpass -p $PASSWD ssh -l admin cluster1 vserver delete -vserver $SVM_NAME_P
svm=`sshpass -p $PASSWD ssh -l admin cluster1 vserver show  -vserver $SVM_NAME_P -fields vserver |grep $SVM_NAME_P |tr -d '\r'` 
[ ! -z "$svm" ] && clean_and_exit "Error Unable to delete vserver $SVM_NAME_P" 255


echo Delete Peer Cluser
sshpass -p $PASSWD ssh -l admin cluster1 cluster peer delete -cluster cluster2 
cpr=`sshpass -p $PASSWD ssh -l admin cluster1 cluster peer show -cluster cluster2 -fields cluster  |grep cluster2 |tr -d '\r'`
[ ! -z "$cpr" ] && clean_and_exit "Error Unable to delete cluster peer from cluster1" 255

sshpass -p $PASSWD ssh -l admin cluster2 cluster peer delete -cluster cluster1
cpr=`sshpass -p $PASSWD ssh -l admin cluster2 cluster peer show -cluster cluster1 -fields cluster  |grep cluster1 |tr -d '\r'`
[ ! -z "$cpr" ] && clean_and_exit "Error Unable to delete cluster peer from cluster2" 255
sleep 5

echo Delete InteCluser LIF cluster1
sshpass -p $PASSWD ssh -l admin cluster1 version 
sshpass -p $PASSWD ssh -l admin cluster1 network interface modify -vserver cluster1 -lif intercluster1 -status-admin down
sshpass -p $PASSWD ssh -l admin cluster1 network interface modify -vserver cluster1 -lif intercluster2 -status-admin down 
sshpass -p $PASSWD ssh -l admin cluster1 network interface delete -vserver cluster1 -lif intercluster1
sshpass -p $PASSWD ssh -l admin cluster1 network interface delete -vserver cluster1 -lif intercluster2
sshpass -p $PASSWD ssh -l admin cluster1 cluster peer policy modify -is-unauthenticated-access-permitted false 
sshpass -p $PASSWD ssh -l admin cluster1 cluster peer policy modify -is-unencrypted-access-permitted false 

echo Delete InteCluser LIF cluster2
sshpass -p $PASSWD ssh -l admin cluster2 version
sshpass -p $PASSWD ssh -l admin cluster2 network interface modify -vserver cluster2 -lif intercluster1 -status-admin down 
sshpass -p $PASSWD ssh -l admin cluster2 network interface modify -vserver cluster2 -lif intercluster2 -status-admin down 
sshpass -p $PASSWD ssh -l admin cluster2 network interface delete -vserver cluster2 -lif intercluster1
sshpass -p $PASSWD ssh -l admin cluster2 network interface delete -vserver cluster2 -lif intercluster2
sshpass -p $PASSWD ssh -l admin cluster2 cluster peer policy modify -is-unauthenticated-access-permitted false 
sshpass -p $PASSWD ssh -l admin cluster2 cluster peer policy modify -is-unencrypted-access-permitted false

clean_and_exit "terminate" 0
