package ImportCsv::Data::Dtb::Product;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use CGI::Session;
use Text::CSV;
use File::Copy;
use ImportCsv::Data::Base;
use ImportCsv::Data::Dtb::ProductStock;
use Moment;
use Data::Dumper;

use constant DEBUG => 1; # 1:true
use constant DATA_DIR => '/var/www/doc/data';
use constant DATA_MOVED_DIR => '/var/www/doc/data/moved';

sub load_csv_from_file
{
    my $self = shift;
    my %res = ();
    my $utils = ImportCsv::Commons::Utils->new;
    my $file = $utils->get_file_name(DATA_DIR, 'shohin');
    if ( !$file ) {
        $utils->logger("target not found.");
        exit 1;
    }
    $utils->logger($file.": found.");
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
            my $valid = undef;
            if ($file =~ /^NVH_SHOHIN/i) {
                $valid = $utils->validateMemberShohin($row);
            }elsif($file =~ /^FCH_SHOHIN/i) {
                $valid = $utils->validateOnlineShohin($row);
            }
            if ($valid){
                $valid->{'line_no'} = $c;
                for(keys $valid){
                    my $k=$_;
                    my $v=$valid->{$k};
                    $utils->logger( "$k => $v");
                }

#                $utils->logger($valid);
                next;
            }
        #----------------------------
        # validate end
        #----------------------------
            my $prod_last_value = &create_or_updateProduct( $pg, $row );
            #$utils->logger( $c.":".$prod_last_value ) if DEBUG==1;
            my $prod_class_last_value = &create_or_updateProductClass($pg,$row, $prod_last_value->{'last_value'});
            &create_or_updateProductStock($pg, $row, $prod_last_value->{'last_value'}, $prod_class_last_value->{'last_value'});
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

    if ( !$data ){
        my $last =  &createProduct( $pg, $line );
        return $last;
    }else{
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
    # 更新対象のstockを探す
    my $stock = ImportCsv::Data::Dtb::ProductStock->new;
    my $st_dta = undef;
    $st_dta = $stock->findByProductCode($pg,$line->[6]) if ($line->[6]); # 会員
    #$st_dta = # 通販

    # $prod_id, $prod_class_idがある。つまり完全に新規: create
    if ( $prod_id && $prod_class_id){
        my $res = createProductStock($pg, $line, $prod_id, $prod_class_id);
    }
    #  $prod_id, $prod_class_idがない。対象stockは無い：create
    elsif(!$st_dta->{'product_class_id'} && $line->[10]){
        warn Dumper "更新対象であるが対象レコードが存在しない";
    }
    #  $prod_id, $prod_class_idがない。対象stockは在る：update
    elsif($st_dta){
        my $res = &updateProductStock($pg, $line, $prod_id, $prod_class_id);
    }
}

sub createProduct
{
    my($pg, $line) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    my $sql = 'INSERT INTO dtb_product';
    $sql   .= " (creator_id, status, name, note, description_list, description_detail, search_word, free_area, del_flg, create_date, update_date, catalog_product_code, start_datetime, end_datetime, point_flg, title1, title2, title3, title4, title5, title6, detail1, detail2, detail3, detail4, detail5, detail6, product_master_name, product_genre_id, set_product_flg, product_division_id, product_handling_division_id, soldout_notices, flight_not_flg, product_markup_rate_id, shipping_fee_type_id) VALUES (";
    $sql .= "2, 1, '$line->[0]', null, null, null, null, null, 0, '$dt', '$dt', '$line->[6]', '1970-01-01 00:00:00.000000', '2099-01-01 00:00:00.000000', null,  null, null, null, null, null, null, null, null, null, null, null, null, '$line->[0]', 0, $line->[1], $line->[2], $line->[3], '$line->[10]', $line->[4], 1, 1)";
    my $res = undef;
    eval{
        $res = $pg->db->query($sql);
    };
    if ($@) {
#        $pg->db->rollback();
        $utils->logger($sql);
        $utils->logger($@);
    }
    $utils->logger($sql) if DEBUG==1;
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
    $sql .= " SET name='$line->[0]', product_master_name='$line->[0]',set_product_flg=$line->[1], product_division_id=$line->[2], product_handling_division_id=$line->[3],flight_not_flg=$line->[4], product_markup_rate_id=1,soldout_notices='$line->[10]'";
    $sql .= " WHERE product_id=".$prod->{'product_id'};
    #$utils->logger($sql) if DEBUG==1;

    my $res = undef;
    eval{
        $res = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        #exit 1;
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
        #exit 1;
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
        #exit 1;
    }
}

sub updateProductStock
{
    my($pg,$line) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    #----------------
    my $sql = "select s.* from dtb_product_class AS c";
    $sql .= " LEFT JOIN dtb_product_stock AS s ON c.product_class_id = s.product_class_id";
    $sql .= " WHERE 1=1";
    $sql .= " AND product_code='$line->[6]' LIMIT 1";
    my $query = $pg->db->query($sql);
    my $hash  = $query->hash;
    #----------------
    my $dt = Moment->now->get_dt();
    $sql=undef;
    $sql = 'UPDATE dtb_product_stock';
    $sql .= " SET stock=$line->[7],update_date='$dt'";
    $sql .= " WHERE product_class_id=$hash->{'product_stock_id'}";
    my $res = undef;
    eval{
        $res = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        #exit 1;
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
#sub find
#{
#    my ($pg,$line) = @_;
#    my $res = $pg->db->query('select count(*) from dtb_product limit 1');
#    warn Dumper $res->hash;
#    return $res->hash;
#}

1;

