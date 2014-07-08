# Try to swap around the names, in sequence:
# whatever-phy* -> whatever(rev)-phy* (retain -phy* suffix)
# whatever-l2vpn-* -> whatever(rev)-l2vpn-* (retain -l2vpn* suffix)
# xx.yy-2 -> yy.xx-2 (xx and yy may contain hyphens)
# xx.yy -> yy.xx
# xx-nn  -> nn-xx
# xx-nn2 -> nn-xx2
# xx-nn-t -> nn-xx-t
# and check if the result exists
# Otherwise return xx-nn/i ("use input value")

sub rev_name {
    my($name) = @_;
    my($rn, $suf);

    $suf = "";
    if ($name =~ /^(.*)-l3$/) {
	$name = $1;
	$suf = "-l3";
    } elsif ($name =~ /^(.*)-l2vpn(.*)$/) {
	$name = $1;
	$suf = "-l2vpn" . $2;
    } elsif ($name =~ /^(.*)-phy(.*)$/) {
	$name = $1;
	$suf = "-phy" . $2;
    }

    if ($name =~ /^([^.]+)\.([^.]+)-([0-9]+)$/) {
	$rn = $2 . "." . $1 . "-" . $3 . $suf;
    } elsif ($name =~ /^([^.]+)\.([^.]+)$/) {
	$rn = $2 . "." . $1 . $suf;
    }
    if (defined($in_load{$rn})) {
	return $rn;
    }
    if      ($name =~ /^([^-]+)-([^-]+)$/) {
	$rn = $2 . "-" . $1 . $suf;
    }
    if (defined($in_load{$rn})) {
	return $rn;
    }
    if      ($name =~ /^([^-]+)-([^-0-9]+)([0-9]+)$/) {
	$rn = "$2" . "-" . "$1" . "$3" . $suf;
    } elsif ($name =~ /^([^-]+)-([^-]+)(.*)$/) {
	$rn = "$2" . "-" . "$1" . "$3" . $suf;
    }
    if (defined($in_load{$rn})) {
	return $rn;
    }
    return "$name" . "/i";
}

1;
