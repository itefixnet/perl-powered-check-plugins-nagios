NAME
   check-printer - Nagios plugin for printer health via SNMP

SYNOPSIS
   check-printer --host|H printer [ --community|c snmp-community ] [
   --snmpwalk snmpwalk-path ] [--verbose] [--help]

DESCRIPTION
   check-printer is a Nagios plugin to monitor printer health via SNMP. It
   uses snmpwalk command to retrieve printer alert table. Strongly inspired
   by check-printers plugin
   http://exchange.nagios.org/directory/Plugins/Network-Protocols/SNMP/check
   -printers/details

OPTIONS
   --host|H printer
       Specifies printer *hostname/ip-address* to monitor. Required.

   --community|c snmp community
       Specifies SNMP community name. Default value is 'public'.

   --snmpwalk snmpwalk-path
       Specifies path to the snmpwalk program. Default value is 'snmpwalk'

   --verbose
       Produces detailed output for debugging

   --help
       Produces a help message.

EXAMPLES
    check-printer --host 10.0.0.100

   Retrieves alert table from the printer and produces status output.

    check-printer --host 10.0.0.100 --snmpwalk "c:\util\netsnmp\bin\snmpwalk"

   Retrieves alert table from the printer via snmpwalk binary
   c:\util\netsnmp\bin\snmpwalk and produces status output.

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.net>

SEE ALSO
   Nagios web site - <http://www.nagios.org/>
   check-printers plugin -
   <http://exchange.nagios.org/directory/Plugins/Network-Protocols/SNMP/chec
   k-printers/details/>

COPYRIGHT
   This program is distributed under the Artistic License
   <http://www.opensource.org/licenses/artistic-license.php/>

VERSION
   Version 1.1, December 2023

CHANGELOG
   Changes from 1.0
        - code clean-up

   Initial release

