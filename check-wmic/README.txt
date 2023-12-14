NAME
   check-wmic - Nagios compatible check plugin for WMI checks

SYNOPSIS
   check-wmic --host|H hostname [ --user user --password password ] --alias
   alias --property property [ --every interval --repeat count ] [ --format
   output-format ] [ --factor number ] [--count] [ --ratio property ] [
   --compare operator ] [--warning *threshold*] [--critical *threshold*]
   [--verbose] [--help]

DESCRIPTION
   check-wmic is a Nagios plugin to monitor Windows systems via WMI (Windows
   Management Instrumentation) from Windows. It uses command line tool WMIC,
   available as standard from Windows XP/2003 on. check_wmi can be used as
   an Windows NRPE plugin as well as an agentless monitoring solution for
   Nagwin.

OPTIONS
   --host|H hostname
       Specifies remote *hostname/ip-address* to monitor. Required.

   --user user --password password
       Specifies credentials to be used to initiate a WMI-connection to the
       remote host. Optional. Credentials of the user running the plugin are
       used as default.

   --alias alias --property property
       Specifies WMI-alias and -property to process in the plugin. Running
       ""wmic /?"" produces available aliases on a system. More information
       about the alias and supported properties are available via ""wmic
       alias" *alias name*". Please check wmic and wql documentation for
       more details.

       Some simple alias and property examples:

        CPU, LoadPercentage
        OS, FreePhysicalMemory
        PAGEFILE, CurrentUsage

       or a complex one:

        Service where (StartMode='Auto' And State!='Running'),Name

       Alias and property are required values.

   --every interval --repeat count
       check-wmic allows you to use wmic options EVERY (in seconds) and
       REPEAT to collect multiple measurements of the same property value.
       Those can be used to calculate an average value for a stretch of
       time, instead of an instant value. CPU Load is a typical example.
       It's been observed that a first measurement in this scenario may
       deviate greatly from other values, due to a potential initial warm-up
       overhead. check-wmic ignores simply the first observation due to that
       fact.

   --format output-format
       It's often desirable to produce some descriptive text as a part of
       the plugin. Describing measured value, measurement units or Nagios
       performance data are examples. --format option allows you to specify
       a format which is acceptable as a first argument to Perl's sprintf
       function. You can specify up to 2 conversions for the value
       collected, one for the normal output, and the other for the
       performance data. Optional.

       Example 1: Collected data: 65, format CPU Load: %d%|'cpu load'=%d%
       produces ""CPU Load: 65%|'cpu load'=65%"".

       Example 2: Collected data: 12.45678934, Format Free memory: %.2f MB.
       produces ""Free memory: 12.46 MB."".

   --factor number
       Sometimes it may be necessary to convert values into more meaningful
       units. *Bytes to MB* or *bits to Mbits* are typical examples. Option
       --factor can be used to multiply the value with the factor you
       specify. Example: factor *0,0009765625* can be used to convert KB to
       MB, MB to GB ...

   --count number
       Some properties generate a list of items instead of a single value.
       List of services is an example. Option --count instructs the plugin
       to count the collected values, not processing them individually.
       Optional.

   --ratio property
       Specify one additional property to be used for calculaction of a
       ratio. Example "--property FreeSpace --ratio Size" allows the plugin
       to work on ratio values of "FreeSpace/Size".

   --compare *operator*
       Specify the type of comparison operator for threshold checks.
       Optional. Available values are:

        'eq'  equal to
        'ne'  not equal
        'gt'  greater than (default!)
        'ge'  greater or equal
        'lt'  less than
        'le'  less or equal

   --warning *threshold*
       Returns WARNING exit code if the value is above (if the warning
       threshold lower than the critical one) or below the *threshold*.
       Optional.

   --critical *threshold*
       Returns CRITICAL exit code if the value is above (if the warning
       threshold lower than the critical one) or below the *threshold*.
       Optional.

   --verbose
       Produces some output for debugging or to see individual values of
       samples.

   --help
       Produces a help message.

EXAMPLES
    check-wmic --host 10.0.0.100 --user abra --password kadabra --alias cpu --property LoadPercentage --every 4 --repeat 4 --format "CPU load %.2f%.|'CPU Load'=%.2f%" --warning 75 --critical 90

   Connects to the host by the supplied credentials, collects CPU load
   percentage three times (the first one of four is dropped) with 4-secs
   intervals, calculates an average value, and produces an output according
   to the format specified. Returns CRITICAL if the load is more than 90%,
   WARNING if it is more than 75%.

    check-wmic --host 10.0.0.100 --alias "LogicalDisk where DeviceID='C:'" --property FreeSpace --factor 0.0000009536743 --format "Free disk space on C: %.2f MB|'Free C:'=%.2fMB" --warn 500 --crit 50

   Connects to the host by the current user's credentials, collects free
   space available on C-disk in bytes, converts it to MB by using the factor
   specified, and produces an output according to the format specified.
   Returns CRITICAL if free space is under 50 MB, WARNING if it is under 500
   MB.

    check-wmic --host 10.0.0.100 --alias "LogicalDisk where DeviceID='C:'" --property FreeSpace --Ratio Size --format "Free disk space on C: %.2f% |'Free C:'=%.2f%" --warn 2 --critical 0.5 --compare lt

   Connects to the host by the current user's credentials, collects free
   space and size on C-disk in bytes, calculates free space ratio
   (freespace/size), and produces an output according to the format
   specified. Returns WARNING if free space is less than 2%, CRITICAL if it
   is less than 0.5%.

    check-wmic --host 10.0.0.100 --user 'abra@nuke.local' --password '!!"#%&' --alias "Service where (StartMode='Auto' And State!='Running')" --property Name --count --format "%d non-running automatic services." --crit 5

   Connects to the host by the supplied domain account credentials, collects
   the instances of automatic Windows services which are not running, counts
   them, and produces an output according to the format specified. Returns
   CRITICAL if there are at least 5 such services.

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.net>

SEE ALSO
   Nagios web site - <http://www.nagios.org/>
   WMIC Tool -
   <http://msdn.microsoft.com/en-us/library/windows/desktop/aa394531%28v=vs.
   85%29.aspx/>
   Perl sprintf - <http://perldoc.perl.org/functions/sprintf.html/>
   WQL (SQL for WMI) -
   <http://msdn.microsoft.com/en-us/library/windows/desktop/aa394606%28v=vs.
   85%29.aspx/>

COPYRIGHT
   This program is distributed under the Artistic License
   <http://www.opensource.org/licenses/artistic-license.php/>

VERSION
   Version 1.2, January 2015

CHANGELOG
   changes from 1.1
        Add option I<--ratio> to specify one additional property for ratio calculation.
        Options --warning and --critical accept floating values

   changes from 1.0
        Add option I<--compare> to specify the type of comparison for threshold checks.
        Return unknown if counter is not available.

   Initial release

