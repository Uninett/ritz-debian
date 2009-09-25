#! %PERL%
#
# $Id$
#
# See POD at bottom of file for more info about this script
# or run 'find_err_dev.pl --help'
#
# Written by Thomas Adamcik 2008

#
# Copyright (c) 2009
#      UNINETT and NORDUnet.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY UNINETT AND NORDUnet ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL UNINETT OR NORDUnet OR
# THEIR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#


use strict; 

use warnings;
use YAML qw/Dump LoadFile DumpFile/;
use Getopt::Long;
use Pod::Usage;

# Following values can be tweaked
my $n_dev        = 3;   # Number of standard deviations we can be off
my $min_value    = 0.2; # Min value (if standard deviation = 0)
my $storage_file = "%TOPDIR%/data/last_dev.yaml";

# Leave these as they are :)
my $help = 0;
my $diff = 0;
my @exclude = ();

GetOptions("deviations=i" => \$n_dev,
           "min-value=i"  => \$min_value,
           "help"         => \$help,
           "diff"         => \$diff,
           "previous=s"   => \$storage_file,
           "exclude=i"    => \@exclude);

pod2usage(-exitstatus => 1, -verbose => 2) if $help;

my $stat;   # Hashref to collect stats
my %seen;   # Hash to keep track of which files have been processed
my %ifaces; # Hash to keep track if ifaces
my $previous;
my $problem;

my $map = {
    'errors.perc' => [
        'inerr hrs >x%  1.0',
        'inerr hrs >x%  0.1',
        'inerr hrs >x%  .01',
        'in % Errs',
        'in % CRC',
        'in % Frm',
        'in % Abrt',
        'in % Ign',
        'out Reset',
        'out Disc%',
        'peak Disc%',
        'iftype',
     ],
    'ether_errs.perc' => [
        'in %  Errs',
        'in %  CRC',
        'in %  Frm',
        'in %  Runts',
        'in %  Giant',
        'in %  Ignor',
        'out % Errs',
        'out % Disc',
        'out % Colls',
    ],
};


    # Remove indicate excluded columns
for my $field (@exclude) {
    $map->{'errors.perc'}->[$field] = 0;
    $map->{'ether_errs.perc'}->[$field] = 0;
}

my @files = sort(@ARGV);

die "No files supplied" if not scalar @files;

my $errtype;

for my $file (@files) {
    next if defined $seen{$file};
    $seen{$file} = 1;

    open FH, $file
        or warn "Could not open $file: $!" and next;

    $file =~ m/.*\/(.*)$/;
    $errtype = $1;
    my %tmp_ifaces;

    while (<FH>) {
        chomp;
        my ($name, @rest) = split /\s+/;

        $tmp_ifaces{$name} = 1;

        my $count = 0;
        for my $x (@rest) {
            next if not $map->{$errtype}->[$count];

            # http://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Algorithm_III
            #
            # n = 0
            # mean = 0
            # S = 0
            #
            # foreach x in data:
            #   n = n + 1
            #   delta = x - mean
            #   mean = mean + delta/n
            #   // This expression uses the new value of mean:
            #   S = S + delta*(x - mean)
            # end for
            #
            # variance = S/(n - 1)
            # dev = sqrt(variance)

            my $delta =
		$x - ($stat->{$errtype}->{$name}->{$count}->{'mean'}||0);

            $stat->{$errtype}->{$name}->{$count}->{'n'}    += 1;
            $stat->{$errtype}->{$name}->{$count}->{'mean'} +=
		$delta / $stat->{$errtype}->{$name}->{$count}->{'n'};
            $stat->{$errtype}->{$name}->{$count}->{'S'}    +=
		$delta * ($x - $stat->{$errtype}->{$name}->{$count}->{'mean'});
            $stat->{$errtype}->{$name}->{$count}->{'last'}  = $x;

            $count++;
        }
    }

    $ifaces{$errtype} = \%tmp_ifaces;

    close FH
        or warn "Could not close $file: $!";
}

# Loop over hash adding 'ok', 'var' and 'dev'
for my $type (keys %$stat) {
    for my $iface (keys %{$stat->{$type}}) {
        # Ignore ifaces that are not in the final file
        next if not defined $ifaces{$type}->{$iface};

        while (my ($col, $val) = each %{$stat->{$type}->{$iface}}) {
            if ($val->{'n'} > 1) {
                $val->{'var'} = $val->{'S'} / ($val->{'n'} - 1);
                $val->{'dev'} = sqrt($val->{'var'});

                if (
		    # We only check the upper bound as lower error rates than
		    # average is ok :)
		    $val->{'last'} <= $val->{'mean'} + $n_dev * $val->{'dev'}
		    ||
		    ($val->{'last'} < $min_value &&  $val->{'dev'} == 0)
		    )
		{
		    $val->{'ok'} = 1;
                } else {
		    $val->{'ok'} = 0;
		    push(@{$problem->{$iface}},
			 {($map->{$type}->[$col] || $col) => $val->{'last'}});
                }
            }
        }
    }
}

