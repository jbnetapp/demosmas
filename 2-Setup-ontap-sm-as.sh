#!/bin/bash
#
set -x
VERSION=1.0
DIRNAME=`dirname $0`
CONFIG_FILE=${DIRNAME}/Setup.conf
FUNCTIONS_FILE=${DIRNAME}/functions.sh

if [ ! -f $CONFIG_FILE ] ; then
	echo "ERROR: Unable to read $CONFIG_FILE"
	exit 1
fi

. $CONFIG_FILE
. $FUNCTIONS_FILE

# Main
check_var 
check_linux_bin
check_mediator

echo Init SSH session host 
check_ssh_keyhost cluster1
check_ssh_keyhost cluster2


sshpass -p $PASSWD ssh -l admin cluster1 version 
sshpass -p $PASSWD ssh -l admin cluster2 version 

# Gets Free Data Aggregate
echo Check for data Aggregate on each clusters 
AGGR_DATA_CL1=`sshpass -p $PASSWD ssh -l admin cluster1 aggr show -root false |grep online |sort -k2 -u | tail -1 |awk '{print $1}'|tr -d '\r'`
[ -z "$AGGR_DATA_CL1" ] && clean_and_exit "ERROR: No Data Aggregate found in cluster1"


AGGR_DATA_CL2=`sshpass -p $PASSWD ssh -l admin cluster2 aggr show -root false |grep online |sort -k2 -u | tail -1 |awk '{print $1}'|tr -d '\r'`
[ -z "$AGGR_DATA_CL2" ] && clean_and_exit "ERROR: No Data Aggregate found in cluster2"

echo Create InteCluser LIF cluster1
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver cluster1 -lif intercluster1 -address $IP_I1 -netmask-length $LMASK -home-node cluster1-01 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver cluster1 -lif intercluster2 -address $IP_I3 -netmask-length $LMASK -home-node cluster1-02 -service-policy default-intercluster -home-port e0g -status-admin up

echo Create InteCluser LIF cluster2
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver cluster2 -lif intercluster1 -address $IP_I2 -netmask-length $LMASK -home-node cluster2-01 -service-policy default-intercluster -home-port e0g -status-admin up
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver cluster2 -lif intercluster2 -address $IP_I4 -netmask-length $LMASK -home-node cluster2-02 -service-policy default-intercluster -home-port e0g -status-admin up

echo Check Network link between clusters
sshpass -p $PASSWD ssh -l admin cluster1 network ping -node cluster1-01 -destination $IP_I2
sshpass -p $PASSWD ssh -l admin cluster1 network ping -node cluster1-02 -destination $IP_I4
sshpass -p $PASSWD ssh -l admin cluster2 network ping -node cluster2-01 -destination $IP_I1
sshpass -p $PASSWD ssh -l admin cluster2 network ping -node cluster2-01 -destination $IP_I3

echo Setup Cluster Peer
cps=`sshpass -p $PASSWD ssh -l admin cluster1 cluster peer show |grep cluster2 | awk '{print $4}'|tr -d '\r'`
if [ "$cps" == "ok" ] ; then
	cps=`sshpass -p $PASSWD ssh -l admin cluster2 cluster peer show |grep cluster1 | awk '{print $4}'|tr -d '\r'`
	[ "$cps" != "ok" ] && clean_and_exit "Error Cluster Peer is in bad status please correct it and try again" 255
else
	time=0 ; while [ "$cps" != "pending" ] && [ $time -lt $TIMEOUT ]; do
		[ "$cps" != "pending" ] && (sleep 1; echo $PASSWD ; sleep 2; echo $PASSWD )| sshpass -p $PASSWD ssh -l admin cluster1 cluster peer create -address-family ipv4 -peer-addrs $IP_I2
		sleep 5; time=$(($time + 5))
		cps=`sshpass -p $PASSWD ssh -l admin cluster1 cluster peer show |grep cluster2 | awk '{print $4}'|tr -d '\r'`
		echo "Cluster peer status is [$cps] [$time]"
	done
	[ "$cps" != "pending" ] && clean_and_exit "Error Unable to create cluster peer from cluster1" 255
	time=0 ; while [ "$cps" != "ok" ] && [ $time -lt $TIMEOUT ]; do
		[ "$cps" != "ok" ] && (sleep 1; echo $PASSWD ; sleep 2; echo $PASSWD )| sshpass -p $PASSWD ssh -l admin cluster2 cluster peer create -address-family ipv4 -peer-addrs $IP_I1 
		sleep 5; time=$(($time + 5))
		cps=`sshpass -p $PASSWD ssh -l admin cluster2 cluster peer show |grep cluster1 | awk '{print $4}'|tr -d '\r'`
		echo "Cluster peer status is [$cps] [$time]"
	done
	[ "$cps" != "ok" ] && clean_and_exit "Error Unable to create cluster peer from cluster2" 255
