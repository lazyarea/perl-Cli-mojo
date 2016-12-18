package ImportCsv::Data::Dtb::Product;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use CGI::Session;
use Text::CSV;
use File::Copy;
use ImportCsv::Data::Base;
use Moment;
use Data::Dumper;

use constant DEBUG => 1; # 1:true


sub findByProductCode
{
    my ($pg,$prd_cd) = @_;
    return undef if (!$prd_cd);
    my $sql = "select s.product_class_id from dtb_product_class AS c";
    $sql .= " LEFT JOIN dtb_product_stock AS s ON c.product_class_id = s.product_class_id";
    $sql .= " WHERE 1=1";
    $sql .= " AND product_code='$prd_cd'";
    $sql .= " LIMIT 1";
    my $query = $pg->db->query($sql);
    my $hash  = $query->hash;
    return $hash;
}

sub findProduct
{
    my ($pg,$line) = @_;
    my $res = $pg->db->query("select * from dtb_product where catalog_product_code = '$line->[6]' limit 1");
    return  $res->hash;
    exit 1;
#    return $res->hash;
}
sub find
{
    my ($pg,$line) = @_;
    my $res = $pg->db->query('select count(*) from dtb_product limit 1');
#    warn Dumper $res->hash;
    return $res->hash;
}

1;

