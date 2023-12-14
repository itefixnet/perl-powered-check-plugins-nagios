NAME
   check-winping - Nagios compatible check plugin for Windows ping checks

SYNOPSIS
   check-winping [ -H | --hostname ] *host* --warning *threshold* --critical
   *threshold* [ [ -4 | --use-ip4 ] | [ -6 | --use-ipv6 ] ] [ --packets
   *number of packets* ] [ --buffersize *number of bytes* ] [ --timeout
   *seconds* ] [ --verbose .. ] [ --help ]

DESCRIPTION
   Inspired by the standard Nagios plugin check_ping, check-winping performs
   ping checks from Windows systems. It is a compiled perl script and the
   source code is available as a part of the package.

OPTIONS
   -H|--hostname *host*
       Hostname to ping. Required.

   --warning *threshold*
       Return WARNING if measured values are at least the threshold values.
       A *threshold* is specified as a combination of round trip time and
       packet loss ratio with the following format : round-trip-time in
       milliseconds,packet-losss-ratio%. Example: 100,80%. Required.

   --warning *threshold*
       Return CRITICAL if measured values are at least the threshold values.
       A *threshold* is specified as a combination of round trip time and
       packet loss ratio with the following format : round-trip-time in
       milliseconds,packet-losss-ratio%. Example: 100,80%. Required.

   -4|--use-ip4
       Use IPv4 connection (standard Windows ping.exe). Optional. Default is
       on.

   -6|--use-ip6
       Use IPv6 connection (standard Windows ping6.exe). Optional. Default
       is off.

   --packets *number of packets*
       Specify the number of packets to send during pinging. Optional.
       Default is 5 packets.

   --buffersize *number of bytes*
       Specify buffer size for ping packets. Optional. Default is 32 bytes.

   --timeout *seconds*
       Specify ping timeout in seconds. Optional. Default is 10 seconds.

   --verbose
       Produces detailed output for debugging. Optional. Can be specified up
       to twice for increasing verbosity.

   --help
       Produces a help message.

EXAMPLE
    check-winping -H itefix.no --warning 100,80% --critical 250,100%

   Checks *itefix.no* with default ping values and returns WARNING if round
   trip average or packet loss ratio is at least 100 ms or 80% respectively,
   returns CRITICAL if round trip average or packet loss ratio is at least
   250 ms or 100% respectively

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.net>

SEE ALSO
   Nagios web site <http://www.nagios.org>

COPYRIGHT
   This program is distributed under the Artistic License.
   <http://www.opensource.org/licenses/artistic-license.php>

VERSION
   Version 1.5, February 2013

CHANGELOG
   Changes from 1.4
        - Bug fix: Proper handling of no responses.
        - New packaging with a faster binary and no need for local temp storage

   Changes from 1.3
        - Produce performance data output according to the guidelines

   Changes from 1.2
        - Bug fix: Newer Windows versions produce ping messages with one less
          empty line. check-winping strips now all empty lines before
          processing ping output.

   Changes from 1.1
        - Better pattern match for localized pings (support for multiple words)
        - Scan response messages to detect anomalies (TTL expire for instance)

   Changes from 1.0
        - Use more generalized match patterns to support localized ping/ping6

   Initial version

