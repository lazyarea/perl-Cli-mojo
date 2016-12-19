package ImportCsv::Commons::Config;

use Mojo::Base qw/Mojolicious::Command/;
use Mojo::Log;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use constant DEBUG => 0;
use constant DATA_DIR => '/var/www/doc/data';
use constant LOG_DIR  => '/tmp';
use constant LOG_FILE  => '/mojo.log';
use constant DBHOST   => 'localhost';
use constant DBNAME   => 'eccube';
use constant DBUSER   => 'eccube';
use constant DBPASSWD => 'Password1';
use constant AUTOCOMMIT => 0;
use constant RAISEERROR => 1;

use Text::CSV;
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}

sub load_config
{
    my $self = shift;
    warn Dumper $self->app->home;
    my %config;
    $config{'LOG'}{'DATA_DIR'} = DATA_DIR;
    $config{'LOG'}{'LOG_DIR'}  = LOG_DIR;
    $config{'LOG'}{'LOG_FILE'} = LOG_FILE;
    $config{'database'}{'host'}     = DBHOST;
    $config{'database'}{'user'}     = DBUSER;
    $config{'database'}{'password'} = DBPASSWD;
    $config{'database'}{'dbname'}   = DBNAME;
    return \%config;
}

1;
