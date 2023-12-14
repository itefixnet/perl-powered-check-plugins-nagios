NAME
   check-file - Nagios compatible check plugin for file/directory count,
   size and age checks

SYNOPSIS
   check-file --target *file/directory*[,*file/directory*]...]] [[--target
   ...] ... ] --filter *filterspec*[,*filterspec*]...]] [[--filter ...] ...
   ] [--delete] [--warning *threshold*] [--critical *threshold*]
   [--rootonly] [--compare *operator*] [--verbose] [--help]

DESCRIPTION
   check-file is a Nagios NRPE plugin for checking simple files or files in
   directories by using various types of filters like file count, size, age
   or name match.

OPTIONS
   --target *file/directory*[,*file/directory*]...]] [[--target ...] ... ]
       This option specifies targets to check. A target can be a simple file
       or a recursive list of files in a directory. You can specify several
       comma separated targets for one --target option, as well as several
       --target options. At least one is required.

   --filter *filterspec*[,*filterspec*]...]] [[--filter ...] ... ]
       Specify filters to select files. A filterspec consist of three
       fields: filter name, operator and value. You can specify several
       comma separated filters for one --filter option, as well as several
       --filter options. Defaults to all files if no filter is defined. List
       of filters available:

        Filter Name     Valid Operators           Valid Value(s)
        -----------     ---------------           --------------
        NAME            match                     a regular expression
        SIZE            eq, ne, gt, lt, ge, le    file size in bytes
        AGE             eq, ne, gt, lt, ge, le    file age (see below)

       check-file uses perl module Time::ParseDate for parsing of the file
       age. A short sample of supported formats is

        Dow, dd Mon yy
        Dow, dd Mon yyyy
        Dow, dd Mon
        dd Mon yy
        count "days"
        count "weeks"
        count "months"
        count "years"
        hh:mm:ss[.ddd] 
        hh:mm 
        hh:mm[AP]M
        hh[AP]M
        count "minutes"
        count "seconds"
        count "hours"
        "+" count units

       See the Time::ParseDate documentation for a complete list of
       supported formats.

   --delete
       Delete selected files. Optional.

   --warning *threshold*
       Return WARNING if the number of files to consider is more than
       *threshold*. Optional.

   --critical *threshold*
       Return CRITICAL if the number of files to consider is more than
       *threshold*. Optional.

   --rootonly
       Limit file search to the top level of targets. No recursive traversal
       of directories.

   --compare *operator*
       Specify the type of comparison operator for threshold checks.
       Optional. Available values are:

        'eq'  equal to
        'ne'  not equal
        'gt'  greater than (default!)
        'ge'  greater or equal
        'lt'  less than
        'le'  less or equal

   --verbose
       Increases output verbosity for debugging.

   --help
       Produces a help message.

EXAMPLES
    check-file --target c:\temp --warn 100 --critical 250

   Counts all files in the directory *c:\temp*. Returns WARNING for more
   than 100 files or CRITICAL for more than 250 files.

    check-file -t c:\backup\db1,c:\backup\db2 --filter "age ge -24 hours" --critical 0

   Returns CRITICAL if at least one of the files *c:\backup\db1* and
   *c:\backup\db2* is 24 hours old.

    check-file --target "c:\logfiles" --filter "size gt 10485760","age lt -15 minutes" --filter "name match \.log$" --delete --warning 10 --critical 50

   Counts and deletes files with .log extension, which are modified within
   last 15 minutes AND are larger than 10 MB. Returns WARNING if there are
   more than 10 files meeting the criteria, CRITICAL for more than 50 files.

EXIT VALUES
    0 OK
    1 WARNING
    2 CRITICAL
    3 UNKNOWN

AUTHOR
   Tevfik Karagulle <http://www.itefix.net>

SEE ALSO
   Nagios web site <http://www.nagios.org>
   Regular Expressions <http://en.wikipedia.org/wiki/Regular_expression>
   Perl module Time::ParseDate
   <http://search.cpan.org/~muir/Time-modules-2006.0814/lib/Time/ParseDate.p
   m>

COPYRIGHT
   This program is distributed under the BSD 2- License.
   <https://opensource.org/license/bsd-2-clause/>

VERSION
   Version 1.5, May 2011

CHANGELOG
   changes from 1.4
        - renamed as check-file
        - produce performance data output according to guidelines

   changes from 1.3
        - check for non-existing targets (credits -ebo-)
        - bugfix - "Can't call method "mtime" (credits -ebo-)

   changes from 1.2
        - use Time::ParseDate for more flexible file age parsing
        - Bug fix - Don't treat directories as files as well

   changes from 1.1
        - Complete redesign of filter option. Options size and age are implemented as filters.
        - Option --rootonly
        - better performance
        - Bug fix! Drop subdirectories from counting.

   changes from 1.0
        - Add options --filter and --delete. More verbose output.

