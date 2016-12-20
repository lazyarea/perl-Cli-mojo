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
use constant DATA_DIR => '/var/www/doc/data';
use constant DATA_MOVED_DIR => '/var/www/doc/data/moved';

#has 'pg' => sub {
#    my $conn = ImportCsv::Data::Base->new;
#    my $pg   = $conn->get_conenction(); # connection error を書く必要がある
#};

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
    $utils->logger($file.": found.");
    my $flag = ($file =~ /^NVH_SHOHIN/i) ? 'member' : 'online';
    if ( !$file ) {
        $res{'message'} = "file not found: shohin";
        $utils->logger(\%res);
        exit 1;
    }
    my $fpath = DATA_DIR.'/'.$file;
    if ( ! -f $fpath){
        $res{'message'} = "file not found: ".$fpath;
        $utils->logger(\%res);
        exit 1;
    }
    # CSV READ START
    my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag();
    open my $fh, "<:encoding(utf8)", $file or die "$file: $!";
    my $conn = ImportCsv::Data::Base->new;
    my $pg   = $conn->get_conenction(); # connection error を書く必要がある
    my $c = 0;
    # BEGIN TRANSACTION
    #$pg->db->begin;
    eval{
        while ( my $row = $csv->getline( $fh ) ) {
            if ($c==0){ $c++; next}
        #----------------------------
        # validate start
        #----------------------------
        #----------------------------
        # validate end
        #----------------------------
            #my $prod_last_insert_id = &createProduct( $pg, $row );
            #my $prod_class_last_value = &createProductClass($pg,$row, $prod_last_value);
            my $prod_last_value = &create_or_updateProduct( $pg, $row );
            my $prod_class_last_value = &create_or_updateProductClass($pg,$row, $prod_last_value->{'last_value'});
warn Dumper "===================";
warn Dumper $prod_last_value->{'last_value'};
warn Dumper $prod_class_last_value->{'last_value'};
            &create_or_updateProductStock($pg, $row, $prod_last_value->{'last_value'}, $prod_class_last_value->{'last_value'});


exit 1;



            #my $prod_class_last_value = &createProductClass($pg,$row, $prod_last_value->{'last_value'});
#            my $prod_class_last_value = &createProductClass($pg,$row, $prod_last_value);
            #warn Dumper "---------------";
            #warn Dumper $prod_last_value;
            #warn Dumper "---------------";
            #&createProductStock($pg, $row, $prod_last_value->{'last_value'}, $prod_class_last_value->{'last_value'});
            $c++;
        }
        # END TRANSACTION
        #$pg->db->commit;
    };
    if ($@){
        #$pg->db->query('ROLLBACK');
        $utils->logger('FAILED INSERT: '.$file);
        $utils->logger($@);
        exit 1;
    }
    $csv->eof or $csv->error_diag();
    close $fh;
    if ( DEBUG == 0){ move $fpath, DATA_MOVED_DIR.'/'.$file or die $!; }
    $utils->logger($file.': done');
}

sub create_or_updateProduct
{
    my($pg, $line) = @_;
    my $data = &findProduct($pg,$line);
#    warn Dumper keys &findProduct($pg,$line);

    if ( !$data ){
        my $last =  &createProduct( $pg, $line );
        return $last;
    }else{
        warn Dumper "exists:". $line->[6];
        &updateProduct($pg, $line);
        return undef;
    }
}

sub create_or_updateProductClass
{
    my($pg,$line,$prod_id) = @_;
    if ($prod_id){
        my $res = &createProductClass($pg,$line,$prod_id);
        return $res;
    }else{
        &updateProductClass($pg,$line,$prod_id);
        return undef;
    }
}

sub create_or_updateProductStock
{
    my ($pg, $line, $prod_id, $prod_class_id) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $data_sql = "select s.product_class_id from dtb_product_class AS c";
    $data_sql .= " LEFT JOIN dtb_product_stock AS s ON c.product_class_id = s.product_class_id";
    $data_sql .= " WHERE 1=1";
    $data_sql .= " AND product_code='$line->[6]'";
    my $data = $pg->db->query($data_sql);
    # Stock not found, then find prod_class_id
    if (!$data->hash->{'product_class_id'}){
        my $cls_sql = 'SELECT product_id, product_class_id  from dtb_product_class';
        $cls_sql .= ' WHERE 1=1';
        $cls_sql .= " AND product_code='$line->[6]'";
        my $prod_class = undef;
        eval{
            $prod_class = $pg->db->query($cls_sql);
            # ここで詰まってる.
            # stockだけレコードがない場合作りに行く
            #$prod_id =  $prod_class->hash->{'product_id'};
            #$prod_class_id = $prod_class->hash->{'product_class_id'};
        };
        if ($@){
            $utils->logger($@);
            $utils->logger($cls_sql);
            return undef;
        }
        #warn Dumper  $prod_class->hash;
        #warn Dumper  $prod_class->hash->{'product_id'};
        #warn Dumper  $prod_class->hash->{'product_class_id'};

        #$prod_class->hash;
    }

    warn Dumper $prod_id;
    warn Dumper $prod_class_id;

    if ( $prod_id && $prod_class_id ){
        warn Dumper "create stock";
        my $res = createProductStock($pg, $line, $prod_id, $prod_class_id);
    }else{
        #my $res = updateProductStock($pg, $line, $stock_prod_class_id);
    }
}

