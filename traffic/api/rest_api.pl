#! %PERL%

#
# $Id$
#

use strict;
use Plack::Util;
use Plack::Runner;
use Data::Dumper;
my $runner = Plack::Runner->new;

my $app = Plack::Util::load_psgi('rest_api.psgi');

$runner->run($app);
