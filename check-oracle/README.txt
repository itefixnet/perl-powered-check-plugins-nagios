NAME
   check-oracle - Nagios compatible check plugin for basic Oracle health
   checks

SYNOPSIS
   check-oracle [--tns | --login | --cache | --tablespace *tablespace name*]
   [--sid *Oracle SID*] [--user *user*] [--password *password*] [--hostname
   *hostname*] [--warning *threshold*] [--critical *threshold*]
   [--oraclehome *home path*] [--verbose] [--help]

DESCRIPTION
   check-oracle works as a Nagios NRPE plugin for basic Oracle health checks
   like tns ping, login, cache and tablespaces

OPTIONS
   --tns [ --sid *SID* | --hostname *hostname* ] [--warning *warning*] [
   --critical *critical* ]
       Performs an Oracle ping on the *SID/hostname* by using *tnsping*
       tool, and returns CRITICAL if not succeeded. Returns respectively
       CRITICAL or WARNING if tns reply time is larger than *critical* or
       *warning*.

   --login --sid *SID*
       Attempts a dummy login on the *SID* and returns CRITICAL if not
       *ORA-01017: invalid username/password* returns.

   --cache --sid *SID* --user *user* --password *password* [--warning
   *warning*] [ --critical *critical* ]
       Checks local database for library and buffer cache hit ratios on the
       *SID*, by using credentials *user/password* to logon. Returns
       respectively CRITICAL or WARNING if at least one cache ratio is below
       *critical* or *warning*.

   --tablespace *tablespace* --sid *SID* --user *user* --password *password*
   [--warning *warning*] [ --critical *critical* ]
       Checks local database for tablespace capacity of the *tablespace* on
       the *SID*, by using credentials *user/password* to logon. Returns
       respectively CRITICAL or WARNING if the usage percent is more than
       *critical* or *warning*.

   --oraclehome *home path*
       check-oracle tries to locate Oracle home directory by using
       ORACLE_HOME env variable or values in the registry. You can use this
       option if you want to override plugin's path location behaviour.

   --verbose
       Produces detailed messages for debugging.

   --help
       Produces a help message.

EXAMPLES
    check-oracle --tns --sid MYORACLE

   Pings the SID *MYORACLE* and returns CRITICAL if not succeeded or NORMAL
   otherwise.

    check-oracle --login --sid MYORACLE

   Performs a dummy login on the SID *MYORACLE* and returns CRITICAL if the
   server answers with a message other than ORA-01017 or NORMAL otherwise.

    check-oracle --cache --sid MYORACLE --user ping --password pong --warning 99 --critical 95

   Logs on by using the credentials *ping/pong* on the SID *MYORACLE*,
   queries system tables and calculates library and buffer cache hit ratios.
   Returns CRITICAL if at least one of the hit ratios is below 95%, WARNING
   if it is below 99% or NORMAL otherwise.

    check-oracle --tablespace MYTABLE --sid MYORACLE --user ping --password pong --warning 90 --critical 95

   Logs on by using the credentials *ping/pong* on the SID *MYORACLE*,
   queries system tables and calculates the usage ratio for the tablespace
   *MYTABLE*. Returns CRITICAL if the usage is over 95%, WARNING if it is
   over 90%, or NORMAL otherwise.

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.net>

SEE ALSO
   Nagios web site <http://www.nagios.org>
   Nagios NRPE documentation
   <http://nagios.sourceforge.net/docs/nrpe/NRPE.pdf>
   Standard Nagios plugins, check-oracle plugin
   check-oracle_vbs at Nagios Exchange
   <http://www.nagiosexchange.org/Oracle.153.0.html?&tx_netnagext_pi1[p_view
   ]=788>

COPYRIGHT
   This program is distributed under the Artistic License.
   <http://www.opensource.org/licenses/artistic-license.php>

VERSION
   Version 1.1, May 2011

CHANGELOG
   changes from 1.0
        - performance data output for tns check
        - ability to specify warning and critical levels for tns checks
        - Windows independency

   Initial version

