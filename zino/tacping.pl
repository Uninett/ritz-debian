#! %PERL%

## $Header$
#
# Send a request to a TACACS server
#
# Written June 1992 by Craig A. Finseth, fin@unet.umn.edu
# available from mail.unet.umn.edu in "~ftp/export/tacfanout.tar[.z]
##

if ($#ARGV < 0) {
USAGE:
    print "Send a UDP TACACS request and print the response program.
     usage is:  tacping [-options] <TACACS server>
     options:
	-p|password <pw> Specify a password (default is 'bar').
	-t|type <type>	Specify a request type (default is 'login').
	-u|user <name>	Specify a user name (default is 'foo').
	-v		Be verbose about what you are doing.\n";
    exit 0;
}

# ---------- parse arguments --------------------

$password = "bar";
$type = "login";
$user = "foo";

while (@ARGV) {
    $x = $ARGV[0];
    $x =~ tr/A-Z/a-z/;
    if ($x eq "-p" || $x eq "-password") {
	if ($#ARGV < 1) {
	    print "Missing options to $x\n";
	    exit 0;
	}
	shift @ARGV;
	$password = $ARGV[0];
    }
    elsif ($x eq "-t" || $x eq "-type") {
	if ($#ARGV < 1) {
	    print "Missing options to $x\n";
	    exit 0;
	}
	shift @ARGV;
	$type = $ARGV[0];
    }
    elsif ($x eq "-u" || $x eq "-user") {
	if ($#ARGV < 1) {
	    print "Missing options to $x\n";
	    exit 0;
	}
	shift @ARGV;
	$user = $ARGV[0];
    }
    elsif ($x eq "-v") {
	$verbose = 1;
    }
    elsif ($x =~ /^-/) {
	goto USAGE;
    }
    else	{
	$server = $ARGV[0];
    }
    shift;
}
if ($server eq "") {
    goto USAGE;
}

if ($verbose) {
    $| = 1;
}

# ---------- open the port --------------------

$AF_INET = 2;
$SOCK_DGRAM = 2;
$sockaddr = 'S n a4 x8';

($name,$aliases,$proto) = getprotobyname("udp");
print "proto: $name, $aliases, $proto\n" if ($verbose);

($name,$aliases,$port) = getservbyname("tacacs", "udp");
print "serv: $name, $aliases, $port\n" if ($verbose);

($name,$aliases,$htype,$len,@addrs) = gethostbyname($server);
$addr = $addrs[0];
if ($verbose) {
    print "host: $name, $aliases, $htype, $len, ";
    printf "%d.%d.%d.%d\n", 
    ord(substr($addr, 0, 1)),
    ord(substr($addr, 1, 1)),
    ord(substr($addr, 2, 1)),
    ord(substr($addr, 3, 1));
}

die "No host named '$server'\n" if (!$addr);

$serv = pack($sockaddr, $AF_INET, $port, $addr);

if (socket(S, $AF_INET, $SOCK_DGRAM, $proto)) {
    print "socket ok\n" if ($verbose);
}
else	{
    die "cannot open socket to $server($addr): $!\n";
}

# ---------- build the packet --------------------

# These are from tacacs.h
@typenames = ("?", "login", "answer", "change", "follow", "connect",
	      "enable", "logout", "reload", "slipon", "slipoff", "slipaddr");
$type =~ tr/A-Z/a-z/;

for $cnt (0..$#typenames) {
    $i = $cnt;
    last if ($type eq $typenames[$cnt]);
}

die "unknown type $type\n" if ($i > $#typenames);

($a,$b,$c,$d) = unpack("C4", $addr);
# Extended tacacs structure
$packet = pack(sprintf("C C n C C C C N C4 n n N n A%d A%d",
		       length($user),
		       length($password)),
	       0x80,		# extended version
	       $i,		# type (from above)
	       $$,		# nonce (transaction ID)
	       length($user),		# length of name
	       length($password),	# length of password
	       0,		# response
	       0,		# reason
	       0,		# assigned user id
	       $a,$b,$c,$d,	# destination host
	       $port,		# destination port
	       1,		# local line number
	       0,		# flags
	       0,		# accesslist
	       $user,		# user name appended to end of file
	       $password);	# password

# ---------- send it --------------------

if ($verbose) {
    print "socket: ";
    for $cnt (0..length($serv) - 1) {
	printf " %x", ord(substr($serv, $cnt, 1));
    }
    print "\n";

    print "send: ";
    for $cnt (0..length($packet) - 1) {
	printf " %x", ord(substr($packet, $cnt, 1));
    }
    print "\n";
}

die "Send error: $!\n" if (send(S, $packet, 0, $serv) != length($packet));

select(S); $| = 1; select(STDOUT);

alarm 5;	# Fixed 5-second timeout

die "Receive error: $!\n" if (!recv(S, $packet, 576, 0));

if ($verbose) {
    print "recv: ";
    for $cnt (0..length($packet) - 1) {
	printf " %x", ord(substr($packet, $cnt, 1));
    }
    print "\n";
}

# ---------- unpack it --------------------

($version,$type,$nonce,$nlen,$pwlen,$response,$reason,$userid,$dhost,$dport,
 $line,$flags,$access,$user) =
    unpack("C C n C C C C N N n n N n A", $packet);

$password = substr($user, $nlen);
$user = substr($user, 0, $nlen);

if ($verbose) {
    print "version $version, type $type ($typenames[$type]), nonce $nonce,
  name length $nlen, password length $pwlen, userid $userid
  destination host $dhost, destination port $dport, line $line,
  flags $flags, access $access, user '$user', password '$password'\n";
}

@respnames = ("?", "accepted", "rejected");
@reasnames = ("none", "expiring", "password", "denied", "quit", "idle",
	      "drop", "bad");

print "response $response ($respnames[$response]), reason $reason ($reasnames[$reason])\n";

die "nonce mismatch\n" if ($nonce != ($$ & 0xffff));

exit 0;

