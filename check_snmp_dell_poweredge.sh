#!/bin/bash

# check_snmp_dell_poweredge
# Description : Check the status of DELL PowerEdge server
# Version : 1.3
# Author : Yoann LAMY
# Licence : GPLv2

# Commands
CMD_BASENAME="/bin/basename"
CMD_SNMPGET="/usr/bin/snmpget"
CMD_SNMPWALK="/usr/bin/snmpwalk"
CMD_AWK="/bin/awk"
CMD_EXPR="/usr/bin/expr"
CMD_GREP="/bin/grep"

# Script name
SCRIPTNAME=`$CMD_BASENAME $0`

# Version
VERSION="1.3"

# Plugin return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# 'arrayDiskName', STORAGEMANAGEMENT-MIB
OID_DISK_NAME=".1.3.6.1.4.1.674.10893.1.20.130.4.1.2"

# 'arrayDiskState', STORAGEMANAGEMENT-MIB
OID_DISK_STATE=".1.3.6.1.4.1.674.10893.1.20.130.4.1.4"

# 'coolingDeviceIndex', MIB-Dell-10892
OID_COOLING_INDEX=".1.3.6.1.4.1.674.10892.1.700.12.1.2.1"

# 'coolingDeviceReading', MIB-Dell-10892
OID_COOLING_READING=".1.3.6.1.4.1.674.10892.1.700.12.1.6.1"

# 'coolingDeviceLocationName', MIB-Dell-10892
OID_COOLING_NAME=".1.3.6.1.4.1.674.10892.1.700.12.1.8.1"

# 'systemStateGlobalSystemStatus', MIB-Dell-10892
OID_GLOBAL_STATUS=".1.3.6.1.4.1.674.10892.1.200.10.1.2.1"

# 'amperageProbeStatus', MIB-Dell-10892
OID_PROBE_POWER_STATUS=".1.3.6.1.4.1.674.10892.1.600.30.1.5.1"

# 'amperageProbeReading', MIB-Dell-10892
OID_PROBE_POWER_READING=".1.3.6.1.4.1.674.10892.1.600.30.1.6.1"

# 'amperageProbeLocationName', MIB-Dell-10892
OID_PROBE_POWER_NAME=".1.3.6.1.4.1.674.10892.1.600.30.1.8.1"

# 'chassisModelName', MIB-Dell-10892
OID_MODEL_NAME=".1.3.6.1.4.1.674.10892.1.300.10.1.9.1"

# 'chassisServiceTagName', MIB-Dell-10892
OID_SERVICE_TAG=".1.3.6.1.4.1.674.10892.1.300.10.1.11.1"

# 'powerUnitRedundancyStatus', MIB-DELL-10892
OID_POWER_STATUS=".1.3.6.1.4.1.674.10892.1.600.10.1.5.1.1"

# 'temperatureProbeStatus', MIB-DELL-10892
OID_TEMPERATURE_STATUS=".1.3.6.1.4.1.674.10892.1.700.20.1.6.1"

# 'temperatureProbeLocationName', MIB-DELL-10892
OID_TEMPERATURE_NAME=".1.3.6.1.4.1.674.10892.1.700.20.1.8.1"

# Default variables
DESCRIPTION="Unknown"
STATE=$STATE_UNKNOWN

# Default options
COMMUNITY="public"
HOSTNAME="127.0.0.1"
TYPE="disk"
DISK=1
WARNING=0
CRITICAL=0

# Option processing
print_usage() {
  echo "Usage: ./check_snmp_dell_poweredge -H 127.0.0.1 -C public -t disk -d 1"
  echo "  $SCRIPTNAME -H ADDRESS"
  echo "  $SCRIPTNAME -C STRING"
  echo "  $SCRIPTNAME -t STRING"
  echo "  $SCRIPTNAME -d INETEGER"
  echo "  $SCRIPTNAME -w INTEGER"
  echo "  $SCRIPTNAME -c INTEGER"
  echo "  $SCRIPTNAME -h"
  echo "  $SCRIPTNAME -V"
}

