package ImportCsv::Data::Dtb::Product;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use CGI::Session;
use ImportCsv::Data::Base;
use Data::Dumper;
use constant DEBUG => 0;
use constant DBHOST => 1;


#sub new
#{
#    my $class = shift;
#    my $self = {};
#    warn Dumper DBHOST;
#    my $pg = Mojo::Pg->new('postgresql://eccube@/eccube');
#    $pg->password('Password1');
#    $self->session('name',1);
#    say $pg->db->query('select version() as version')->hash->{version};
#    my $res =  $pg->db->query('select count(*) from dtb_product limit 1');
#    warn Dumper $res->hash;
#    my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$host;port=$port;options=$options",
#            $username,$password,
#            {AutoCommit => 0, RaiseError => 1, PrintError => 0});
#    return bless $self, $class, $dbh;
#    return bless $self, $class;
#}


sub find
{
    my $self = shift;

    my $connect = ImportCsv::Data::Base->new;
    my $pg = $connect->get_conenction();
    my $res = $pg->db->query('select count(*) from dtb_product limit 1');
    warn Dumper $res->hash;
    return $res->hash;
}

1;

