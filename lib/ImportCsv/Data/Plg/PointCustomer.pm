package ImportCsv::Data::Plg::PointCustomer;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use Text::CSV;
use File::Copy;
use ImportCsv::Data::Base;
use Moment;
use Data::Dumper;
use constant DEBUG => 0; # 1:true

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};
has utils => sub{
     return ImportCsv::Commons::Utils->new;
};

sub new
{
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}

sub addFromKihon
{
    my ($self,$pg,$line,$customer_id) = @_;
    warn Dumper $customer_id;
}

sub findCustomer
{
    my ($self,$customer_id) = @_;
}


1;
