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
version=2
more=""
label="value"

# Usage Info
usage() {
  echo '''
  Usage: check_snmp [OPTIONS]
  [OPTIONS]

  -p PORT            Port to send the snmp request to (default: 161)
  -N COMMUNITY       SNMP community name (default: public)
  -H HOST            Hostname to send SNMP queries to
  -o OID             SNMP OID to query
  -V VERSION         SNMP Version (default: 2)
  -M MORE            When using -V 3, pass all required snmpget parameters
                     with -M, i.E. "-u user -a MD5 -A 72d0815....D38 -x AES"
  -L LABEL           Performance Label

  -w WARNING         Defines limit for WARNING
  -c CRITICAL        Defines limit for CRITICAL

  -W WARNING REGEX   If regex matches WARNING will be returned
  -C CRITICAL REGEX  If regex matches CRITICAL will be returned
  '''
}

#main
#get options
while getopts "p:N:H:o:V:M:W:C:w:c:" opt; do
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
    V)
      version=$OPTARG
      ;;
    M)
      more=$OPTARG
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
    l)
     label=\'$OPTARG\'
     labelClean=$OPTARG
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
if ! [[ "$version" =~ ^[0-9]+$ ]]; then
  echo "Error: -V must be 1 , 2 or 3"
  usage
  exit 3
fi
if [ $version -lt 1 ] || [ $version -gt 3 ]; then
  echo "Error: -V must be 1 , 2 or 3"
  usage
  exit 3
fi

oversion=$version
if [ $version -eq 2 ];then
  version="-v2c"
elif [ $version -eq 1 ]; then
  version="-v1"
fi

start=$(echo $(($(date +%s%N)/1000000)))
if [ $oversion -eq 3 ] ; then
  rtr=$(eval snmpget -Oqv -v3 $more $host $oid 2>&1)
else
  rtr=$(eval snmpget -Oqv $version -c $community $host $oid 2>&1)
fi
status=$?

rtr=$(echo $rtr | cut -d "\"" -f 2)
end=$(echo $(($(date +%s%N)/1000000)))
runtime=$(($end-$start))

if [ $status -eq 0 ] ; then
  if [ $regexmode -eq 1 ]; then
    if [[ "$rtr" =~ $criticalregex ]]; then
      regexsafe = ${criticalregex//[|]/PIPE}
      echo "CRITICAL: Result value '"$rtr"' matches critical regex '"$regexsafe"' | $label=$rtr"
      exit 2
    elif [[ "$rtr" =~ $warningregex ]]; then
      regexsafe = ${warningregex//[|]/PIPE}
      echo "WARNING: Result value '"$rtr"' matches warning regex '"$regexsafe"' | $label=$rtr"
      exit 1
    else
      echo "SNMP OK - $labelClean $rtr in "$runtime" ms | $label=${rtr}c;$warning;$critical;"
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
         echo "CRITICAL: '$rtr' is bigger than critical limit '$critical' | $label=$rtr;$warning;$critical;0;$critical"
         exit 2
       fi
       if [ $rtr -gt $warning ]; then
         echo "WARNING: '$rtr' is bigger than warning limit '$warning' | $label=$rtr;$warning;$critical;0;$critical"
         exit 1
       fi
    else
       if [ $rtr -lt $critical ]; then
         echo "CRITICAL: '$rtr' is smaller than critical limit '$critical' | $label=$rtr;$warning;$critical;0;$critical"
         exit 2
       fi
       if [ $rtr -lt $warning ]; then
         echo "WARNING: '$rtr' is smaller than warning limit '$warning' | $label=$rtr;$warning;$critical;0;$critical"
         exit 1
       fi
    fi
    echo "SNMP OK - $labelClean $rtr in "$runtime" ms | $label=${rtr};$warning;$critical;"
    exit 0
  fi
else
  case $status in
    1)
      echo "CRITICAL: snmpget returned error code 1 (connection failed) - $rtr"
      ;;
    *)
      echo "UNKNOWN: snmpget returned unknown error code $status - $rtr"
      exit 3
      ;;
  esac
  exit 2
fi