fi
sshpass -p $PASSWD ssh -l admin cluster1 cluster peer show 
sshpass -p $PASSWD ssh -l admin cluster2 cluster peer show 

echo Create $SVM_NAME_P cluster1
sshpass -p $PASSWD ssh -l admin cluster1 vserver create -vserver $SVM_NAME_P -subtype default 
sshpass -p $PASSWD ssh -l admin cluster1 vserver iscsi create -vserver $SVM_NAME_P -target-alias $SVM_NAME_P -status-admin up
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_admin -service-policy default-data-files -address $IP_SVM_P1 -netmask-length $LMASK -home-node cluster1-01 -home-port e0g  -service-policy default-data-files
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_data1 -service-policy default-data-iscsi -address $IP_SVM_P2 -netmask-length $LMASK -home-node cluster1-01 -home-port e0g -firewall-policy data -data-protocol iscsi
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_data2 -service-policy default-data-iscsi -address $IP_SVM_P3 -netmask-length $LMASK -home-node cluster1-02 -home-port e0g -firewall-policy data -data-protocol iscsi
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_data3 -service-policy default-data-iscsi -address $IP_SVM_P4 -netmask-length $LMASK -home-node cluster1-01 -home-port e0g -firewall-policy data -data-protocol iscsi
sshpass -p $PASSWD ssh -l admin cluster1 network interface create -vserver $SVM_NAME_P -lif ${SVM_NAME_P}_data4 -service-policy default-data-iscsi -address $IP_SVM_P5 -netmask-length $LMASK -home-node cluster1-02 -home-port e0g -firewall-policy data -data-protocol iscsi

echo Create $SVM_NAME_S cluster2
sshpass -p $PASSWD ssh -l admin cluster2 vserver create -vserver $SVM_NAME_S -subtype default 
sshpass -p $PASSWD ssh -l admin cluster2 vserver iscsi create -vserver $SVM_NAME_S -target-alias $SVM_NAME_S -status-admin up
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_admin -service-policy default-data-files -address $IP_SVM_S1 -netmask-length $LMASK -home-node cluster2-01 -home-port e0g -service-policy default-data-files
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_data1 -service-policy default-data-iscsi -address $IP_SVM_S2 -netmask-length $LMASK -home-node cluster2-01 -home-port e0g -firewall-policy data -data-protocol iscsi
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_data2 -service-policy default-data-iscsi -address $IP_SVM_S3 -netmask-length $LMASK -home-node cluster2-02 -home-port e0g -firewall-policy data -data-protocol iscsi
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_data3 -service-policy default-data-iscsi -address $IP_SVM_S4 -netmask-length $LMASK -home-node cluster2-01 -home-port e0g -firewall-policy data -data-protocol iscsi
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_NAME_S -lif ${SVM_NAME_S}_data4 -service-policy default-data-iscsi -address $IP_SVM_S5 -netmask-length $LMASK -home-node cluster2-02 -home-port e0g -firewall-policy data -data-protocol iscsi



echo Create svm relation 
sps=`sshpass -p $PASSWD ssh -l admin cluster2 vserver peer show |grep $SVM_NAME_S |awk '{ print $3}'|tr -d '\r'`
if [ "$sps" != "peered" ]; then
	sshpass -p $PASSWD ssh -l admin cluster1 vserver peer create -vserver $SVM_NAME_P -peer-vserver $SVM_NAME_S -applications snapmirror -peer-cluster cluster2
	time=0 ; while [ "$sps" != "pending" ] && [ $time -lt $TIMEOUT ]; do
		sleep 1; time=$(($time + 1))
		sps=`sshpass -p $PASSWD ssh -l admin cluster2 vserver peer show |grep $SVM_NAME_S |awk '{ print $3}'|tr -d '\r'`
		echo "vserver peer status [$sps] [$time]"
	done
	[ "$sps" != "pending" ] && clean_and_exit "Error Unable to create vserver peer from cluster1 $SVM_NAME_P" 255
	sshpass -p $PASSWD ssh -l admin cluster2 vserver peer accept -vserver $SVM_NAME_S -peer-vserver $SVM_NAME_P
	time=0 ; while [ "$sps" != "peered" ] && [ $time -lt $TIMEOUT ]; do
		sleep 1; time=$(($time + 1))
		sps=`sshpass -p $PASSWD ssh -l admin cluster2 vserver peer show |grep $SVM_NAME_S |awk '{ print $3}'|tr -d '\r'`
		echo "vserver peer status [$sps] [$time]"
	done
	[ "$sps" != "peered" ] && clean_and_exit "Error Unable to accept vserver peer from cluster2 $SVM_NAME_S" 255
