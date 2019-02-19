#!/bin/bash
# Author: ozzi-  https://github.com/ozzi-/check_snmp/ 

# startup checks
if [ -z "$BASH" ]; then
  echo "Please use BASH."
  exit 3
fi
if [ ! -e "/usr/bin/which" ]; then
  echo "/usr/bin/which is missing."
  exit 3
fi
snmp=$(which snmpget)
if [ $? -ne 0 ]; then
  echo "Please install snmpget"
  exit 3
fi

# Default Values
community="public"
port=161

# Usage Info
usage() {
  echo '''
  Usage: check_snmp [OPTIONS]
  [OPTIONS]

  -p PORT            Port to send the snmp request to (default: 161)
  -N COMMUNITY       SNMP community name (default: public)
  -H HOST            Hostname to send SNMP queries to
  -o OID             SNMP OID to query

  -w WARNING         Defines limit for WARNING
  -c CRITICAL        Defines limit for CRITICAL

  -W WARNING REGEX   If regex matches WARNING will be returned
  -C CRITICAL REGEX  If regex matches CRITICAL will be returned
  '''
}

#main
#get options
while getopts "p:N:H:o:W:C:w:c:" opt; do
  case $opt in
    p)
      port=$OPTARG
      ;;
    N)
      community=$OPTARG
      ;;
    H)
      host=$OPTARG
      ;;
    o)
      oid=$OPTARG
      ;;
    W)
      warningregex=$OPTARG
      ;;
    C)
      criticalregex=$OPTARG
      ;;
    w)
      warning=$OPTARG
      ;;
    c)
      critical=$OPTARG
      ;;
    *)
      usage
      exit 3
      ;;
  esac
done

#required paramters
if [ -z "$host" ]; then
  echo "Error: host is required"
  usage
  exit 3
fi
if [ -n "$criticalregex" ] && [ -n "$warningregex" ]; then
  regexmode=1
elif [ -n "$warning" ] && [ -n "$critical" ]; then
  regexmode=0
else
  echo "Error: Either use regexes -W & -C OR use -w & -c"
  usage
  exit 3
fi
if [ -z "$oid" ]; then
  echo "Error: oid is required"
  usage
  exit 3
fi

start=$(echo $(($(date +%s%N)/1000000)))
rtr=$(snmpget -Oqv -v2c -c $community $host $oid)
status=$?
rtr=$(echo $rtr | cut -d "\"" -f 2)
end=$(echo $(($(date +%s%N)/1000000)))
runtime=$(($end-$start))

if [ $status -eq 0 ] ; then
  if [ $regexmode -eq 1 ]; then
    if [[ "$rtr" =~ $criticalregex ]]; then
      echo "CRITICAL: Result value '"$rtr"' matches critical regex '"$criticalregex"'"
      exit 2
    elif [[ "$rtr" =~ $warningregex ]]; then
      echo "WARNING: Result value '"$rtr"' matches warning regex '"$warningregex"'"
      exit 1
    else
      echo "OK: snmpget='"$rtr"' in "$runtime" ms | result=$rtr"
      exit 0
    fi
  else
    re='^[0-9]+$'
    if ! [[ $rtr =~ $re ]] ; then
      echo "CRITICAL: Expected integer value as repsonse, since you are using -w & -c, but result is not an integer value '$rtr' - use -W & -C to use regexes"
      exit 2
    fi
    if [ $critical -gt $warning ]; then
       if [ $rtr -gt $critical ]; then
         echo "CRITICAL: '$rtr' is bigger than critical limit '$critical'"
         exit 2
       fi
       if [ $rtr -gt $warning ]; then
         echo "WARNING: '$rtr' is bigger than warning limit '$warning'"
         exit 1
       fi
    else
       if [ $rtr -lt $critical ]; then
         echo "CRITICAL: '$rtr' is smaller than critical limit '$critical'"
         exit 2
       fi
       if [ $rtr -lt $warning ]; then
         echo "WARNING: '$rtr' is smaller than warning limit '$warning'"
         exit 1
       fi
    fi
    echo "OK: snmpget='"$rtr"' in "$runtime" ms | value=$rtr;$warning;$critical;0;$critical"
    exit 0
  fi
else
  case $status in
    1)
      echo "CRITICAL: snmpget returned error code 1 (connection failed)"
      ;;
    *)
      echo "UNKNOWN: snmpget returned unknown error code $status"
      exit 3
      ;;
  esac
  exit 2
fi
