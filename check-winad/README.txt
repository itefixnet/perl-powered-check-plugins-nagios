NAME
   check-winad - Nagios compatible check plugin for basic Active Directory
   health checks

SYNOPSIS
   check-winad [--dc] [--dfsr] [--noeventlog] [--verbose] [--config *config
   file*] [--help]

DESCRIPTION
   check-winad is a Nagios compatible check plugin for basic Active
   Directory health checks

OPTIONS
   --dc
       Checks domain controller functionality by using *dcdiag* tool from
       Windows Support Tools. Following dcdiag tests are performed :

        services, replications, advertising, fsmocheck, ridmanager (not for RODCs), machineaccount, kccevent, frssysvol (2003 or later), frsevent (2003 or later), sysvolcheck(2008 or later), dfsrevent (2008 or later)

   --dfsr
       Specifies that SysVol replication uses DFS instead of FRS (Windows
       2008 or later)

   --noeventlog
       Don't run the dc tests kccevent and frsevent, since their 24-hour
       scope may not be too relevant for Nagios.

   --verbose
       Prints dcdiag command to run.

   --config *config file*
       check-winad can be localized by using a configuration file
       (*check-winad.config* in the same directory as the plugin itself by
       default). This parameter can be used to specify an alternative
       location for the configuration file.

   --help
       Produces help message.

CONFIGURATION FILE
   dcdiag tool used by check-winad can produce localized output. check-winad
   can use a configuration file to map localized dcdiag output to
   pre-defined scanning patterns. The default location is
   *check-winad.config* in the same directory as the plugin itself. You can
   use *--config* option to specify an alternative location. check-winad
   will use English language by default if there is no configuration file.
   Configuration file example:

    # check-winad configuration for language mappings
    # replace strings right to equal signs with your localized dcdiag/netdiag output
    [Language]
    dcdiag_connectivity            = passed test connectivity
    dcdiag_services                        = passed test services
    dcdiag_replications            = passed test replications
    dcdiag_advertising                     = passed test advertising
    dcdiag_fsmo                            = passed test fsmocheck
    dcdiag_rid                                     = passed test ridmanager
    dcdiag_machine                         = passed test machineaccount
    dcdiag_frssysvol                       = passed test frssysvol
    dcdiag_sysvolcheck                     = passed test sysvolcheck
    dcdiag_frsevent                        = passed test frsevent
    dcdiag_kccevent                        = passed test kccevent
    dcdiag_dfrsevent                       = passed test dfsrevent
    dcdiag_warning                         = warning
    dcdiag_failed                          = failed

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.net>

SEE ALSO
   Nagios web site <http://www.nagios.org>
   DCDIAG documentation
   <http://technet2.microsoft.com/windowsserver/en/library/f7396ad6-0baa-4e6
   6-8d18-17f83c5e4e6c1033.mspx>

COPYRIGHT
   This program is distributed under the Artistic License.
   <http://www.opensource.org/licenses/artistic-license.php>

VERSION
   Version 1.8, October 2015

CHANGELOG
   changes from 1.7
        - Better handling of multi line output (due to longer domain names for example)
        - Remove --member check as the netdiag tool is not available as of Windows 2008

   changes from 1.6
        - Do not perform RID Manager checks for RODCs (Read-Only Domain Controllers)

   changes from 1.5
        - Windows 2012 server support
        - Use Windows version information directly
        - make localized string checks in lowercase

   changes from 1.4
        - Add command line option 'dfsr'
        - --verbose option to print dcdiag/netdiag commands generated
        - introducing configuration file for handling localized output
        - --config option to specify an alternative location for the configuration file
        - member checks on W2008 systems are not performed due to non-availability of netdiag

   changes from 1.3
        - Windows 2008 support (checks are done in lowercase only)
        - Dropped member test 'trust' as it requires domain admin privileges thus introducing a security weakness.
        - Introducing option 'nokerberos' due to netdiag bug (see Microsoft KB870692)

   changes from 1.2
        - Add command line option 'noeventlog'.

   changes from 1.1
        - Support for Windows 2000 domains
        - Use CRITICAL instead of ERROR

   changes from 1.0
        - remove sysevent test as it can be many other event producers than active directory.

