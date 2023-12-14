NAME
   check-rsync - Nagios compatible check plugin for rsync checks

SYNOPSIS
   check-rsync [ --capability *rsync capability*[,...] ... ] [ --module
   *rsync module*[,...] ... ] [ --version *rsync version* ] [ --protocol
   *rsync protocol* ] [ --print_capability ] [ --print_module ] [ --rsync
   *rsync path*] [ --verbose ] [ --help ]

DESCRIPTION
   check-rsync is a Nagios NRPE plugin for checking various aspects of rsync
   like version, protocol, capabilities and modules

OPTIONS
   --capability *rsync capability*[,...] ...
       This option specifies the required set of rsync capabilities to check
       for. You can specify several comma separated capabilities for one
       --capability option, as well as several --capability options.
       Optional. Default is no capability check.

   --module *rsync module*[,...] ...
       This option specifies the required set of rsync modules served by the
       local rsync daemon. You can specify several comma separated modules
       for one --module option, as well as several --module options.
       Optional. Default is no module check.

   --version *rsync version*
       This option specifies the minimum required version of the rsync
       program. Optional. Default is no version check.

   --protocol *rsync protocol*
       This option specifies the minimum required version of the rsync
       protocol. Optional. Default is no protocol check.

   --print_capability
       This option instructs check-rsync to print the list of available
       capabilities at the local rsync. Optional. Default output is the
       version and protocol number.

   --print_module
       This option instructs check-rsync to print the list of modules served
       by the local rsync daemon. Optional. Default output is the version
       and protocol number.

   --rsync *rsync path*
       You can use this option to specify the exact location of the rsync
       program. Optional. Default is *rsync* via search path.

   --verbose
       Increases output verbosity for debugging.

   --help
       Produces a help message.

EXAMPLES
    check-rsync

   Prints version and protocol number

    check-rsync --version 3.0.2 --protocol 30

   Prints the rsync version and protocol. Returns CRITICAL if the version is
   lower than *3.0.2* or the protocol is lower than *30*.

    check-rsync --rsync "C:\program files\icw\bin\rsync.exe" --capability "64-bit files,iconv" --print_cap

   Uses *C:\program files\icw\bin\rsync.exe* as the rsync program and prints
   the rsync version, protocol and capabilities available. Returns CRITICAL
   if the capabilities *64-bit files* and *iconv* are not among the
   supported ones.

    check-rsync --module "mirror_a,backup_b" --print_module

   Prints the rsync version, protocol and visible modules served by the
   local daemon. Returns CRITICAL if the modules *mirror_a* and *backup_b*
   are not among the available ones.

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.net>

SEE ALSO
   Nagios web site <http://www.nagios.org>
   Rsync <http://rsync.samba.org>

COPYRIGHT
   This program is distributed under the Artistic License.
   <http://www.opensource.org/licenses/artistic-license.php>

VERSION
   Version 1.0, February 2009

CHANGELOG
   Initial version

