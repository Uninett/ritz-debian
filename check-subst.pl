
#
# no hash-bang, this is run with "perl script args"
#

# $Id$
#

require 'getopts.pl';

sub read_subst {
    my($f) = @_;
    our(%s_vars);

    open(IN, $f) || die "Could not open $f: $!";
    while(<IN>) {
	if (/.*%([A-Z][^%]*)%.*/) {
	    $s_vars{$1} = 1;
	}
    }
    close(IN);
}

sub read_Makefile {
    my($f) = @_;
    our(%m_var);

    open(IN, $f) || die "Could not open $f: $!";
    while(<IN>) {
	chomp;
	if (/(.*)=.*/) {
	    $m_var{$1} = 1;
	}
    }
    close(IN);
}

#
# Main
#

our($opt_s, $opt_o);
our(%s_vars, %m_vars);

&Getopts("o:s:");

&read_subst($opt_s);
&read_Makefile($opt_o);

my($err) = 0;

foreach my $v (keys %m_vars) {
    if (!defined($s_vars)) {
	printf(STDERR "Variable %s missing from Makefile.inc\n", $v);
	$err = 1;
    }
}
if ($err) {
    printf(STDERR "Please pick settings from new Makefile.inc.dist\n");
}
exit($err);
