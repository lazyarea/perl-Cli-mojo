package ImportCsv::Data::Dtb::CustomerKind;

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

sub find
{
    my ($self,$pg,$cond) = @_;
    return undef if (!$cond);
    my $sql = "select * from dtb_customer_kind";
    $sql .= " WHERE 1=1 ";
    for( keys $cond){$sql .= " AND $_ = '$cond->{$_}'";}
    $sql .= " LIMIT 1";
    my $query = $pg->db->query($sql);
    my $hash  = $query->hash;
    return $hash;
}


1;
