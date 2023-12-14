NAME
   check-winprocess - Nagios compatible check plugin for Windows processes

SYNOPSIS
   check-winprocess [--filter *filter spec*[,*filter spec*] ... ] ... ]
   [--warning *threshold*] [--critical *threshold*] [--compare *operator*]
   [--first *number*] [--kill] [--verbose] [--help]

DESCRIPTION
   check-winprocess is a Nagios NRPE plugin for checking processes by using
   criteria like status, name, cpu and memory usage and many more. You can
   also specify if the processes meeting the criteria will be killed.
   check_process uses Windows tools *tasklist* and *taskkill* (available in
   XP and later).

OPTIONS
   --filter *filter spec*[,*filter spec*] ... ] ... ]
       Specify filters to select processes. A *filter spec* consists of
       three fields: filter name, operator and value. You can specify
       several comma separated filters for one --filter option, as well as
       several --filter options. Defaults to all processes if no filter is
       defined. List of filters available (see tasklist documentation for
       more help):

        Filter Name     Valid Operators           Valid Value(s)
        -----------     ---------------           --------------
        STATUS          eq, ne                    RUNNING | NOT RESPONDING
        IMAGENAME       eq, ne                    Image name
        PID             eq, ne, gt, lt, ge, le    PID value
        SESSION         eq, ne, gt, lt, ge, le    Session number
        SESSIONNAME     eq, ne                    Session name
        CPUTIME         eq, ne, gt, lt, ge, le    CPU time in the format
                                                  of hh:mm:ss.
                                                  hh - hours,
                                                  mm - minutes, ss - seconds
        MEMUSAGE        eq, ne, gt, lt, ge, le    Memory usage in KB
        USERNAME        eq, ne                    User name in [domain\]user
                                                  format
        SERVICES        eq, ne                    Service name
        WINDOWTITLE     eq, ne                    Window title
        MODULES         eq, ne                    DLL name

   --warning *threshold*
       Return WARNING if the number of processes matching the criteria is
       more than *threshold*. Optional.

   --critical *threshold*
       Return CRITICAL if the number of processes matching the criteria is
       more than *threshold*. Optional.

   --compare *operator*
       Specify the type of comparison operator for threshold checks.
       Optional. Available values are:

        'eq'  equal to
        'ne'  not equal
        'gt'  greater than (default!)
        'ge'  greater or equal
        'lt'  less than
        'le'  less or equal

   --first *number*
       List process names as a part of plugin output. The first specified
       number of processes will be selected. Optional.

   --kill
       Kill the processes matching the filtering criteria. Useful as an
       action handler. Works only if at least one filter is defined.
       Optional.

   --verbose
       Increase output verbosity for debugging.

   --help
       Produce a help message.

EXAMPLES
    check-winprocess.exe --warn 100 --critical 300

   Checks the total number of processes in memory and returns WARNING for
   more than 100 processes or CRITICAL for more than 300 processes.

    check-winprocess.exe --filter "imagename eq runaway.exe","cputime gt 01:00:00" --critical 1

   Checks if there exists *runaway.exe* processes with CPU time longer than
   one hour, returns CRITICAL if there was at least one process.

    check-winprocess.exe --filter "imagename eq A.EXE","imagename eq B.EXE","imagename eq C.EXE" --compare ne --critical 3

   Checks if there exists A.EXE, B.EXE and C.EXE processes, returns CRITICAL
   if the number of processes is not 3.

    check-winprocess.exe --filter "memusage gt 102400" --filter "status eq NOT RESPONDING" --kill --critical 1

   Checks if there exists processes with memory consumption more than 100 MB
   and in *NOT RESPONDING* state, kills them and returns CRITICAL if there
   was at least one process.

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
   TASKLIST documentation
   <http://technet.microsoft.com/en-us/library/bb491010.aspx>
   TASKKILL documentation
   <http://technet.microsoft.com/en-us/library/bb491009.aspx>

COPYRIGHT
   This program is distributed under the Artistic License.
   <http://www.opensource.org/licenses/artistic-license.php>

VERSION
   Version 1.6, October 2012

CHANGELOG
   changes from 1.5
        Introduce option --first allowing to list first number of process names as a part of the plugin output.
        List process names as comma separated list in verbose output (newline creates some problems)

   changes from 1.4
        produce performance data according to guidelines

   changes from 1.3
        Proper treatment of 0 as threshold

   changes from 1.2
        renamed as 'check-winprocess'
        use csv output from tasklist

   changes from 1.1
        Drop the language specific -no output- check

   Changes from 1.0
        Add option I<--compare> to specify the type of comparison for threshold checks.
        Treat information about no tasks properly.

