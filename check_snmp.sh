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
  echo '''Usage: check_snmp [OPTIONS]
  [OPTIONS]:
  -p PORT          Port to send the snmp request to (default: 161)
  -C COMMUNITY     SNMP community name (default: public)
  -H HOST          Hostname to send SNMP queries to
  -o OID           SNMP OID to query
  -l WARNING       If regex matches WARNING will be returned, overrides -m,-w, -W and -M
  -h CRITICAL      If regex matches CRITICAL will be returned, overrides -m, -w, -W and -M
  -w MIN_WARNING   Bottom warning limit, if result is an integer value and below limit, WARNING will be returned
  -m MAX_WARNING   Top warning limit, if result is an integer value and above limit, WARNING will be returned
  -W MIN_CRITICAL  Bottom critical limit, if result is an integer value and below limit, CRITICAL will be returned
  -M MAX_CRITICAL  Top critical limit, if result is an integer value and above limit, CRITICAL will be returned'''
}

#main
#get options
while getopts "p:C:H:o:l:h:w:m:W:M:" opt; do
  case $opt in
    p)
      port=$OPTARG
      ;;
    C)
      community=$OPTARG
      ;;
    H)
      host=$OPTARG
      ;;
    o)
      oid=$OPTARG
      ;;
    l)
      warningregex=$OPTARG
      ;;
    h)
      criticalregex=$OPTARG
      ;;
    w)
      minwarning=$OPTARG
      ;;
    m)
      maxwarning=$OPTARG
      ;;
    W)
      mincritical=$OPTARG
      ;;
    M)
      maxcritical=$OPTARG
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
elif [ -n "$minwarning" ] && [ -n "$maxwarning" ] && [ -n "$mincritical" ] && [ -n "$maxcritical" ]; then
  regexmode=0
else
  echo "Error: Either use -l and -h OR use -w -m -W -M"
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
      echo "CRITICAL: Response value '"$rtr"' matches critical regex '"$criticalregex"'"
      exit 2
    elif [[ "$rtr" =~ $warningregex ]]; then
      echo "WARNING: Response value '"$rtr"' matches warning regex '"$warningregex"'"
      exit 1
    else
      echo "OK: snmpget='"$rtr"' in "$runtime" ms"
    fi
  else
    re='^[0-9]+$'
    if ! [[ $rtr =~ $re ]] ; then
      echo "CRITICAL: Expected integer value as repsonse (as using -w -m -W- M) but response is not an integer value '$rtr' - use -l and -h for regex checks"
      exit 2
    fi

    if [ $rtr -gt $maxcritical ] || [ $rtr -lt $mincritical ]; then
      if [ $rtr -gt $maxcritical ]; then
        echo "CRTICAL: Response value '"$rtr"' is bigger than critical limit '"$maxcritical"'"
      else
        echo "CRTICAL: Response value '"$rtr"' is smaller than critical limit '"$mincritical"'"
      fi
      exit 2
    elif [ $rtr -gt $maxwarning ] || [ $rtr -lt $minwarning ]; then
      if [ $rtr -gt $maxwarning ]; then
        echo "WARNING: Response value '"$rtr"' is bigger than warning limit '"$maxwarning"'"
      else
        echo "WARNING: Response value '"$rtr"' is smaller than warning limit '"$minwarning"'"
      fi
      exit 1
    else
      echo "OK: snmpget='"$rtr"' in "$runtime" ms"
    fi
  fi
  exit $?
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
