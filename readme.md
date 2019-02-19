# check_snmp
Provides SNMP checks using warning / critical limits for integer results or regexes.
Supports performance data.

## Script
```
  Usage: check_snmp [OPTIONS]
  [OPTIONS]

  -p PORT            Port to send the snmp request to (default: 161)
  -n COMMUNITY       SNMP community name (default: public)
  -H HOST            Hostname to send SNMP queries to
  -o OID             SNMP OID to query

  -w WARNING         Defines limit for WARNING
  -c CRITICAL        Defines limit for CRITICAL

  -W WARNING REGEX   If regex matches WARNING will be returned
  -C CRITICAL REGEX  If regex matches CRITICAL will be returned
```
Notes: 
- You can either set limits (-w & -c) OR regexes (-W & -C)
- Setting limits and regexes, regexes will be used
- When using regexes, the performance data won't include warning / critical limits
- When setting a warning limit that is smaller than the critical limit, a GREATER THAN will be used to evaluate the result
- When setting a critical limit that is smaller than the warning limit, a LESS THAN will be used to evaluate the result

Example usage of the script:
```
# (1) If result is bigger than 4, return warning, bigger than 7, return critical
./check_snmp.sh -H 192.168.200.101 -o iso.3.6.1.2.1.25.4.2.1.6.11391 -w 4 -c 7
CRITICAL: '5' is bigger than warning limit '$critical'

# (2) If result is smaller than 4, return warning, smaller than 2, return critical (since -w > -c)
./check_snmp.sh -H 192.168.200.101 -o iso.3.6.1.2.1.25.4.2.1.6.11391 -w 4 -c 2
CRITICAL: '5' is bigger than warning limit '$critical'

# (3) If result is between 1-3, return warning, between 4-99 return critical
./check_snmp.sh -H 192.168.200.101 -o iso.3.6.1.2.1.25.4.2.1.6.11391 -W [1-3] -C [4-99]
WARNING: Result value '2' matches warning regex '[1-3]'

# (4) If result string is a Pentium CPU, return warning, if a Xeon CPU, return critical
./check_snmp.sh -H 192.168.200.101 -o iso.3.6.1.2.1.25.3.2.1.3.1 -l "Pentium" -h "Intel.*Xeon.*"
CRITICAL: Result value 'Intel(R) Xeon(R) CPU E5-1680 v2 @ 3.00GHz' matches critical regex 'Intel.*Xeon.*'
```

## Icinga 2
Usage in your hosts file:
```
# (1)
object Host "mailserver.local" {
  check_command = "check-snmp"
  address = "192.168.200.101"
  vars.csnmp_oid = "iso.3.6.1.2.1.25.4.2.1.6.11391"
  vars.csnmp_warning = "4"
  vars.csnmp_critical = "7"
}
# (3)
object Host "mailserver.local" {
  check_command = "check-snmp"
  address = "192.168.200.101"
  vars.csnmp_oid = "iso.3.6.1.2.1.25.4.2.1.6.11391"
  vars.csnmp_community = "communityname"
  vars.csnmp_port = 1234
  vars.csnmp_warning_regex = "[1-3]"
  vars.csnmp_critical_regex = "[4-99]"
}
```
See the provided commands.conf for the Icinga command definition of "check-snmp".