fi

sshpass -p $PASSWD ssh -l admin cluster1 volume create -volume $VOL_NAME_P -vserver $SVM_NAME_P -aggregate $AGGR_DATA_CL1 -size $SIZE -autosize-mode grow -snapshot-policy none -space-guarantee none -state online
sshpass -p $PASSWD ssh -l admin cluster1 volume snapshot autodelete modify -vserver $SVM_NAME_P -volume $VOL_NAME_P -enabled true

sshpass -p $PASSWD ssh -l admin cluster2 volume create -volume $VOL_NAME_S -vserver $SVM_NAME_S -aggregate $AGGR_DATA_CL2 -size $SIZE -autosize-mode grow -snapshot-policy none -space-guarantee none -type DP -state online

U_SIZE=`echo $SIZE|sed -e s/[0-9]//g`
N_SIZE=`echo $SIZE|sed -e s/[a-zA-Z]//g`
LUN_SIZE=$(($N_SIZE / 3 * 2 ))${U_SIZE}
sshpass -p $PASSWD ssh -l admin cluster1 lun create -vserver $SVM_NAME_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -size $LUN_SIZE -ostype Linux -space-reserve disabled

echo Add certificate on cluster1 
crt=`sshpass -p $PASSWD ssh -l admin cluster1 security certificate show -cert-name ONTAPMediatorCA -fields serial |grep ONTAPMediatorCA |tr -d '\r'`
time=0 ; while [ -z "$crt" ] && [ $time -lt $TIMEOUT ]; do
	sleep 5; time=$(($time + 5))
	[ -z "$crt" ] && (sleep 1; cat $CRT_FILE; sleep 2; echo "" ) | sshpass -p $PASSWD ssh -l admin cluster1 security certificate install -type server-ca -vserver cluster1 -cert-name ONTAPMediatorCA
	crt=`sshpass -p $PASSWD ssh -l admin cluster1 security certificate show -cert-name ONTAPMediatorCA -fields serial |grep ONTAPMediatorCA |tr -d '\r'`
done
crt=`sshpass -p $PASSWD ssh -l admin cluster1 security certificate show -cert-name ONTAPMediatorCA -fields serial |grep ONTAPMediatorCA |tr -d '\r'`
[ -z "$crt" ] && clean_and_exit "ERROR: Failed to install certificate on cluster1" 255

echo Add certificate on cluster2 
crt=`sshpass -p $PASSWD ssh -l admin cluster2 security certificate show -cert-name ONTAPMediatorCA -fields serial |grep ONTAPMediatorCA |tr -d '\r'`
time=0 ; while [ -z "$crt" ] && [ $time -lt $TIMEOUT ]; do
	sleep 5; time=$(($time + 5))
	[ -z "$crt" ] && (sleep 1; cat $CRT_FILE; sleep 2; echo "" ) | sshpass -p $PASSWD ssh -l admin cluster2 security certificate install -type server-ca -vserver cluster2 -cert-name ONTAPMediatorCA
	crt=`sshpass -p $PASSWD ssh -l admin cluster2 security certificate show -cert-name ONTAPMediatorCA -fields serial |grep ONTAPMediatorCA |tr -d '\r'`
done
crt=`sshpass -p $PASSWD ssh -l admin cluster2 security certificate show -cert-name ONTAPMediatorCA -fields serial |grep ONTAPMediatorCA |tr -d '\r'`
[ -z "$crt" ] && clean_and_exit "ERROR: Failed to install certificate on cluster2" 255