print_version() {
  echo $SCRIPTNAME version $VERSION
  echo ""
  echo "The nagios plugins come with ABSOLUTELY NO WARRANTY."
  echo "You may redistribute copies of the plugins under the terms of the GNU General Public License v2."
}

print_help() {
  print_version
  echo ""
  print_usage
  echo ""
  echo "Check the status of a DELL PowerEdge server"
  echo ""
  echo "-H ADDRESS"
  echo "   Name or IP address of host (default: 127.0.0.1)"
  echo "-C STRING"
  echo "   Community name for the host's SNMP agent (default: public)"
  echo "-t STRING"
  echo "   Different status (disk, fan, health, info, power, redundancy, temperature)"
  echo "-d INTEGER"
  echo "   Numero of disk (default: 1)"
  echo "-w INTEGER"
  echo "   Warning level for temperature in degres celsius (default: 0)"
  echo "-c INTEGER"
  echo "   Critical level for temperature in degres celsius (default: 0)"
  echo "-h"
  echo "   Print this help screen"
  echo "-V"
  echo "   Print version and license information"
  echo ""
  echo ""
  echo "This plugin uses the 'snmpget' command and the 'snmpwalk' command included with the NET-SNMP package."
  echo "This plugin support performance data output (fan, power, temperature)."
}

while getopts H:C:t:d:w:c:hV OPT
do
  case $OPT in
    H) HOSTNAME="$OPTARG" ;;
    C) COMMUNITY="$OPTARG" ;;
    t) TYPE="$OPTARG" ;;
    d) DISK=$OPTARG ;;
    w) WARNING=$OPTARG ;;
    c) CRITICAL=$OPTARG ;;
    h)
      print_help
      exit $STATE_UNKNOWN
      ;;
    V)
      print_version
      exit $STATE_UNKNOWN
      ;;
   esac
done

# Plugin processing
if [ $TYPE = "disk" ]; then
  # Check disk state (Usage: ./check_snmp_dell_poweredge -H 127.0.0.1 -C public -t disk -d 1)
  DISK_NAME=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME "${OID_DISK_NAME}.${DISK}" | $CMD_AWK -F '"' '{print $2}'`
  DISK_STATE=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME "${OID_DISK_STATE}.${DISK}"`
  DESCRIPTION="Etat du disque '${DISK_NAME}' : "
  case $DISK_STATE in
    0)
      DESCRIPTION="$DESCRIPTION Unknown"
      STATE=$STATE_UNKNOWN
      ;;
    1)
      DESCRIPTION="$DESCRIPTION Ready, no RAID Array found"
      STATE=$STATE_OK
      ;;
    2)
      DESCRIPTION="$DESCRIPTION Error, hard drive is not operational"
      STATE=$STATE_CRITICAL
      ;;
    3)
      DESCRIPTION="$DESCRIPTION Online, RAID array is OK"
      STATE=$STATE_OK
      ;;
    4)
      DESCRIPTION="$DESCRIPTION Offline, hard drive is not available for RAID array"
      STATE=$STATE_CRITICAL
      ;; 
    6)
      DESCRIPTION="$DESCRIPTION Degraded"
      STATE=$STATE_CRITICAL
      ;;
    7)
      DESCRIPTION="$DESCRIPTION Restoring"
      STATE=$STATE_WARNING
      ;;
    11)
      DESCRIPTION="$DESCRIPTION Hard drive not found"
      STATE=$STATE_CRITICAL
      ;;
    15)  
      DESCRIPTION="$DESCRIPTION Reconfiguring"
      STATE=$STATE_WARNING
      ;;
    24)
      DESCRIPTION="$DESCRIPTION Reconstructing"
      STATE=$STATE_WARNING
      ;;
    25)
      DESCRIPTION="$DESCRIPTION No media found"
      STATE=$STATE_WARNING
      ;;
    26)
      DESCRIPTION="$DESCRIPTION Formatting"
      STATE=$STATE_WARNING
      ;;
    28)
      DESCRIPTION="$DESCRIPTION Diagnosis"
      STATE=$STATE_WARNING
      ;;
    35)
      DESCRIPTION="$DESCRIPTION Initializing"
      STATE=$STATE_WARNING
      ;;
    *)
      DESCRIPTION="$DESCRIPTION Unknown"
      STATE=$STATE_UNKNOWN
      ;;
  esac
