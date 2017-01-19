package ImportCsv::Commons::Config;

use Mojo::Base qw/Mojolicious::Command/;
use Mojo::Log;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use YAML;

use constant DEBUG => 0;
use constant DB_CONFIG => '/var/www/app/config/eccube/database.yml';
use constant DATA_DIR => '/var/www/doc/data';
use constant ERROR_DIR => '/root/error_data';
use constant LOG_DIR  => '/var/www/doc/data/log';
use constant LOG_FILE  => '/mojo.log';
use constant DATA_DIR=> '/var/www/doc/data';
use constant DATA_MOVED_DIR => '/var/www/doc/data/moved';

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
    my %config;
    $config{'data'}{'data_dir'} = DATA_DIR;
    $config{'data'}{'error_dir'} = ERROR_DIR;
    $config{'data'}{'data_moved_dir'} = DATA_MOVED_DIR;
    $config{'log'}{'log_dir'}  = LOG_DIR;
    $config{'log'}{'log_file'} = LOG_FILE;
    my $db = YAML::LoadFile(DB_CONFIG);
    $config{database} = $db->{database};
    return \%config;
}

1;