echo Add the Mediator on cluster1
ms=`sshpass -p $PASSWD ssh -l admin cluster1 snapmirror mediator show -mediator-address $MEDIATOR_IP -peer-cluster cluster2 |grep $MEDIATOR_IP |awk '{print $3}' | tr -d '\r'`
if [ "$ms" != "connected" ] ; then
	time=0 ; while [ "$ms" != "connected" ] && [ $time -lt $TIMEOUT ]; do
		[ "$ms" != "connected" ] && (sleep 1; echo $MEDIATOR_PASSWD; sleep 2; echo $MEDIATOR_PASSWD)| sshpass -p $PASSWD ssh -l admin cluster1 snapmirror mediator add -mediator-address $MEDIATOR_IP -peer-cluster cluster2 -username mediatoradmin -port-number $MEDIATOR_PORT
		sleep 1; time=$(($time + 1))
		ms=`sshpass -p $PASSWD ssh -l admin cluster1 snapmirror mediator show -mediator-address $MEDIATOR_IP -peer-cluster cluster2 |grep $MEDIATOR_IP |awk '{print $3}' | tr -d '\r'`
		echo "Mediator status [$ms] [$time]"
	done
	[ "$ms" != "connected" ] && clean_and_exit "Error Failed to create mediator on clsuter1" 255
fi

echo Add the Mediator on cluster2 
ms=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror mediator show -mediator-address $MEDIATOR_IP -peer-cluster cluster1 |grep $MEDIATOR_IP |awk '{print $3}' | tr -d '\r'`
if [ "$ms" != "connected" ] ; then
	time=0 ; while [ "$ms" != "connected" ] && [ $time -lt $TIMEOUT ]; do
		[ "$ms" != "connected" ] && (sleep 1; echo $MEDIATOR_PASSWD; sleep 2; echo $MEDIATOR_PASSWD)| sshpass -p $PASSWD ssh -l admin cluster2 snapmirror mediator add -mediator-address $MEDIATOR_IP -peer-cluster cluster1 -username mediatoradmin -port-number $MEDIATOR_PORT
		sleep 1; time=$(($time + 1))
		ms=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror mediator show -mediator-address $MEDIATOR_IP -peer-cluster cluster1 |grep $MEDIATOR_IP |awk '{print $3}' | tr -d '\r'`
		echo "Mediator status [$ms] [$time]"
	done
	[ "$ms" != "connected" ] && clean_and_exit "Error Failed to create mediator on clsuter1" 255
fi

echo Create Consistency group and consistency relation 
sms=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field status |grep $SMBC_DST_PATH |awk '{print $3}'| tr -d '\r'`
echo Snapmirror Status is [$sms]
if [ "$sms" != "InSync" ]; then 
	sshpass -p $PASSWD ssh -l admin cluster2 snapmirror create -source-path $SMBC_SRC_PATH -destination-path $SMBC_DST_PATH -cg-item-mappings $VOL_NAME_P:@$VOL_NAME_S -policy AutomatedFailOver 
	sms=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field state |grep $SMBC_DST_PATH |awk '{print $3}'| tr -d '\r'`
	echo Snapmirror State is [$sms]
	[ "$sms" != "Uninitialized" ] && clean_and_exit "ERRROR: Unable to create snamirror smbc from clsuter2" 255

	sshpass -p $PASSWD ssh -l admin cluster2 snapmirror initialize -destination-path $SMBC_DST_PATH
	sms=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field status |grep $SMBC_DST_PATH |awk '{print $3}'| tr -d '\r'`
	while [ "$sms" != "InSync" ]; do
		sms=`sshpass -p $PASSWD ssh -l admin cluster2 snapmirror show -destination-path $SMBC_DST_PATH -field status |grep $SMBC_DST_PATH |awk '{print $3}'| tr -d '\r'`
		echo Please waite Snapmirror State is [$sms] ; date
		sleep 1
	done
fi

echo Create iGroup Linux
INITIATOR_NAME=`cat $LINUX_ISCSI_INITIATOR_FILE | awk -F '=' '{print $2}'`
sshpass -p $PASSWD ssh -l admin cluster1 igroup create -igroup centos01 -protocol mixed -ostype linux -initiator $INITIATOR_NAME -vserver $SVM_NAME_P
sshpass -p $PASSWD ssh -l admin cluster2 igroup create -igroup centos01 -protocol mixed -ostype linux -initiator $INITIATOR_NAME -vserver $SVM_NAME_S

sshpass -p $PASSWD ssh -l admin cluster1 lun map -vserver $SVM_NAME_P -path /vol/${VOL_NAME_P}/${LUN_NAME} -igroup centos01
sshpass -p $PASSWD ssh -l admin cluster2 lun map -vserver $SVM_NAME_S -path /vol/${VOL_NAME_S}/${LUN_NAME} -igroup centos01

clean_and_exit "Terminate" 0
