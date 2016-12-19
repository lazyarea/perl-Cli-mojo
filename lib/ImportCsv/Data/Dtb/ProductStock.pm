package ImportCsv::Data::Dtb::ProductStock;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use CGI::Session;
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

sub findByProductCode
{
    my ($self,$pg,$prd_cd) = @_;
    return undef if (!$prd_cd);
    my $sql = "select s.* from dtb_product_class AS c";
    $sql .= " LEFT JOIN dtb_product_stock AS s ON c.product_class_id = s.product_class_id";
    $sql .= " WHERE 1=1";
    $sql .= " AND product_code='$prd_cd'";
    $sql .= " LIMIT 1";
    my $query = $pg->db->query($sql);
    my $hash  = $query->hash;
    return $hash;
}


1;

