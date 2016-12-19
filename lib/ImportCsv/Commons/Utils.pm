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

sub get_file_name
{
    my ($self, $path, $fname ) = @_;
    warn Dumper $path;
    warn Dumper $fname;
    chdir($path);
    my @file = glob "*.csv";
    # warn Dumper join( "\t", @file ), "\n";
#    warn Dumper @file ;
    foreach my $file (@file){
        if ($file =~ /$fname/i){
            return $file;
        }
    }
}

1;

