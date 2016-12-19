package ImportCsv::Commons::Utils;

use Mojo::Base qw/Mojolicious::Command/;
use Mojo::Log;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use constant DEBUG => 0;
use constant DATA_DIR => '/var/www/doc/data';
use constant LOG_DIR  => '/tmp';
use constant LOG_FILE  => '/mojo.log';
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

#    my %valid = ();
#    if ( my $res = &len('aaaaa', 3) ){
#        $valid{'aaaaa'} = 'too long:'.$res;
#    }
#    if ( my $res = &len('bbbb', 3) ){
#        $valid{'bbbb'} = 'too long:'.$res;
#    }
#    my $log = Mojo::Log->new;
#    $log = Mojo::Log->new(path => '/tmp/mojo.log', level => 'info');
#    $log->info(%valid);
#    for(keys %valid){
#        my $k=$_;
#        my $v=$valid{$k};
#        $log->info( "$k => $v");
#    }
#
sub logger
{
    my ($self,$data) = @_;
    my $log = Mojo::Log->new(path => LOG_DIR.LOG_FILE, level => 'info');
    $log->info($data);
}

sub len
{
    my ($str, $limit) = @_;
    if ( length($str) > $limit){
        return true;
    }
    return undef;
}

1;

