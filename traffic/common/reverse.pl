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
    our(%in_load);		# should be populated from reading
				# a daily report or similar

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

    # Handle popA-popB-2 -> popB-popA-2
    if ($name =~ /^([^-]+)-([^-]+)-([0-9]+)$/) {
        $rn = $2 . "-" . $1 . "-" . $3 . $suf;
    }   
    if (defined($in_load{$rn})) {
        return $rn;
    }   

    # Handle routerA.routerB-2 -> routerB.routerA-2
    if ($name =~ /^([^.]+)\.([^.]+)-([0-9]+)$/) {
	$rn = $2 . "." . $1 . "-" . $3 . $suf;
    # ...or routerA.routerB -> routerB.routerA
    } elsif ($name =~ /^([^.]+)\.([^.]+)$/) {
	$rn = $2 . "." . $1 . $suf;
    }
    if (defined($in_load{$rn})) {
	return $rn;
    }

    # Handle popA-popB -> popB-popA
    if      ($name =~ /^([^-]+)-([^-]+)$/) {
	$rn = $2 . "-" . $1 . $suf;
    }
    if (defined($in_load{$rn})) {
	return $rn;
    }

    # Handle popA-popB2 -> popB-popA2
    if      ($name =~ /^([^-]+)-([^-0-9]+)([0-9]+)$/) {
	$rn = "$2" . "-" . "$1" . "$3" . $suf;
    # or popA-popB-whatever -> popB-popA-whatever
    } elsif ($name =~ /^([^-]+)-([^-]+)(.*)$/) {
	$rn = "$2" . "-" . "$1" . "$3" . $suf;
    }
    if (defined($in_load{$rn})) {
	return $rn;
    }

    if (defined($in_load{$name . $suf})) {
	return $name . $suf . "/i";
    }
    return "$name" . "/i";
}

1;
