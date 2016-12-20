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

use constant DEBUG => 0;
use constant DATA_DIR => '/var/www/doc/data';
use constant DATA_MOVED_DIR => '/var/www/doc/data/moved';


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

sub load_csv_from_file
{
    my $self = shift;
    my %res = ();
    my $utils = ImportCsv::Commons::Utils->new;
    my $file = $utils->get_file_name(DATA_DIR, 'shohin');
    if ( !$file ) {
        $res{'message'} = "file not found: shohin";
        return \%res;
    }
    my $fpath = DATA_DIR.'/'.$file;
    if ( ! -f $fpath){
        $res{'message'} = "file not found: ".$fpath;
#        return "file not found: ".$fpath;
        return \%res;
    }

    # CSV READ START
    my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag();
    open my $fh, "<:encoding(utf8)", $file or die "$file: $!";
    my $conn = ImportCsv::Data::Base->new;
    my $pg   = $conn->get_conenction(); # connection error を書く必要がある
    my $c = 0;
    while ( my $row = $csv->getline( $fh ) ) {
        if ($c==0){ $c++; next}
        &addProduct( $pg, $row );
        $c++;
    }
    $csv->eof or $csv->error_diag();
    close $fh;
    move $fpath, DATA_MOVED_DIR.'/'.$file;
}

sub addProduct
{
    my($pg, $line) = @_;
    my $dt = Moment->now->get_dt();
    my $sql = 'INSERT INTO dtb_product';
    $sql   .= " (creator_id, status, name, note, description_list, description_detail, search_word, free_area, del_flg, create_date, update_date, catalog_product_code, start_datetime, end_datetime, point_flg, point_rate, title1, title2, title3, title4, title5, title6, detail1, detail2, detail3, detail4, detail5, detail6, product_master_name, product_genre_id, set_product_flg, product_division_id, product_handling_division_id, soldout_notices, flight_not_flg, product_markup_rate_id, shipping_fee_type_id) VALUES (";
    $sql .= "2, 1, '$line->[0]', null, null, null, null, null, 0, '$dt', '$dt', '$line->[6]', '1970-01-01 00:00:00.000000', '2099-01-01 00:00:00.000000', null, null, null, null, null, null, null, null, null, null, null, null, null, null, '$line->[0]', 0, $line->[1], $line->[2], $line->[3], '$line->[10]', $line->[4], $line->[5], 1)";

    my $res = undef;
    eval{
        $res = $pg->db->query($sql);
    };
    if ($@) {
#        $pg->db->rollback();
        warn Dumper $sql;
        say $@;
    }
#    warn Dumper $res;
#    my $conn = ImportCsv::Data::Base->new;
#    my $pg   = $conn->get_conenction();
#    &find();
}

sub find
{
    my $self = shift;
    my $conn = ImportCsv::Data::Base->new;
    my $pg   = $conn->get_conenction();
    my $res = $pg->db->query('select count(*) from dtb_product limit 1');
    warn Dumper $res->hash;
    return $res->hash;
}

1;