elif [ $TYPE = "fan" ]; then
  # Check fans RPM (Usage: ./check_snmp_dell_poweredge -H 127.0.0.1 -C public -t fan)
  TEST=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_COOLING_INDEX}.1`;
  if [ -n "$TEST" ]; then
    DESCRIPTION="Vitesse de rotation des ventilateurs :"
    for COOLING_ID in `$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME $OID_COOLING_INDEX`; do
      COOLING_NAME=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_COOLING_NAME}.${COOLING_ID} | $CMD_AWK -F '"' '{print $2}'`
      COOLING_READING=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_COOLING_READING}.${COOLING_ID}`
      DESCRIPTION="$DESCRIPTION '${COOLING_NAME}' : ${COOLING_READING} tr/min, "
      PERFORMANCE_DATA="$PERFORMANCE_DATA '${COOLING_NAME}'=${COOLING_READING}"
    done
    DESCRIPTION="$DESCRIPTION | $PERFORMANCE_DATA"
    STATE=$STATE_OK
  fi
elif [ $TYPE = "health" ]; then
  # Check global system status (Usage: ./check_snmp_dell_poweredge -H 127.0.0.1 -C public -t health)
  HEALTH_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME $OID_GLOBAL_STATUS`
  DESCRIPTION="Etat general : "
  case $HEALTH_STATUS in
    1)
      DESCRIPTION="$DESCRIPTION Unknown"
      STATE=$STATE_UNKNOWN
      ;;
    2)
      DESCRIPTION="$DESCRIPTION Unknown"
      STATE=$STATE_UNKNOWN
      ;;
    3)
      DESCRIPTION="$DESCRIPTION Normal"
      STATE=$STATE_OK
      ;;
    4)
      DESCRIPTION="$DESCRIPTION Warning"
      STATE=$STATE_WARNING
      ;;
    5)
      DESCRIPTION="$DESCRIPTION Critical"
      STATE=$STATE_CRITICAL
      ;;
    6)
      DESCRIPTION="$DESCRIPTION Critical"
      STATE=$STATE_CRITICAL
      ;;
    *)
      DESCRIPTION="$DESCRIPTION Unknown"
      STATE=$STATE_UNKNOWN
      ;;
  esac
elif [ $TYPE = "info" ]; then
  # Information (Usage: ./check_snmp_dell_poweredge -H 127.0.0.1 -C public -t info)
  MODEL_NAME=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME $OID_MODEL_NAME | $CMD_AWK -F '"' '{print $2}'`
  if [ -n "${MODEL_NAME}" ]; then
    SERIAL_TAG=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME $OID_SERVICE_TAG | $CMD_AWK -F '"' '{print $2}'`
    DESCRIPTION="Information : Dell ${MODEL_NAME} possede le service TAG '${SERIAL_TAG}'"
    STATE=$STATE_OK
  fi
