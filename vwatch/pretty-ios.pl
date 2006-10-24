#
# $Id$
#

# Prettyprint/abbreviate "system description",
# leave essential information only for those variants
# we have been tought to condense.

sub pretty_ios_desc {
    my($desc) = @_;

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

    if ($desc =~ /Juniper Networks, Inc. ([^ ]+) .*kernel JUNOS ([^ ]+) .*/) {
	$desc = "JunOS $2 $1";
    }
    return $desc;
}

sub pretty_desc {
    my($desc) = @_;

    $desc = &pretty_ios_desc($desc);
    $desc = &pretty_junos_desc($desc);
    $desc = &pretty_hp_desc($desc);
    return $desc;
}

1;