if ($diff) {
    my %header_printed;
    my $new_problems = '';
    my $resolved_problems = '';

    if (-f $storage_file) {
        $previous = LoadFile($storage_file);
    } else {
        $previous = {};
    }

    my %all_ifaces;
    # Determine the union of previous problem ifaces and current ifaces
    for my $iface (keys %{$problem}) {
        $all_ifaces{$iface} = 1;
    }
    for my $iface (keys %{$previous}) {
        $all_ifaces{$iface} = 1;
    }

    # Start checking all ifaces
    for my $iface (sort keys %all_ifaces) {
        my %resolved;
        my %new;

        if (defined ($previous->{$iface})) {
            # Add previous problems to state so that we can diff
            for my $p (@{$previous->{$iface}}) {
                my ($col, $val) = %$p;
                $resolved{$col} = 1;
            }
        }

        if (defined ($problem->{$iface})) {
            for my $p (@{$problem->{$iface}}) {
                my ($col, $val) = %$p;
                if (defined $resolved{$col}) {
                    # Remove persisting problems
                    delete $resolved{$col};
                } else {
                    $new{$col} = $val;
                }
            }
        }

        if (keys(%new) || keys(%resolved)) {

            if (keys(%new)) {
                $new_problems .=
		    sprintf "\t%20.20s:", $iface;
                $new_problems .=
		    join (', ',  map qq('$_': $new{$_}), keys(%new)). "\n";
                print header_line($errtype)
		    unless $header_printed{$errtype}++;
                print map {errs_line ($errtype, $iface, \%new)} (keys %new)[0];
            }
            if (keys(%resolved)) {
                $resolved_problems .=
		    sprintf "\t%20.20s:", $iface;
                $resolved_problems .=
		    join (', ',  map qq('$_'), keys %resolved). "\n";
            }
        }
    }

    #print "New deviations:\n",      $new_problems      if $new_problems;
    print "\nResolved deviations:\n", $resolved_problems
	if $resolved_problems;

    # Print yaml of stats to storage_file
    DumpFile($storage_file, $problem) ||
	warn "Could not DumpFile $storage_file: $!";
} else {
    # Print yaml of stats to STDOUT
    Dump($problem) || warn "Could not Dump: $!";
}

sub header_line {
    my ($type) = @_;
    my %header_format = 
        (
         'errors.perc'     =>
	 "Interface                inerr hrs >x% ------------ in % -----------  -- out ----\n".
	 "                           1.0 0.1 .01  Errs   CRC   Frm  Abrt   Ign  Reset Disc%\n",
         'ether_errs.perc' =>
	 "Interface                  --------------  in % --------------  ----- out % -----\n".
	 "                           Errs   CRC Frame Runts Giant Ignor   Errs  Disc Colls\n",
        );
    return $header_format{$type};
        
}

sub errs_line {
    my ($type, $intf, $cols) = @_;
    my @errs_cols = @{$map->{$type}};

    my %line_format = 
        (
         'errors.perc'     =>
	 "%-25.25s  %3s %3s %3s %5s %5s %5s %5s %5s  %5s %5s\n",
         'ether_errs.perc' =>
	 "%-25.25s  %5s %5s %5s %5s %5s %5s  %5s %5s %5s\n",
        ); 
        return(sprintf($line_format{$type}, $intf,
		       map {defined $cols->{$_} ?
				$cols->{$_} : ' '}
		       @errs_cols));
}

__END__

=head1 NAME

find-err-dev.pl - ...

=head1 SYNOPSIS

find-err-dev.pl [options] files

=head1 OPTIONS

=over

=item B<--deviation> B<<value>>

Sets factor for how many standard deviations the measured value may be
off relative to the average before being flagged.  The default value
is 3.

=item B<--min-value> B<<value>>

If the standard deviation is zero, we will compare the actual value
measured with this threshold, and any measurement over this threshold
will be flagged as a deviation.

The default treshold / minimum value is 0.2.

=item B<--exclude> B<<column-no>>

Columns from input file to exclude, not counting the logical port
name column, given by their coloumn number.  This option may be
repeated, and the coloumns to exclude will accumulate.

=item B<--help>

Shows this help message.

=item B<--diff>

Produce a diff against the previous results.

=item B<--previous> B<<file>>

Where to store the previous results, so that the recent result
can be compared to the historical values.  The default value
is %TOPDIR%/data/last_dev.yaml.

=back

=head1 DESCRIPTION

This tool is designed to assist in finding changes in daily error
statistics from Zino. To keep things simple this program knows very
little about the report format, it simply accepts a space/tab-delimted
file with a logical interface name in the first coloumn, and error
rates / percentages in the following columns.  This tool looks at the
last of the reports given, and compares its values to the averages and
standard deviations computed over all of the reports given, and uses
the values given in the B<--deviation> and B<--min-value> options to
decide which of the values in the last report to mark as a deviation.

  Chebyshev's inequality proves that in any data set, nearly
  all of the values will be close to the mean value, where the
  meaning of "close to" is specified by the standard
  deviation. Chebyshev's inequality entails that for (nearly)
  all random distributions, not just normal ones, we have the
  following weaker bounds:

  50% of the values are within sqrt(2) standard deviations from the mean.
  75% of the values are within 2 standard deviations from the mean.
  89% of the values are within 3 standard deviations from the mean.
  94% of the values are within 4 standard deviations from the mean.
  96% of the values are within 5 standard deviations from the mean.
  97% of the values are within 6 standard deviations from the mean.
  98% of the values are within 7 standard deviations from the mean.

  (Source http://en.wikipedia.org/wiki/Standard_deviation)

For the sake of making the report understandable we use the following
mapping for the report columns in the file types we know about.

=over

=item B<errors>

 inerr hrs >x% --------- in % ---------  -- out -----peak-
   1.0 0.1 .01 Errs  CRC  Frm Abrt  Ign  Reset Disc% Disc% iftype
    xx  xx  xx xxxx xxxx xxxx xxxx xxxx  xxxxx xxxxx xxxxx xxxxxx

=item B<ether_errs>

 --------------  in % --------------  ----- out % -----
  Errs   CRC Frame Runts Giant Ignor   Errs  Disc Colls
 xxxxx xxxxx xxxxx xxxxx xxxxx xxxxx  xxxxx xxxxx xxxxx

=back

This script is usually handled by a small shell script wrapper which
encapsulates the intended use of this script.

=cut
