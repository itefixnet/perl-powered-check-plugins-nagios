NAME
   check-winservice - Nagios compatible check plugin for Windows services

SYNOPSIS
   check-winservice [ [ --service service[,service ...] ] ... ] [ [ --state
   state[,state ...] ] ... ] [ [ --startmode startmode[,startmode ...] ] ...
   ] [ --fingerprint [fingerprint] ] [--warning *threshold*] [--critical
   *threshold*] [--verbose] [--help]

DESCRIPTION
   check-winservice is a Nagios plugin to monitor services on the local
   Windows system. You can filter services based on name, state or start
   mode. Negation is also possible. check-winservice has also a *service
   snapshot fingerprint* capability which may help you to monitor changes on
   service configurations.

OPTIONS
   --service service[,service ...] ] ...
       Specifies services you want to monitor. You can supply comma
       separated values as well as multiple --service options. In addition,
       you may exclude a service by prepending a ! (like !alerter).
       Optional. Defaults to all services.

   --state state[,state ...] ] ...
       Specifies service states you want to monitor. You can supply comma
       separated values as well as multiple --state options. In addition,
       you may negate a state by prepending a ! (like !running). Available
       state values (case insensitive):

        - running
        - stopped
        - paused
        - start pending
        - stop pending
        - continue pending
        - pause pending
        - unknown

       Optional. Defaults to all states.

   --startmode startmode[,startmode ...] ] ...
       Specifies service start modes you want to monitor. You can supply
       comma separated values as well as multiple --startmode options. In
       addition, you may negate a start mode by prepending a ! (like !auto).
       Available start mode values (case insensitive):

        - auto
        - manual
        - disabled
        - boot
        - system

       Optional. Defaults to all start modes.

   --fingerprint [fingerprint]
       Generates a *service snapshot fingerprint* for the selected set of
       services. A *service snapshot fingerprint* is simply an MD5 digest of
       a string consisting of concatenated values of following properties
       for each selected service:

        - Name, DisplayName, PathName, ServiceType, Started, StartMode, StartName, State, Status, Description

       prints the fingerprint if no parameter is specified. Otherwise it
       checks if the given fingerprint matches the current fingerprint for
       the selected services. Returns CRITICAL if it is a mismatch, OK
       otherwise. That way, you can get an indication about a possible
       unauthorized service configuration change.

   --warning *threshold*
       Returns WARNING exit code if the selected number of services is above
       the *threshold*. Optional.

   --critical *threshold*
       Returns CRITICAL exit code if the selected number of services is
       above the *threshold*. Optional.

   --verbose
       Produces some output for debugging or to see individual values of
       samples. Multiple values are allowed.

   --help
       Produces a help message.

EXAMPLES
    check-winservice --startmode auto --state !running --critical 0

   Returns CRITICAL if there exists automatic services which are not
   running.

    check-winservice --service TroubleMaker1,TroubleMaker2 --state running --critical 0

   Returns CRITICAL if services *TroubleMaker1* or *TroubleMaker2* are
   running.

    check-winservice --critical 1 -startmode boot,system -service !BootA,!BootB,!SystemC

   Returns CRITICAL if there is at least one service except service BootA,
   BootB and SystemC, which is configured to start during boot or system
   phase.

    check-winservice --warning 200 --critical 300

   Returns WARNING or CRITICAL if the number of defined services exceeds 200
   or 300 respectively.

    check-winservice --startmode !manual --service Manual1,Manual2 --service Manual3 --critical 0

   Returns CRITICAL if services *Manual1*, *Manual2* or *Manual3* are not
   configured to run manually.

    check-winservice --fingerprint --state running

   Print the *service snapshot fingerprint* for running services.

    check-winservice --fingerprint xxxxxxxxxxxxxxxxxxxxxxx --state running

   Returns CRITICAL if the specified fingerprint xxxxxxx does not match the
   *service snapshot fingerprint* of running services

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.no>

SEE ALSO
   Nagios web site <http://www.nagios.org>
   Nagios NRPE documentation
   <http://nagios.sourceforge.net/docs/nrpe/NRPE.pdf>
   typeperf documentation
   <http://www.microsoft.com/resources/documentation/windows/xp/all/proddocs
   /en-us/nt_command_typeperf.mspx?mfr=true>

COPYRIGHT
   This program is distributed under the Artistic License.
   <http://www.opensource.org/licenses/artistic-license.php>

VERSION
   Version 1.1, October 2011

CHANGELOG
   Changes from 1.0
        - Bug fix: Improper combination of multiple negated elements in the generated WQL string.

   Initial release

