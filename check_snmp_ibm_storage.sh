#!/bin/bash  
#
# this plugin check hardware storage of a IBM Server
#
# Date: 2011-09-26
# Author: Ivan Bergantin - ITA
#

# get arguments

while getopts 'H:C:h' OPT; do
  case $OPT in
    H)  hostibm=$OPTARG;;
    C)  snmpcommunity=$OPTARG;;
    h)  hlp="yes";;
    *)  unknown="yes";;
  esac
done

# usage
HELP="
    Check hardware storage on IBM server with SNMP (GPL licence) - Version 1.0

    usage: $0 [ -H value -C value -h ]

    syntax:

            -H --> Host - Name or IP Address
            -C --> Community SNMP (default public)
            -h --> Print This Help Screen

"

# se è stato chiesto l'help col parametro -h o se non sono stati passati parametri ($# uguale a 0) stampo l'help
if [ "$hlp" = "yes" -o $# -lt 1 ]; then
	echo "$HELP"
	exit 0
fi

if [ -z "$snmpcommunity" ]; then
        snmpcommunity="public"
fi

##################################################################################
### funciotn with operational status selection
##################################################################################

function statuscase {
	case $1 in
        	1)
                	exitstatus="unknown"
                        mystatus=1
                ;;
        	2)
                	exitstatus="other"
                        mystatus=1
                ;;
                3)
                        exitstatus="ok"
                ;;
                4)
                        exitstatus="warning"
                        mystatus=1
                ;;
                5)
                        exitstatus="failure"
                        mystatus=2
                ;;
                *)
                        exitstatus="not detected"
                        mystatus=0
                ;;
	esac
}

##################################################################################
### Main 
##################################################################################

