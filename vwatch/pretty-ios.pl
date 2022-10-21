#
# $Id$
#

# Prettyprint/abbreviate "system description",
# leave essential information only for those variants
# we have been tought to condense.

sub pretty_ios_desc {
    my($desc) = @_;

    if ($desc =~ /NX-OS\(tm\) ([^,]*), .*Version ([^,]*), .*/) {
	$desc = "Cisco-NX-OS $2 $1";
    }
    if ($desc =~ /IOS XR.*Version ([^\[]*).*/) {
	$desc = "Cisco-IOS-XR $1";
    }
    if ($desc =~ /IOS.*\(([^\)]+)\), Version ([^,\n]+),/) {
	$desc = "Cisco-IOS $2 $1";
    }
    if ($desc =~ /IOS.*\(([^\)]+)\),.*Version ([^ ]+) /) {
	$desc = "Cisco-IOS $2 $1";
    }
    if ($desc =~ /GS.*\(([^\)]+)\), Version ([^,]+),/) {
	$desc = "Cisco-IOS $2 $1";
    }
    if ($desc =~ /Cisco ONS ([^ ]+) ([^ ]+) .*/) {
	$desc = "Cisco $2 ONS-$1";
    }
    if ($desc =~ /.*Cisco Catalyst Operating.*, Version (\d+.\d+\(\d+\)).*/) {
	$desc = "Cisco CatOS $1";
    }
    return $desc;
}

sub pretty_arista_desc {
    my($desc) = @_;

    if ($desc =~ /Arista Networks EOS version ([^ ]+) running on an Arista Networks ([^ ]+)/) {
	$desc = "Arista-EOS $1 $2";
    }
    return $desc;
}

sub pretty_hp_desc {
    my($desc) = @_;
    
    if ($desc =~ /(HP[0-9]+[A-Z]) .*\(([^\)]+)\), revision ([^,]+),/) {
	$desc = "$3 $1 $2";
    }
    return $desc;
}

sub pretty_junos_desc {
    my($desc) = @_;

    if ($desc =~
	/Juniper Networks, Inc. \S+ \[([^ ]+)\] .* kernel JUNOS ([^ ,]+)[, ].*/) {
	$desc = "JunOS $2 " . lc($1);
} elsif ($desc =~
	/Juniper Networks, Inc. ([^ ]+) .*kernel JUNOS ([^ ,]+)[, ].*/) {
	$desc = "JunOS $2 " . lc($1);
    }
    return $desc;
}

sub pretty_procurve {
    my($desc) = @_;

    if ($desc =~ /ProCurve ([^ ]+) [^ ]+ ([^ ]+), revision ([^ ]+), ROM ([^ ]+) .*/) {
	$desc = "HP-ProCurve $1 $2 $3 ROM $4";
    } elsif ($desc =~ /^HP ([^ ]+) ([^ ]+) Switch, revision ([^ ,]+), ROM ([^ ]+).*/) {
	$desc = "HP-ProCurve $1 $2 $3 ROM $4";
    }
    return $desc;
}

sub pretty_desc {
    my($desc) = @_;

    $desc = &pretty_ios_desc($desc);
    $desc = &pretty_junos_desc($desc);
    $desc = &pretty_arista_desc($desc);
    $desc = &pretty_hp_desc($desc);
    $desc = &pretty_procurve($desc);
    return $desc;
}

1;
