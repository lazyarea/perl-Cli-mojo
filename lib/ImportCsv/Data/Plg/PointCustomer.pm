package ImportCsv::Data::Plg::PointCustomer;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use Text::CSV;
use File::Copy;
use ImportCsv::Data::Base;
use ImportCsv::Commons::Utils;
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


sub addPlgPointCustomer
{
    my ($self, $pg, $data) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();

    my $sql = undef;
    $sql = 'select last_value from plg_point_customer_plg_point_customer_id_seq';
    my $lastv = undef;
    local $@;
    eval{
        $lastv = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }
    my $lv = $lastv->hash;

    $sql = undef;
    $sql = "INSERT INTO plg_point_customer(plg_point_customer_id,customer_id, plg_point_current, create_date,update_date) VALUES ";
    $sql .= "($lv->{'last_value'}+1,$data->{'customer_id'},$data->{'point'},'$dt','$dt')";
$utils->logger($sql);
    my $res = undef;
    local $@;
    eval{
        $res = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }
    return $lv->{'last_value'}+1;
}


1;
