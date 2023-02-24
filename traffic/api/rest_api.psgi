#! %PERL%
# -*- perl -*-

#
# $Id$
#

use strict;
use warnings;

use lib "%TOPDIR%/lib";

require "search.pl";
require "read-5m-sum.pl";
require "db-lookup.pl";
require "date.pl";
require "utils.pl";

use traffic_sum;

use POSIX qw();
use Raisin::API;
use Raisin::Entity;
use Data::Dumper;
use Types::Standard qw(Any Int Str);

plugin 'Swagger';

# swagger_security(name => 'stoken', in => 'header', type => 'api_key');

# middleware '+Auth';

middleware 'CrossOrigin',
    origins => '*',
    methods => [qw/DELETE GET HEAD OPTIONS PATCH POST PUT/],
    headers => [qw/accept authorization content-type api_key_token/];

api_default_format 'json';

swagger_setup(
    title => 'Uninett traffic statistics data',
    description => 'Uninett traffic statistics data',
    #terms_of_service => '',

    contact => {
        name => 'Havard Eidnes',
        url => 'https://stats.uninett.no/',
        email => 'Havard.Eidnes@sikt.no',
    },
#     license => {
#         name => 'Perl license',
#         url => 'http://dev.perl.org/licenses/',
#     },
);

desc 'Uninett traffic statistics data';
resource traffic => sub {
    summary 'Stats';
    params(
           requires('lines',    type => Str, desc => '%2B-separated line names'),
           optional('date',     type => Str, desc => 'datespec',
                    default => POSIX::strftime "%Y-%m-%d", localtime time),
          );
    get '5m_sum' => sub {
        my $params = shift;
        my @results = get_5m_sum ($params->{date}, $params->{lines});
        # Return data
        {
            traffic_5min_data => {
                ('Line name(s)' => $params->{lines}),
                 'Data',   [ map
                     {
                         {
                             'time', $_->[0],
                             'bit/s in', int($_->[1]),
                             'bit/s out', int($_->[2]),
                         }
                     } @results
                     ]
            }
        }
    };
};

run;