if [ -n "$hostibm" ]; then
	
	pluginoutput=""
	mystatus="0"

	result=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.100.5.0`
	if [ -n "$result" -a "$result" != "End of MIB" ]; then
		mymodel="adaptec"
	fi
	result=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.9.1.0`
	if [ -n "$result" -a "$result" != "End of MIB" ]; then
		mymodel="lsi"
	fi
	result=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.1.1`
	if [ -n "$result" -a "$result" != "End of MIB" ]; then
		mymodel="lsi"
	fi

##################################################################################
####### Check drive LSI
##################################################################################

	if [ "$mymodel" = "lsi" ]; then

		######
		### Modello LSI 1
		######

		### Controller
		myctrnumber=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.1.1.1 | awk -F'INTEGER: ' '{printf $2}'`
                i=1
                for i in `seq 1 $myctrnumber`;
                do
			oid=$(( $i - 1 ))
			myctrmodel=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.1.1.3.1.12.$oid | awk -F'STRING: ' '{printf $2}'`
			myctrserial=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.1.1.3.1.13.$oid | awk -F'STRING: ' '{printf $2}'`
			myctrdriver=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.1.1.3.1.15.$oid | awk -F'STRING: ' '{printf $2}'`
			pluginoutput="$pluginoutput Controller LSI $i [Model $myctrmodel serial $myctrserial driver $myctrdriver]\n"
			mydiskcount=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.1.1.3.1.23.$oid | awk -F'INTEGER: ' '{printf $2}'`
			mydiskpredfailure=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.1.1.3.1.24.$oid | awk -F'INTEGER: ' '{printf $2}'`
			mydiskfailure=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.1.1.3.1.25.$oid | awk -F'INTEGER: ' '{printf $2}'`
			pluginoutput="$pluginoutput Physical disk devices present in this adapter: $mydiskcount\n"
			pluginoutput="$pluginoutput Number of disk devices in this adapter that are predictive failed: $mydiskpredfailure\n"
			pluginoutput="$pluginoutput Number of disk devices in this adapter that are failed: $mydiskfailure\n\n"
			if (( $mydiskpredfailure > 0 )); then
				mystatus="1" 
			fi
			if (( $mydiskfailure > 0 )); then
				mystatus="2" 
			fi
		done

		### Disk
		mydevicenumber=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.2.1.1 | awk -F'INTEGER: ' '{printf $2}'`
                i=1
                for i in `seq 1 $mydevicenumber`;
                do
			oid=$(( $i - 1 ))
			mydevicevendor=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.2.1.2.1.24.$oid | awk -F'STRING: ' '{printf $2}'`
			mydevicemodel=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.2.1.2.1.25.$oid | awk -F'STRING: ' '{printf $2}'`
			mydevicecapacity=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.2.1.2.1.15.$oid | awk -F'INTEGER: ' '{printf $2}'`
			mydeviceprogress=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.2.1.2.1.21.$oid | awk -F'STRING: ' '{printf $2}'`
			mydevicestatus=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.5.1.4.2.1.2.1.10.$oid | awk -F'INTEGER: ' '{printf $2}'`
	                case $mydevicestatus in
	                        0) mydevicestatus="unconfigured-good"
	                        mystatus="0" ;;
	                        1) mydevicestatus="unconfigured-bad"
	                        mystatus="1" ;;
	                        2) mydevicestatus="hot-spare" ;;
	                        16) mydevicestatus="offline" 
	                        mystatus="1" ;;
	                        17) mydevicestatus="failed" 
	                        mystatus="2" ;;
	                        20) mydevicestatus="rebuild"
	                        mystatus="1" ;;
	                        24) mydevicestatus="online" ;;
	                        32) mydevicestatus="copyback" ;;
	                        64) mydevicestatus="system" ;;
	                esac

			pluginoutput="$pluginoutput Drive $i is $mydevicestatus [$mydevicevendor model $mydevicemodel with capacity $mydevicecapacity] - If active task: $mydeviceprogress progress\n"
		done

		######
		### Modello LSI 2
		######

                ### Controller
                myctrnumber=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.1.1 | awk -F'INTEGER: ' '{printf $2}'`
                i=1
                for i in `seq 1 $myctrnumber`;
                do
                        oid=$(( $i - 1 ))
                        myctrmodel=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.1.3.1.12.$oid | awk -F'STRING: ' '{printf $2}'`
                        myctrserial=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.1.3.1.13.$oid | awk -F'STRING: ' '{printf $2}'`
                        myctrdriver=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.1.3.1.15.$oid | awk -F'STRING: ' '{printf $2}'`
                        pluginoutput="$pluginoutput Controller LSI $i [Model $myctrmodel serial $myctrserial driver $myctrdriver]\n"
                        mydiskcount=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.1.2.1.22.$oid | awk -F'INTEGER: ' '{printf $2}'`
                        mydiskpredfailure=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.1.2.1.23.$oid | awk -F'INTEGER: ' '{printf $2}'`
                        mydiskfailure=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.1.2.1.24.$oid | awk -F'INTEGER: ' '{printf $2}'`
                        pluginoutput="$pluginoutput Physical disk devices present in this adapter: $mydiskcount\n"
                        pluginoutput="$pluginoutput Number of disk devices in this adapter that are predictive failed: $mydiskpredfailure\n"
                        pluginoutput="$pluginoutput Number of disk devices in this adapter that are failed: $mydiskfailure\n\n"
                        if (( $mydiskpredfailure > 0 )); then
                                mystatus="1"
                        fi
                        if (( $mydiskfailure > 0 )); then
                                mystatus="2"
                        fi
                done

                ### Disk
                mydevicenumber=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.2.1.1 | awk -F'INTEGER: ' '{printf $2}'`
                i=1
                for i in `seq 1 $mydevicenumber`;
                do
                        oid=$(( $i - 1 ))
                        mydevicevendor=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.2.1.2.1.24.$oid | awk -F'STRING: ' '{printf $2}'`
                        mydevicemodel=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.2.1.2.1.25.$oid | awk -F'STRING: ' '{printf $2}'`
                        mydevicecapacity=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.2.1.2.1.15.$oid | awk -F'INTEGER: ' '{printf $2}'`
                        mydeviceprogress=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.2.1.2.1.21.$oid | awk -F'STRING: ' '{printf $2}'`
                        mydevicestatus=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.3582.4.1.4.2.1.2.1.10.$oid | awk -F'INTEGER: ' '{printf $2}'`
                        case $mydevicestatus in
                                0) mydevicestatus="unconfigured-good"
                                mystatus="0" ;;
                                1) mydevicestatus="unconfigured-bad"
                                mystatus="1" ;;
                                2) mydevicestatus="hot-spare" ;;
                                16) mydevicestatus="offline"
                                mystatus="1" ;;
                                17) mydevicestatus="failed"
                                mystatus="2" ;;
                                20) mydevicestatus="rebuild"
                                mystatus="1" ;;
                                24) mydevicestatus="online" ;;
                                32) mydevicestatus="copyback" ;;
                                64) mydevicestatus="system" ;;
                        esac

                        pluginoutput="$pluginoutput Drive $i is $mydevicestatus [$mydevicevendor model $mydevicemodel with capacity $mydevicecapacity] - If active task: $mydeviceprogress progress\n"
                done

##################################################################################
####### Check drive ADAPTEC
##################################################################################

	elif [ "$mymodel" = "adaptec" ]; then
		myctrvendor=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.201.1.1.3 | awk -F'STRING: ' '{printf $2}'`
		myctrmodel=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.201.1.1.4 | awk -F'STRING: ' '{printf $2}'`
		myctrrevision=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.201.1.1.5 | awk -F'STRING: ' '{printf $2}'`
		myctrserial=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.201.1.1.6 | awk -F'STRING: ' '{printf $2}'`
		myctrmemory=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.201.1.1.12 | awk -F'INTEGER: ' '{printf $2}'`
		myctrbattstatus=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.201.1.1.14 | awk -F'INTEGER: ' '{printf $2}'`
	        case $myctrbattstatus in
	                1) myctrbattstatus="unknown" 
			mystatus="1" ;;
	                2) myctrbattstatus="other" 
			mystatus="1" ;;
	                3) myctrbattstatus="notApplicable" ;;
	                4) myctrbattstatus="notInstalled" ;;
	                5) myctrbattstatus="ok" ;;
	                6) myctrbattstatus="failed" 
			mystatus="2" ;;
	                7) myctrbattstatus="charging" 
			mystatus="1" ;;
	                8) myctrbattstatus="discharging" 
			mystatus="1" ;;
	                9) myctrbattstatus="inMaintenanceMode" 
			mystatus="1" ;;
	                10) myctrbattstatus="chargingDisabled" 
			mystatus="1" ;;
	        esac
		myctrstatus=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.201.1.1.15 | awk -F'INTEGER: ' '{printf $2}'`
		statuscase $myctrstatus
		myctrstatus=`echo $exitstatus`
		myctroverallstatus=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.201.1.1.16 | awk -F'INTEGER: ' '{printf $2}'`
		statuscase $myctroverallstatus
		myctrstatus=`echo $exitstatus`

		hostopstatus=`echo $result | awk -F'INTEGER: ' '{printf $2}'`
		statuscase $hostopstatus

		pluginoutput="$pluginoutput Storage Overall Status is $exitstatus [$myctrvendor $myctrmodel Ver. $myctrrevision - Serial $myctrserial]\nMemory: $myctrmemory MB on battery [Status $myctrbattstatus]\nStatus controller is $myctrstatus [controller overall status is $myctrstatus]\n"

		###disk
                numdevice=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.400.1.1.11 | wc -l`
                i=1
                for i in `seq 1 $numdevice`;
                do
                        mydevicetypegroup=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.400.1.1.5.$i | awk -F'INTEGER: ' '{printf $2}'`
                        if [ "$mydevicetypegroup" =  "2" ]; then
				mydevicevendor=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.400.1.1.6.$i | awk -F'STRING: ' '{printf $2}'`
	                        mydevicemodel=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.400.1.1.7.$i | awk -F'STRING: ' '{printf $2}'`
	                        mydevicerev=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.400.1.1.8.$i | awk -F'STRING: ' '{printf $2}'`
	                        mydeviceserial=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.400.1.1.9.$i | awk -F'STRING: ' '{printf $2}'`
	                        mydevicelocation=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.400.1.1.12.$i | awk -F'STRING: ' '{printf $2}'`
	                        mydevicecapacity=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.410.1.1.3.$i | awk -F'INTEGER: ' '{printf $2}'`
	                        mydevicesmart=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.410.1.1.8.$i | awk -F'INTEGER: ' '{printf $2}'`
			        case $mydevicesmart in
			                1) mydevicesmart="unknown" ;;
			                2) mydevicesmart="notSupported" ;;
			                3) mydevicesmart="notEnabled" ;;
			                4) mydevicesmart="ok" ;;
			                5) mydevicesmart="errorPredicted" 
					mystatus="2" ;;
			        esac
	                        mydevicestatus=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.400.1.1.11.$i | awk -F'INTEGER: ' '{printf $2}'`
	                        statuscase $mydevicestatus
	
	                        pluginoutput="$pluginoutput Drive $i is $exitstatus - $mydevicelocation [Vendor $mydevicevendor Model $mydevicemodel FW $mydevicerev - Serial $mydeviceserial] Capacity $mydevicecapacity - Smart value is $mydevicesmart \n"
			fi
                done

##################################################################################
####### Check array ADAPTEC
##################################################################################

                numdevice=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.1000.1.1.1 | wc -l`
                i=1
                for i in `seq 1 $numdevice`;
                do
                        myarraycapacity=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.1000.1.1.3.$i | awk -F'INTEGER: ' '{printf $2}'`
			myarraytype=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.1000.1.1.4.$i | awk -F'INTEGER: ' '{printf $2}'`
		        case $myarraytype in
		                1) myarraytype="unknown" ;;
		                2) myarraytype="other" ;;
		                3) myarraytype="raid0" ;;
		                4) myarraytype="raid1" ;;
		                5) myarraytype="raid2" ;;
		                6) myarraytype="raid3" ;;
		                7) myarraytype="raid4" ;;
		                8) myarraytype="raid5" ;;
		                9) myarraytype="raid6" ;;
		                10) myarraytype="raid10" ;;
		                11) myarraytype="raid50" ;;
		                12) myarraytype="volume" ;;
		                13) myarraytype="volume-of-raid0" ;;
		                14) myarraytype="volume-of-raid1" ;;
		                15) myarraytype="volume-of-raid5" ;;
		                16) myarraytype="raid1e" ;;
		                17) myarraytype="raid5ee" ;;
		                18) myarraytype="raid-volume" ;;
		                19) myarraytype="raid60" ;;
		        esac
			myarraytaskstatus=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.1000.1.1.6.$i | awk -F'INTEGER: ' '{printf $2}'`
		        case $myarraytaskstatus in
		                1) myarraytaskstatus="unknown" ;;
		                2) myarraytaskstatus="other" ;;
		                3) myarraytaskstatus="noTaskActive" ;;
		                4) myarraytaskstatus="reconstruct"
				mystatus="1" ;;
		                5) myarraytaskstatus="zeroInitialize" ;;
		                6) myarraytaskstatus="verify"
				mystatus="1" ;;
		                7) myarraytaskstatus="verifyWithFix"
				mystatus="1" ;;
		                8) myarraytaskstatus="modification"
				mystatus="1" ;;
		                9) myarraytaskstatus="copyback" ;;
		                10) myarraytaskstatus="compaction" ;;
		                11) myarraytaskstatus="expansion" ;;
		                12) myarraytaskstatus="snapshotBackup" ;;
		        esac
			myarraytaskcompletation=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.1000.1.1.7.$i | awk -F'INTEGER: ' '{printf $2}'`
			myarraytaskpriority=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.1000.1.1.8.$i | awk -F'INTEGER: ' '{printf $2}'`
		        case $myarraytaskpriority in
		                1) myarraytaskpriority="unknown" ;;
		                2) myarraytaskpriority="other" ;;
		                3) myarraytaskpriority="notSupported" ;;
		                4) myarraytaskpriority="notApplicable" ;;
		                5) myarraytaskpriority="none" ;;
		                6) myarraytaskpriority="low" ;;
		                7) myarraytaskpriority="medium" ;;
		                8) myarraytaskpriority="high" ;;
		        esac
			myarraystate=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.1000.1.1.12.$i | awk -F'INTEGER: ' '{printf $2}'`
		        case $myarraystate in
		                1) myarraystate="unknown" ;;
		                2) myarraystate="other" ;;
		                3) myarraystate="optimal" ;;
		                4) myarraystate="quickInited" ;;
		                5) myarraystate="impacted"
				mystatus="1" ;;
		                6) myarraystate="degraded"
				mystatus="2" ;;
		                7) myarraystate="failed"
				mystatus="2" ;;
		                8) myarraystate="compacted"
				mystatus="1" ;;
		        esac
			myarraystatus=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.1000.1.1.11.$i | awk -F'INTEGER: ' '{printf $2}'`
			statuscase $myarraystatus

                        pluginoutput="$pluginoutput Array $i is $exitstatus [State $myarraystate] - $myarraytype with capacity $myarraycapacity - Task Status: $myarraytaskstatus at $myarraytaskcompletation % [Priority task is $myarraytaskpriority]\n"

			mySpare=`snmpwalk -v 1 -c $snmpcommunity -On $hostibm .1.3.6.1.4.1.795.14.1.1002.1.1.1 | wc -l`
			if (( $mySpare > 0 )); then
				pluginoutput="$pluginoutput Spare disk found : $mySpare \n"
			fi

                done

	else
		echo -ne "Critical - Check your device. Maybe isn't IBM.\n"
		exit 2
	fi


##################################################################################
####### END
##################################################################################

		if [ "$mystatus" =  "0" ]; then
			echo -ne "OK - "
		else
			echo -ne "CRITICAL - "
			mystatus="2"
		fi
		echo -ne "$pluginoutput"
                exit $mystatus
else
	echo -ne "SCRIPT ERROR - You must define the host. \n"
	exit 3
fi
exit  

