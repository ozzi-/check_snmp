# check_snmp
Provides SNMP checks using minimum and maximum integer values for warning and critical levels or regexes for warning & critical.


Example usage of the script:
```
./check_snmp.sh -H 192.168.200.101 -o iso.3.6.1.2.1.25.4.2.1.6.11391 -w 3 -m 7 -W 7 -M 999
CRTICAL: Response value '4' is smaller than critical limit '7'

./check_snmp.sh -H 192.168.200.101 -o iso.3.6.1.2.1.25.4.2.1.6.11391 -l [0-3] -h [4-6]
CRITICAL: Response value '4' matches critical regex '[4-6]'

./check_snmp.sh -H 192.168.200.101 -o iso.3.6.1.2.1.25.3.2.1.3.1 -l "Pentium" -h "Intel.*Xeon.*"
CRITICAL: Response value 'Intel(R) Xeon(R) CPU E5-1680 v2 @ 3.00GHz' matches critical regex 'Intel.*Xeon.*'
```


Example config (see commands.conf) for Icinga 2:
```
object Host "mailserver.local" {
  check_command = "snmp"
  address = "192.168.200.101"
  vars.csnmp_oid = "iso.3.6.1.2.1.25.3.2.1.3.1"
  vars.csnmp_community = "public"
  vars.csnmp_warning_min = "10"
  vars.csnmp_warning_max = "40"
  vars.csnmp_critical_min = "10"
  vars.csnmp_critical_max = "60"
}
```