elif [ $TYPE = "power" ]; then
  # Check power consumption (Usage: ./check_snmp_dell_poweredge -H 127.0.0.1 -C public -t power)
  PROBE_POWER_ID=`$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME $OID_PROBE_POWER_NAME | $CMD_GREP -i 'System Board System Level' | $CMD_AWK '{ print $1}' | $CMD_AWK -F "." '{print $NF}'`
  if [ -n "$PROBE_POWER_ID" ]; then
    PROBE_POWER_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_PROBE_POWER_STATUS}.${PROBE_POWER_ID}`
    PROBE_POWER_READING=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_PROBE_POWER_READING}.${PROBE_POWER_ID}`
    DESCRIPTION="Puissance consommee : $PROBE_POWER_READING Watts"
    case $PROBE_POWER_STATUS in
      1)
        DESCRIPTION="$DESCRIPTION (Unknown)"
        STATE=$STATE_UNKNOWN
        ;;
      2)
        DESCRIPTION="$DESCRIPTION (Unknown)"
        STATE=$STATE_UNKNOWN
        ;;
      3)
        DESCRIPTION="$DESCRIPTION (Normal)"
        STATE=$STATE_OK
        ;;
      4)
        DESCRIPTION="$DESCRIPTION (Critique)"
        STATE=$STATE_CRITICAL
        ;;
      5)
        DESCRIPTION="$DESCRIPTION (Critique)"
        STATE=$STATE_CRITICAL
        ;;
      6)
        DESCRIPTION="$DESCRIPTION (Problem)"
        STATE=$STATE_WARNING
        ;;
      7)
        DESCRIPTION="$DESCRIPTION (Problem)"
        STATE=$STATE_WARNING
        ;;
      8)
        DESCRIPTION="$DESCRIPTION (Problem)"
        STATE=$STATE_WARNING
        ;;
      9)
        DESCRIPTION="$DESCRIPTION (Problem)"
        STATE=$STATE_WARNING
        ;;
      10)
        DESCRIPTION="$DESCRIPTION (Problem)"
        STATE=$STATE_WARNING
        ;;
      *)
        DESCRIPTION="$DESCRIPTION (Unknown)"
        STATE=$STATE_UNKNOWN
        ;;
    esac
    DESCRIPTION="$DESCRIPTION | power=${PROBE_POWER_READING};0;0;0"
  fi
elif [ $TYPE = "redundancy" ]; then
  # Check power redundancy status (Usage: ./check_snmp_dell_poweredge -H 127.0.0.1 -C public -t redundancy)
  POWER_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME $OID_POWER_STATUS`
  case $POWER_STATUS in
    1)
      DESCRIPTION="Unknown"
      STATE=$STATE_UNKNOWN
      ;;
    2)
      DESCRIPTION="Unknown"
      STATE=$STATE_UNKNOWN
      ;;
    3)
      DESCRIPTION="Power supply redundancy is OK"
      STATE=$STATE_OK
      ;;
    4)
      DESCRIPTION="Degrade"
      STATE=$STATE_WARNING
      ;;
    5)
      DESCRIPTION="Power supply redundancy failure"
      STATE=$STATE_CRITICAL
      ;;
    6)
      DESCRIPTION="No Power supply redundancy found"
      STATE=$STATE_CRITICAL
      ;;
    7)
      DESCRIPTION="Hors ligne"
      STATE=$STATE_CRITICAL
      ;;
    *)
      DESCRIPTION="Inconnu"
      STATE=$STATE_UNKNOWN
      ;;
  esac
elif [ $TYPE = "temperature" ]; then
  # Check ambient temperature (Usage: ./check_snmp_dell_poweredge -H 127.0.0.1 -C public -t temperature -w 30 -c 35)
  TEMPERATURE_ID=`$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME $OID_TEMPERATURE_NAME | $CMD_GREP -i 'Ambient Temp' | $CMD_AWK '{ print $1}' | $CMD_AWK -F "." '{print $NF}'`
  if [ -n "${TEMPERATURE_ID}" ]; then
    TEMPERATURE_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_TEMPERATURE_STATUS}.${TEMPERATURE_ID}`
    if [ -n "${TEMPERATURE_STATUS}" ]; then
      TEMPERATURE_STATUS=`$CMD_EXPR $TEMPERATURE_STATUS / 10`
      if [ $TEMPERATURE_STATUS -gt $CRITICAL ] && [ $CRITICAL != 0 ]; then
        STATE=$STATE_CRITICAL
      elif [ $TEMPERATURE_STATUS -gt $WARNING ] && [ $WARNING != 0 ]; then
        STATE=$STATE_WARNING
      else
        STATE=$STATE_OK
      fi
      DESCRIPTION="Ambient temperature : $TEMPERATURE_STATUS Degres Celsius | temperature=${TEMPERATURE_STATUS};$WARNING;$CRITICAL;0"
    fi
  fi
fi

echo $DESCRIPTION
exit $STATE