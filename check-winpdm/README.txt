NAME
   check-winpdm - Nagios compatible check plugin for Windows processor, disk
   and memory checks

SYNOPSIS
   check-winpdm [ [ --processor [--psamples *count*] [--pinterval *seconds*]
   ] | [ --disk [--drive *drive letter with colon*] ] | [ --memory [
   *physical|virtual|pagefile* ] ] ] [--warning *threshold*] [--critical
   *threshold*] [--verbose] [--help]

DESCRIPTION
   check-winpdm is a Nagios plugin to monitor basic resources of processor,
   disk and memory on the local Windows system.

OPTIONS
   --processor
       Checks processor utilization by collecting three samples with
       two-seconds intervals and returns the average as default. Number of
       samples and interval can be adjusted by the options *--psamples* and
       *--pinterval*.

   --disk
       Checks local disk utilization by using WMI. Option --drive must be
       specified.

   --drive *local drive letter with colon*
       Disk only. Specifies the local drive for utilization measurement.

   --memory [ *physical|virtual|pagefile* ]
       Checks physical, virtual or pagefile memory utilization by using WMI.
       Default is physical.

   --warning *threshold*
       Returns WARNING exit code if the measured value is above the
       *threshold*.

   --critical *threshold*
       Returns CRITICAL exit code if the measured value is above the
       *threshold*.

   --psamples *count*
       Processor only. Specifies the number of samples for calculation of
       processor usage. Default is 3.

   --pinterval *seconds*
       Processor only. Specifies the interval in seconds between samples.
       Default is 2.

   --verbose
       Produces some output for debugging or to see individual values of
       samples.

   --help
       Produces a help message.

EXAMPLES
    check-winpdm --processor --warning 60 --critical 90 --psamples 10 --pinterval 5

   Calculates an average CPU utilization value by sampling the related
   performance counter 10 times with 5-seconds intervals. In addition to a
   one-line status output, it also returns CRITICAL if the calculated value
   is above 90, WARNING if it is above 60 or NORMAL otherwise.

    check-winpdm --disk --drive C: -w 97.5 -c 99.5

   Gets utilization of C: drive, produces a one-line status output, returns
   CRITICAL if the measured value is above 97.5%, WARNING if it is above
   99.5% or NORMAL otherwise.

    check-winpdm --memory -w 90 -c 99

   Gets information about physical memory usage, produces a one-line status
   output, returns CRITICAL if the measured value is above 99, WARNING if it
   is above 90 or NORMAL otherwise.

    check-winpdm --memory pagefile -w 80 -c 95

   Gets information about pagefile usage, produces a one-line status output,
   returns CRITICAL if the measured value is above 95, WARNING if it is
   above 80 or NORMAL otherwise.

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.net>

SEE ALSO
   Nagios web site <http://www.nagios.org>
   typeperf documentation
   <http://www.microsoft.com/resources/documentation/windows/xp/all/proddocs
   /en-us/nt_command_typeperf.mspx?mfr=true>

COPYRIGHT
   This program is distributed under the Artistic License.
   <http://www.opensource.org/licenses/artistic-license.php>

VERSION
   Version 1.6, April 2016

CHANGELOG
   Changes from 1.5
        - use WMIC for processor checks

   Changes from 1.4
        - produce performance data according to guidelines

   Changes from 1.3
        - Processor measurements are made via 'top' tool on Cygwin.

   Changes from 1.2
        - Use Win32::Perflib (ref http://www.jkrb.de/jmk/showsource.asp?f=data/scripts/processor.pl)
        - option --memory accepts three value for different types of memory checks: I<physical> (default), I<virtual> and I<pagefile>

   Changes from 1.1
        - processor: Change time interval unit from seconds to milliseconds
        - processor: Use perl module instead of the external tool typeperf

   Changes from 1.0
        - use CRITICAL instead of ERROR
        - New option --verbose to produce some additional information for debugging or monitoring.
        - Processor. Two new options: --psamples and --pinterval
        - Disk. Total disk size is also printed.
        - Memory. Page file is monitored instead of physical memory.

