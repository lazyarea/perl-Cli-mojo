package ImportCsv::Commons::Utils;

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
    my $fpath = DATA_DIR.'/'.$name;

    if (! -f $fpath ){
        return $res{'message'} = 'file not found:'.$name;
    }
    my @csv = &load_csv_from_file($fpath);
#    foreach my $line (@csv){
#    }
}

1;

