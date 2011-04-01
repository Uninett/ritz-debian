#! /usr/bin/perl

# $Id$

# Make a combined index of "daily avg", "daily 98th percentile"
# plus pointers to "current" statistics.

push(@INC, "%LIBDIR%");
use lib qw(%LIBDIR%);

use POSIX qw(strftime);
use Zino::conn qw(read_desc select_types %fullname %ports);

require 'getopts.pl';

require 'date.pl';
require 'search.pl';


sub dayreport_ports {
    my(@ports);
    my($d) = &date_to_datespec(&yesterday(), "day");
    my($dn) = &find_day_report_dir($d);
    my($f) = $dn . "/traffic";
    open(REP, $f) || return;
    while(<REP>) {
	chomp;
	@_ = split;
	push(@ports, $_[0]);
    }
    close(REP);
    return @ports;
}

sub err {
    my($e) = @_;
    printf STDERR "%s\n", $e;
    exit 1;
}

sub read_template {
    my($f) = @_;
    our(%select, %title, @group_order, @head_lines, @tail_lines);
    our(%text, %catplot);

    open(IN, "$f") || die "Could not open $f: $!";
    while(<IN>) {
	chomp;
	@_ = split(/\s+/, $_, 2);
	if (/^group/) {
	    my($group) = $_[1];
	    while ($_ ne "") {
		$_ = <IN>;
		chomp;
		@_ = split(/\s+/, $_, 2);
		if (/^select/) {
		    $select{$group} = $_[1];
		} elsif (/^title/) {
		    $title{$group} = $_[1];
		} elsif (/^catplot/) {
		    $catplot{$group} = $_[1];
		} elsif (/^text/) {
		    my($marker) = @_[1];
		    while($_ ne $marker) {
			$_ = <IN>;
			chomp;
			if ($_ ne $marker) {
			    $text{$group} .= $_ . "\n";
			}
		    }
		} elsif (/^$/) {
		    next;
		} else {
		    &err("Unrecognized group line: $_");
		}
	    }
	}
	if (/^order/) {
	    @group_order = split(/,/, $_[1]);
	}
	if (/^head/) {
	    my($marker) = $_[1];
	    while ($_ ne $marker) {
		$_ = <IN>;
		chomp;
		if ($_ ne $marker) {
		    push(@head_lines, $_);
		}
	    }
	}
	if (/^tail/) {
	    my($marker) = $_[1];
	    while($_ ne $marker) {
		$_ = <IN>;
		chomp;
		if ($_ ne $marker) {
		    push(@tail_lines, $_);
		}
	    }
	}
    }
    close(IN);
}

#
# Convert some common .se/.no letters into html equivalents
#

sub htmlize {
    my($s) = @_;

    $s =~ s/&/&amp;/g;
    $s =~ s/\x{E4}/&auml;/g;
    $s =~ s/\x{C4}/&Auml;/g;
    $s =~ s/\x{F6}/&ouml;/g;
    $s =~ s/\x{D6}/&Ouml;/g;
    $s =~ s/\x{E5}/&aring;/g;
    $s =~ s/\x{C5}/&Aring;/g;
    $s =~ s/\x{F8}/&oslash;/g;
    $s =~ s/\x{D8}/&Oslash;/g;
    $s =~ s/\x{E9}/&eacute;/g;
    $s =~ s/\x{C9}/&Eacute;/g;

    return $s;
}

sub active_links {
    my($name) = @_;
    our(%ports, %active_port);
    my(@ports);
    
    foreach my $p (@{ $ports{$name} }) {
	if (defined($active_port{$p})) {
	    push(@ports, $p);
	}
    }
    return @ports;
}

sub emit_html {
    our(%select, %title, @group_order, @head_lines, @tail_lines, %text);
    our(%fullname, %catplot);

    foreach my $l (@head_lines) {
	printf("%s\n", $l);
    }
    foreach my $g (@group_order) {
	if (defined($catplot{$g})) {
	    printf("<table border=\"0\" width=\"100%\">\n");
	    printf("  <tr>\n");
	    printf("    <td width=\"50%\"><h3>%s</h3></td>\n",
		   &htmlize($title{$g}));
	    printf("    <td width=\"5%\">&nbsp;</td>\n");
	    printf("    <td width=\"8%\">&nbsp;</td>\n");
	    printf("    <td width=\"8%\"><a href=\"/stat-q/r-all?q=all&amp;");
	    printf("name=%s\">Current</a></td>\n", $catplot{$g});
	    printf("    <td width=\"29%\">&nbsp;</td>\n");
	    printf("  </tr>\n");
	    printf("</table>\n");
	} else {
	    printf("<h3>%s</h3>\n", &htmlize($title{$g}));
	}
	if (defined($text{$g})) {
	    printf("<p>%s</p>\n", &htmlize($text{$g}));
	}
	# if there are no selection expression, skip table
	if (!defined($select{$g})) { next; }
	printf("<table border=\"0\" width=\"100%\">\n");
	my(@names);
	@names = &select_types($select{$g}, keys %fullname);
	foreach my $n (sort @names) {
	    printf("  <tr>\n    <td width=\"50%\">%s</td>\n",
		   &htmlize($fullname{$n}));
	    printf("    <td width=\"5%\">");
	    printf("<a href=\"98p/%s.png\">%s</a></td>\n",
		   $n, "98%");
	    printf("    <td width=\"8%\">");
	    printf("<a href=\"avg/%s.png\">%s</a></td>\n",
		   $n, "Average");
	    printf("    <td width=\"8%\">");
	    printf("<a href=\"/stat-q/r-all?q=all&amp;");
	    printf("name=%s\">%s</a></td>\n",
		   $n, "Current");
	    my($i) = 0;
	    printf("    <td>Links: ");
	    foreach $l (&active_links($n)) {
		printf("    <a href=\"/stat-q/r-all?q=all&amp;name=%s\">",
		       $l);
		printf("%d</a>", ++$i);
	    }
	    printf("</td>\n");
	    printf("  </tr>\n");
	}
	printf("</table>\n\n");
    }
    my $ms;
    $ms =  '^(Uppdaterad|Updated|Oppdatert): ';
    $ms .= '\d+-\d+-\d+ \d+:\d+:\d+$';
    foreach my $l (@tail_lines) {
	if ($l =~ /$ms/o) {
	    printf("%s: %s\n", $1,
		   strftime("%Y-%m-%d %H:%M:%S", localtime($^T)));
	    next;
	}
	printf("%s\n", $l);
    }
}


#
# Main
#

&Getopts("c:t:");
if (! -f $opt_c) {
    &err("description file (-c file) not readable: $opt_c");
}
&read_desc($opt_c);

if (! -f $opt_t) {
    &err("HTML template file (-t file) not readable: $opt_t");
}
@ports = &dayreport_ports();
foreach $p (@ports) {
    $active_port{$p} = 1;
}


&read_template($opt_t);
&emit_html();
