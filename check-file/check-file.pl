#!/usr/bin/perl
#perl2exe_include "overloading.pm";
#
# check-file.pl - Nagios compatible check plugin for 
#  file/directory count, size and age checks

use strict;
use warnings;
use Getopt::Long;
use File::Find;
use File::stat;
use Time::ParseDate;

our $VERSION = "1.5";

our $OK = 0;
our $WARNING = 1;
our $CRITICAL = 2;
our $UNKNOWN = 3;

our %status_text = (
	$OK => "OK",
	$WARNING => "WARNING",
	$CRITICAL => "CRITICAL",
	$UNKNOWN => "UNKNOWN"
);

our $numfiles = 0;
our $numdelete = 0;
our $numall = 0;

our @targets = ();
our $warning = undef;
our $critical = undef;
our @filters = ();
our $delete = 0;
our $verbose = 0;
our $rootonly = 0;
our $compare = 'gt'; # type of comparison operator for critical/warning thresholds
our $help = 0;

GetOptions (
	"target=s" => \@targets,
	"warning=i" => \$warning,
	"critical=i" => \$critical,
	"verbose" => \$verbose,
	"rootonly" => \$rootonly,
	"compare=s" => sub { $compare = lc $_[1] },
	"delete" => \$delete,
	"filter=s" => \@filters,
	"help" => sub { PrintUsage() }
) || PrintUsage();

ExitProgram ($UNKNOWN, "No targets are specified.") if not scalar @targets;
grep (/$compare/, split (',', 'eq,ne,gt,ge,lt,le')) || ExitProgram($UNKNOWN, "Unsupported compare operator: $compare");

@targets = split(/,/,join(',', @targets));
@filters = split(/,/,join(',', @filters));

our @files = ();

foreach my $target (@targets)
{
	-e $target || ExitProgram($UNKNOWN, "Target does not exist");
	
	-d $target && do
		{
			if ($rootonly)
			{
				opendir(DIR, $target) || ExitProgram($UNKNOWN, "Can't opendir $target: $!");
				my @rootfiles = grep { -f "$target/$_" } readdir(DIR);
				closedir DIR;
			
				foreach (@rootfiles) {
					AddFile("$target/$_");
				}		
			} else {
				find (\&wanted, $target);
			};
			next;
		};
			
	-f $target && do
		{
			AddFile($target);
			next;
		} 
}
	
my $message = "$numfiles files " . (($numfiles < $numall) ? "out of $numall " : "") . "to consider " . (($delete and $numdelete) ? ", $numdelete deleted.":"");

# add performance data
$message .= "|'selected files'=$numfiles;" . (defined $warning ? $warning : "") . ";" . (defined $critical ? $critical : "") . ";" .
	" 'all files'=$numall 'deleted files'=$numdelete";

defined $critical && IsThreshold($numfiles, $critical, $compare) && ExitProgram ($CRITICAL, $message);
defined $warning && IsThreshold($numfiles, $warning, $compare) && ExitProgram ($WARNING, $message);
ExitProgram ($OK, $message);
	
#### SUBROUTINES ####
sub wanted 
{
	-f $File::Find::name && AddFile($File::Find::name);
}

##### AddFile #####
sub AddFile
{
	$numall++;
	
	my $file = shift;
	my $infilter = 0;
	my $sb = stat($file);
	my $lage;
	
	foreach my $filter (@filters)
	{
		# filters consist of three fields separated by white space
		my ($filter_type, $filter_op, $filter_val) = ($filter =~ /(\S+)\s+(\S+)\s+(.*)/);
		($filter_type && $filter_op && $filter_val) 
			|| ExitProgram($UNKNOWN, "A filterspec should consist of three fields : $filter");
		
		$filter_type = lc $filter_type;
		$filter_op = lc $filter_op;
		
		$filter_type eq 'name' && $filter_op eq 'match' && $file =~ /$filter_val/ && $infilter++ && next;
		$filter_type eq 'size' &&  IsThreshold($sb->size, $filter_val, $filter_op) && $infilter++ && next;
		$filter_type eq 'age' && ($lage = parsedate($filter_val)) && IsThreshold($sb->mtime, $lage, $filter_op) && $infilter++ && print "ok " && next;		
	}
	
	if ($infilter == scalar @filters) { # Are all filters  passed through ??
		$delete && (unlink $file) && $numdelete++; # delete function
		print "$file - " . $sb->size . " bytes, modified at " . localtime($sb->mtime) . "\n" if $verbose;
		$numfiles++;	
	}
}

##### IsThreshold #####
sub IsThreshold
{
	my ($value, $threshold, $operand) = @_;
	
	return
		($operand eq 'eq' and $value == $threshold) || 
		($operand eq 'ne' and $value != $threshold) ||
		($operand eq 'gt' and $value > $threshold) ||
		($operand eq 'ge' and $value >= $threshold) || 
		($operand eq 'lt' and $value < $threshold) ||
		($operand eq 'le' and $value <= $threshold);
}

##### PrintUsage #####
sub PrintUsage
{
	print "
Usage:
    check-file --target file/directory[,file/directory]...]] [[--target ...]
    ... ] --filter filterspec[,filterspec]...]] [[--filter ...] ... ]
    [--delete] [--warning threshold] [--critical threshold] [--rootonly]
    [--compare operator] [--verbose] [--help]

