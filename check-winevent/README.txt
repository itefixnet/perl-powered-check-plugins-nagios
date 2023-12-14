NAME
   check-winevent - Nagios compatible check plugin for Windows eventlogs

SYNOPSIS
   check-winevent [ [ --log event log[,event log ...] ] ... ] [ [ --code
   event code[,event code ...] ] ... ] [ [ --type event type[,event type
   ...] ] ... ] [ [ --source event source[,event source ...] ] ... ] [
   --window time window ] [--warning *threshold*] [--critical *threshold*]
   [--verbose] [--help]

DESCRIPTION
   check-winevent is a Nagios plugin to monitor event logs on the local
   Windows system. You can filter events based on time, code, type and
   source. Negation is also possible for code, type and source.
   check-winevent is capable of scanning multiple event logs.

OPTIONS
   --log event log[,event log ...] ] ...
       Specifies event logs you want to monitor. You can supply comma
       separated values as well as multiple --log options. Optional.
       Defaults to all available event logs on the system.

   --code event code[,event code ...] ] ...
       Specifies event codes you want to monitor. You can supply comma
       separated values as well as multiple --code options. In addition, you
       may negate an event code by prepending a ! (like !1904). Optional.
       Defaults to all event codes.

   --type event type[,event type ...] ] ...
       Specifies event types you want to monitor. You can supply comma
       separated values as well as multiple --type options. In addition, you
       may negate an event type by prepending a ! (like !warning). Available
       event types: (case insensitive):

        - information
        - warning
        - error
        - audit failure
        - audit success

       Optional. Defaults to all event types.

   --source event source[,event source ...] ] ...
       Specifies event sources you want to monitor. You can supply comma
       separated values as well as multiple --source options. In addition,
       you may negate an event source by prepending a ! (like !W32Time).
       Optional. Defaults to all event sources.

   --window *time value*
       Process events within the last *time value*. You may specify a time
       value in free form like "5 minutes and 10 seconds". Optional.
       Defaults to '1 hour'.

   --warning *threshold*
       Returns WARNING exit code if the selected number of events is above
       the *threshold*. Optional.

   --critical *threshold*
       Returns CRITICAL exit code if the selected number of events is above
       the *threshold*. Optional.

   --verbose
       Produces some output for debugging or to see individual values of
       samples. Multiple values are allowed.

   --help
       Produces a help message.

EXAMPLES
    check-winevent --type error --window "5 minutes" --critical 0

   Scans all event logs available on the system and returns CRITICAL if
   there was at least one error event last 5 minutes.

    check-winevent --log application --source "Application Hang","Application Error" --type error --warning 10 --critical 100

   Scans application event log for events occurred during the last hour and
   returns WARNING or CRITICAL if the number of events exceed 10 or 100
   respectively.

    check-winevent --log security --window "30 minutes" --type "audit failure"

   Scans security event log and returns CRITICAL if there was at least one
   audit failure event during the last 30 minutes.

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.net>

SEE ALSO
   Nagios web site <http://www.nagios.org>
   Perl Time::Duration::Parse documentation
   <http://search.cpan.org/~miyagawa/Time-Duration-Parse-0.06/lib/Time/Durat
   ion/Parse.pm>

COPYRIGHT
   This program is distributed under the Artistic License.
   <http://www.opensource.org/licenses/artistic-license.php>

VERSION
   Version 1.3, January 2014

CHANGELOG
   Changes from 1.2
        - Bug fix: Improper combination of multiple negated elements in the generated WQL string. See Itefix forum topic https://www.itefix.no/i2/content/problem-checkwinevent-multiple-code-exclusions for more info.
        - New packaging - faster start

   Changes from 1.1
        - use UTC instead of localtime as WMI delivers event entries with UTC-time

   Changes from 1.0
        -typo status code SERVICE -> EVENT

   Initial release

