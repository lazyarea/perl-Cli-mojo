package ImportCsv::Commons::Utils;

use strict;
use warnings;
use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use constant DEBUG => 0;
use constant DATA_DIR => '/var/www/doc/data';
use Text::CSV;
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}

sub check_file
{
    my ($self, $name) = @_;
    warn Dumper DATA_DIR;
};

sub load_csv_from_file
{
    my ($self, $name) = @_;
    my %res = ();
#    if ( -f DATA_DIR.'/'.name) return $res['message'] = 'file not found:'.$name;
#    my @csv = &load_csv_from_file("./chk.csv");
#    foreach my $line (@csv){
#    }
    for( my $i=0; $i<10; ++$i){
        warn Dumper $i;
    }
}
1;