Options:
    --target file/directory[,file/directory]...]] [[--target ...] ... ]
        This option specifies targets to check. A target can be a simple
        file or a recursive list of files in a directory. You can specify
        several comma separated targets for one --target option, as well as
        several --target options. At least one is required.

    --filter filterspec[,filterspec]...]] [[--filter ...] ... ]
        Specify filters to select files. A filterspec consist of three
        fields: filter name, operator and value. You can specify several
        comma separated filters for one --filter option, as well as several
        --filter options. Defaults to all files if no filter is defined.
        List of filters available:

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
         count \"days\"
         count \"weeks\"
         count \"months\"
         count \"years\"
         hh:mm:ss[.ddd] 
         hh:mm 
         hh:mm[AP]M
         hh[AP]M
         count \"minutes\"
         count \"seconds\"
         count \"hours\"
         \"+\" count units

        See the Time::ParseDate documentation for a complete list of
        supported formats.

    --delete
        Delete selected files. Optional.

    --warning threshold
        Return WARNING if the number of files to consider is more than
        threshold. Optional.

    --critical threshold
        Return CRITICAL if the number of files to consider is more than
        threshold. Optional.

    --rootonly
        Limit file search to the top level of targets. No recursive
        traversal of directories.

    --compare operator
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

";
	
}

##### ExitProgram #####
sub ExitProgram
{
	my ($exitcode, $message) = @_;
	
	my $lcomp = "FILE";
	print "$lcomp $status_text{$exitcode} - $message";
	exit ($exitcode);
}

__END__

=head1 NAME

B<check-file> - Nagios compatible check plugin for file/directory count, size and age checks

=head1 SYNOPSIS

B<check-file> B<--target> I<file/directory>[,I<file/directory>]...]] [[--target ...] ... ] B<--filter> I<filterspec>[,I<filterspec>]...]] [[--filter ...] ... ] [B<--delete>] [B<--warning> I<threshold>] [B<--critical> I<threshold>] [B<--rootonly>] [B<--compare> I<operator>] [B<--verbose>] [B<--help>]

=head1 DESCRIPTION

B<check-file> is a Nagios NRPE plugin for checking simple files or files in directories by using various types of filters like file count, size, age or name match.

=head1 OPTIONS

=over 4 

=item B<--target> I<file/directory>[,I<file/directory>]...]] [[--target ...] ... ]

This option specifies targets to check. A target can be a simple file or a recursive list of files in a directory. You can specify several comma separated targets for one --target option, as well as several --target options. At least one is required.

=item B<--filter> I<filterspec>[,I<filterspec>]...]] [[--filter ...] ... ]

Specify filters to select files. A filterspec consist of three fields: filter name, operator and value. You can specify several comma separated filters for one --filter option, as well as several --filter options. Defaults to all files if no filter is defined. List of filters available:

 Filter Name     Valid Operators           Valid Value(s)
 -----------     ---------------           --------------
 NAME            match                     a regular expression
 SIZE            eq, ne, gt, lt, ge, le    file size in bytes
 AGE             eq, ne, gt, lt, ge, le    file age (see below)

check-file uses perl module B<Time::ParseDate> for parsing of the file age. A short sample of supported formats is

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

See the Time::ParseDate documentation for a complete list of supported formats.

=item B<--delete>

Delete selected files. Optional.

=item B<--warning> I<threshold>

Return WARNING if the number of files to consider is more than I<threshold>. Optional.

=item B<--critical> I<threshold>

Return CRITICAL if the number of files to consider is more than I<threshold>. Optional.

=item B<--rootonly>

Limit file search to the top level of targets. No recursive traversal of directories.

=item B<--compare> I<operator>

Specify the type of comparison operator for threshold checks. Optional. Available values are:

 'eq'  equal to
 'ne'  not equal
 'gt'  greater than (default!)
 'ge'  greater or equal
 'lt'  less than
 'le'  less or equal

=item B<--verbose>

Increases output verbosity for debugging.

=item B<--help>

Produces a help message.

=back

=head1 EXAMPLES

 check-file --target c:\temp --warn 100 --critical 250

Counts all files in the directory I<c:\temp>. Returns WARNING for more than 100 files or CRITICAL for more than 250 files.

 check-file -t c:\backup\db1,c:\backup\db2 --filter "age ge -24 hours" --critical 0

Returns CRITICAL if at least one of the files I<c:\backup\db1> and I<c:\backup\db2> is 24 hours old.

 check-file --target "c:\logfiles" --filter "size gt 10485760","age lt -15 minutes" --filter "name match \.log$" --delete --warning 10 --critical 50

Counts and deletes files with B<.log> extension, which are modified within last 15 minutes AND are larger than 10 MB. Returns WARNING if there are more than 10 files meeting the criteria, CRITICAL for more than 50 files.

=head1 EXIT VALUES

 0 OK
 1 WARNING
 2 CRITICAL
 3 UNKNOWN

=head1 AUTHOR

Tevfik Karagulle L<http://www.itefix.net>

=head1 SEE ALSO

=over 4

=item Nagios web site L<http://www.nagios.org>

=item Regular Expressions L<http://en.wikipedia.org/wiki/Regular_expression>

=item Perl module Time::ParseDate L<http://search.cpan.org/~muir/Time-modules-2006.0814/lib/Time/ParseDate.pm>

=back

=head1 COPYRIGHT

This program is distributed under the BSD 2- License. L<https://opensource.org/license/bsd-2-clause/>

=head1 VERSION

Version 1.5, May 2011

=head1 CHANGELOG

=over 4

=item changes from 1.4

 - renamed as check-file
 - produce performance data output according to guidelines

=item changes from 1.3

 - check for non-existing targets (credits -ebo-)
 - bugfix - "Can't call method "mtime" (credits -ebo-)

=item changes from 1.2

 - use Time::ParseDate for more flexible file age parsing
 - Bug fix - Don't treat directories as files as well

=item changes from 1.1

 - Complete redesign of filter option. Options size and age are implemented as filters.
 - Option --rootonly
 - better performance
 - Bug fix! Drop subdirectories from counting.

=item changes from 1.0

 - Add options --filter and --delete. More verbose output.

=back

=cut
