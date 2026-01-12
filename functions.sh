#
# Functions
#
FUNCTIONS_VERSION=1.0

clean_and_exit(){
	[ -f "$TMPFILE" ] && rm -f $TMPFILE
        echo $1 ; [ -z "$2" ] && exit 0 
	[ $2 -ne 0 ] && exit $2
}

check_ssh_keyhost(){
	cluster_name=$1
	[ -z "$cluster_name" ] && return 
	[ ! -d "$HOME/.ssh" ] && mkdir $HOME/.ssh
	SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -v cluster_name=$cluster_name '{if ( $1 == cluster_name ) print $1}'|tr -d '\r'`
	[ -z "$SSH_Name" ] &&  ssh-keyscan $cluster_name >> $HOME/.ssh/known_hosts 
}

check_linux_bin(){
	which lsof > /dev/null 2>&1 ; [ $? -ne 0 ] && clean_and_exit "Error lsof not available: Please install the pacakge"  255
	which sshpass > /dev/null 2>&1 ; [ $? -ne 0 ] && clean_and_exit "Error sshpass not available: Please install the pacakge"  255
	which multipath  > /dev/null 2>&1 ; [ $? -ne 0 ] && clean_and_exit "Error unable to run multipath" 255
	which rescan-scsi-bus.sh > /dev/null 2>&1  ; [ $? -ne 0 ] && clean_and_exit "Error: rescan-scsi-bus.sh not available" 255
}

check_netapp_linux_bin(){
	which sanlun ; [ $? -ne 0 ] && clean_and_exit "ERROR: sanlun not available" 0
}

check_mediator() {
 	mediator_port=`lsof -n |grep TCP |grep "*:$MEDIATOR_PORT" | awk '{ print $9}' | uniq`
	[ "$mediator_port" != "*:${MEDIATOR_PORT}" ] && clean_and_exit "Error Mediator not running or used a bad port number" 255
}

check_var(){
[ -z "$TMPFILE" ] && clean_and_exit "Error variable not defined: TMPFILE" 255
[ -z "$PASSWD" ] && clean_and_exit "Error variable not defined: PASSWD" 255
[ -z "$TIMEOUT" ] && clean_and_exit "Error variable not defined: TIMEOUT" 255
[ -z "$LMASK" ] && clean_and_exit "Error variable not defined: LMASK" 255
[ -z "$ROUTER" ] && clean_and_exit "Error variable not defined: ROUTER" 255
[ -z "$IP_I1" ] && clean_and_exit "Error variable not defined: IP_I1" 255
[ -z "$IP_I3" ] && clean_and_exit "Error variable not defined: IP_I3" 255
[ -z "$IP_I2" ] && clean_and_exit "Error variable not defined: IP_I2" 255
[ -z "$IP_I4" ] && clean_and_exit "Error variable not defined: IP_I4" 255
[ -z "$SVM_NAME_P" ] && clean_and_exit "Error variable not defined: SVM_NAME_P" 255
[ -z "$IP_SVM_P1" ] && clean_and_exit "Error variable not defined: IP_SVM_P1" 255
[ -z "$IP_SVM_P2" ] && clean_and_exit "Error variable not defined: IP_SVM_P2" 255
[ -z "$IP_SVM_P3" ] && clean_and_exit "Error variable not defined: IP_SVM_P3" 255
[ -z "$IP_SVM_P4" ] && clean_and_exit "Error variable not defined: IP_SVM_P4" 255
[ -z "$IP_SVM_P5" ] && clean_and_exit "Error variable not defined: IP_SVM_P5" 255
[ -z "$SVM_NAME_S" ] && clean_and_exit "Error variable not defined: SVM_NAME_S" 255
[ -z "$IP_SVM_S1" ] && clean_and_exit "Error variable not defined: IP_SVM_S1" 255
[ -z "$IP_SVM_S2" ] && clean_and_exit "Error variable not defined: IP_SVM_S2" 255
[ -z "$IP_SVM_S3" ] && clean_and_exit "Error variable not defined: IP_SVM_S3" 255
[ -z "$IP_SVM_S4" ] && clean_and_exit "Error variable not defined: IP_SVM_S4" 255
[ -z "$IP_SVM_S5" ] && clean_and_exit "Error variable not defined: IP_SVM_P5" 255
[ -z "$VOL_NAME_P" ] && clean_and_exit "Error variable not defined: VOL_NAME_P" 255
[ -z "$VOL_NAME_S" ] && clean_and_exit "Error variable not defined: VOL_NAME_S" 255
[ -z "$LUN_NAME" ] && clean_and_exit "Error variable not defined: LUN_NAME" 255
[ -z "$SIZE" ] && clean_and_exit "Error variable not defined: SIZE" 255
[ -z "$SMBC_SRC_PATH" ] && clean_and_exit "Error variable not defined: SMBC_SRC_PATH" 255
[ -z "$SMBC_DST_PATH" ] && clean_and_exit "Error variable not defined: SMBC_DST_PATH" 255
[ -z "$MEDIATOR_PORT" ] && clean_and_exit "Error variable not defined: MEDIATOR_PORT" 255
[ -z "$MEDIATOR_IP" ] && clean_and_exit "Error variable not defined: MEDIATOR_IP" 255
[ -z "$MEDIATOR_PASSWD" ] && clean_and_exit "Error variable not defined: MEDIATOR_PASSWD" 255
[ -z "$CRT_FILE" ] && clean_and_exit "Error variable not defined: CRT_FILE" 255
[ -z "$LINUX_ISCSI_INITIATOR_FILE" ] && clean_and_exit "Error variable not defined: LINUX_ISCSI_INITIATOR_FILE" 255
[ -z "$MNT_DATA" ] && clean_and_exit "Error variable not defined: MNT_DATA" 255
}