sub createProduct
{
    my($pg, $line) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
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
        $utils->logger($sql);
        $utils->logger($@);
        exit 1;
    }
    #$utils->logger($sql) if DEBUG==1;
    my $ret = $pg->db->query('select last_value from dtb_product_product_id_seq');
    return $ret->hash;
}

sub updateProduct
{
    my($pg, $line) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    my $prod = &findProduct($pg,$line);
    my $sql = 'UPDATE dtb_product';
    $sql .= " SET name='$line->[0]', product_master_name='$line->[0]',set_product_flg=$line->[1], product_division_id=$line->[2], product_handling_division_id=$line->[3],flight_not_flg=$line->[4], product_markup_rate_id=$line->[5],soldout_notices='$line->[10]'";
    $sql .= " WHERE product_id=".$prod->{'product_id'};
    #$utils->logger($sql) if DEBUG==1;

    my $res = undef;
    eval{
        $res = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        exit 1;
    }
}

sub createProductClass
{
    my($pg,$line,$prod_id) = @_;
    return undef if (!$prod_id);
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();

    my $next = $pg->db->query("select nextval('dtb_product_class_product_class_id_seq')");
    my $nextv = $next->hash->{'nextval'};
    my $sql = 'INSERT INTO public.dtb_product_class';
    $sql .= '(product_class_id, product_id, product_type_id, class_category_id1, class_category_id2, delivery_date_id, creator_id, product_code, stock, stock_unlimited, sale_limit, price01, price02, delivery_fee, create_date, update_date, del_flg, stock_scheduled_sell) VALUES ';
    $sql .= "( $nextv, $prod_id, 1, null, null, null, 2, '$line->[6]', $line->[7], 0, null, null, $line->[9], null, '$dt', '$dt', 0, $line->[8])";
    my $res = undef;
    eval{
        $res = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        exit 1;
    }
    my $ret = $pg->db->query('select last_value from dtb_product_class_product_class_id_seq');
    return $ret->hash;
}


sub updateProductClass
{
    my($pg,$line,$prod_id) = @_;
#    return undef if (!$prod_id);
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    my $sql = undef;
    if ($line->[6]){
        $sql = "select * from dtb_product_class where product_code='$line->[6]'";
    }
    my $data = $pg->db->query($sql);
    if (!$data->hash){
        $utils->logger('updateProductClass:'.$line->[6].': product_code not found.');
        return undef;
    }
    my $update_sql =  'UPDATE dtb_product_class SET ';
    $update_sql .= "  stock=$line->[7],price02=$line->[9],update_date='$dt', stock_scheduled_sell='$line->[8]'";
    $update_sql .= " WHERE product_code='$line->[6]'";
    #$utils->logger($update_sql) if DEBUG == 1;
    my $res = undef;
    eval{
        $res = $pg->db->query($update_sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }
}

sub createProductStock
{
    my($pg,$line,$prod_id,$prod_class_id) = @_;
    return undef if (!$prod_id || !$prod_class_id);
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    my $sql = 'INSERT INTO public.dtb_product_stock';
    $sql .= ' (product_class_id, creator_id, stock, create_date, update_date) VALUES ';
    $sql .= "  ( $prod_class_id, 2, $line->[7], '$dt', '$dt')";
    my $res = undef;
    eval{
        $res = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        exit 1;
    }
}

sub updateProductStock
{
    my($pg,$line,$prod_id,$prod_class_id) = @_;
    return undef if (!$prod_id || !$prod_class_id);
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    my $sql = 'UPDATE dtb_product_stock';
    $sql .= " SET stock=$line->[7],update_date='$dt'";
    $sql .= " WHERE product_class_id=$prod_id";
    my $res = undef;
    eval{
        $res = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        exit 1;
    }
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

