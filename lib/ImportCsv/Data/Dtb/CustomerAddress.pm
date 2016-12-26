package ImportCsv::Data::Dtb::CustomerAddress;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use Text::CSV;
use File::Copy;
use ImportCsv::Data::Base;
use ImportCsv::Data::Dtb::Customer;
use ImportCsv::Data::Mtb::Pref;
use Moment;
use Data::Dumper;

use constant DEBUG => 0; # 1:true
#use constant DATA_DIR => '/var/www/doc/data';
#use constant DATA_MOVED_DIR => '/var/www/doc/data/moved';

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};
has utils => sub{
     return ImportCsv::Commons::Utils->new;
};

sub load_csv_from_file
{
    my $self = shift;
    my %res = ();
    my $utils = ImportCsv::Commons::Utils->new;
    my $file = $utils->get_file_name($self->commons_config->{'data'}->{'data_dir'}, 'nohin');
    if ( !$file ) {
        $utils->logger("target not found.");
        exit 1;
    }
    $utils->logger($file.": found.");
    my $fpath = $self->commons_config->{'data'}->{'data_dir'}.'/'.$file;
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
    my $last_customer = '';
    # BEGIN TRANSACTION
    #$pg->db->begin;
    eval{
        while ( my $row = $csv->getline( $fh ) ) {
            if ($c==0){ $c++; next}
            #-----------------------------skip
            if ($row->[10] =~ /(3|4)/ ){
                $utils->logger($c.'行目：得意先区分'.$row->[0]);
                next;
            }
            ##----------------------------validate start
            my $valid = undef;
            if ($file =~ /^NVH_NOHIN/i) {
                $valid = $utils->validateMemberNohin($row);
            }elsif($file =~ /^FCH_NOHIN/i) {
                $valid = $utils->validateOnlineNohin($row);
            }
            if ($valid){
                $valid->{'line_no'} = $c;
                for(keys $valid){
                    my $k=$_;
                    my $v=$valid->{$k};
                    $utils->logger( "$k => $v");
                }
                next;
            }
            #----------------------------validate end
            my $del_flg = 0;
            if ($file =~ /^NVH_NOHIN/i) {
                if ( $last_customer ne $row->[1] ) {
                    $del_flg = 1;
                    $last_customer = $row->[1];
                }
            }elsif($file =~ /^FCH_NOHIN/i) {
                if ( $last_customer ne $row->[0] ) {
                    $del_flg = 1;
                    $last_customer = $row->[0];

                }
            }
            &createCustomerAddress($pg,$row, $file, $del_flg);
            #----------------------------
            $c++;
        }
        # END TRANS:w
        # ACTION
        #$pg->db->commit;
    };
    local $@;
    if ($@){
        #$pg->db->query('ROLLBACK');
        $utils->logger('FAILED INSERT: '.$file);
        $utils->logger($@);
        exit 1;
    }
    $csv->eof or $csv->error_diag();
    close $fh;
    if ( DEBUG == 0){ move $fpath, $self->commons_config->{'data'}->{'data_moved_dir'}.'/'.$file or die $!; }
    $utils->logger($file.': done');
}

sub createCustomerAddress
{
    my($pg, $line, $file, $del_flg) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $customer = &findCustomer($pg,$line,$file); #既存データ検索
    if ( !$customer ){
        $utils->logger("$line->[0],$line->[1],$line->[2],$line->[3]");
        return undef;
    }
    if ( $del_flg == 1 ){
        &deleteCustomerAddress($pg,$customer);
    }
    my $ret = undef;
    if ($file =~ /^NVH_NOHIN/i) {
        &createMemberNohin($pg,$line,$customer);
    }elsif($file =~ /^FCH_NOHIN/i){
        &createOnlineNohin($pg,$line,$customer);
    }
}

sub findCustomer
{
    my ($pg,$line,$file) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $sql = 'SELECT * FROM dtb_customer';
    if ($file =~ /^NVH_NOHIN/i) {
        $sql .= " WHERE craft_number='$line->[1]'" if $line->[1];
    }elsif($file =~ /^FCH_NOHIN/i) {
        $sql .= " WHERE client_code='$line->[0]'" if $line->[0];
    }
    my $ret = undef;
    eval{
        $ret = $pg->db->query($sql);
    };
    local $@;
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }
    my $hash = $ret->hash;
    return $hash;
}

sub deleteCustomerAddress{
    my ($pg,$customer) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $sql = 'DELETE FROM dtb_customer_address ';
    $sql   .= " WHERE customer_id = '$customer->{'customer_id'}'";
    my $ret = undef;
    eval{
        $ret = $pg->db->query($sql);
    };
    local $@;
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }

}

sub createMemberNohin
{
    my ($pg,$line,$data) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    my $sql = 'INSERT INTO dtb_customer_address(';
    $sql .= 'customer_id,pref,name01,name02,kana01,kana02,company_name,zip01,zip02,zipcode,';
    $sql .= 'addr01,addr02,addr03,tel01,fax01,create_date,update_date,del_flg,';
    $sql .= 'rrr_customer_address_id,craft_number,delivery_name) VALUES (';
    $sql .= "$data->{'customer_id'}, $line->[3], '$line->[4]', '$line->[5]', '$line->[6]', '$line->[7]', '$line->[8]', '$line->[11]',";
    $sql .= "'$line->[12]', '$line->[11]$line->[12]', '$line->[13]', '$line->[14]', '$line->[15]', '$line->[16]', '$line->[17]',";
    $sql .= "'$dt', '$dt', 0, '$line->[2]', '$line->[1]', '$line->[9]')";
    my $ret = undef;
    eval{
        $ret = $pg->db->query($sql);
    };
    local $@;
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }

    my $next = $pg->db->query("select nextval('dtb_customer_address_customer_address_id_seq')");
    my $nextv = $next->hash->{'nextval'};
    return $nextv;

}

sub createOnlineNohin
{
    my ($pg,$line,$data) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();

    my $pref = ImportCsv::Data::Mtb::Pref->new;
    my $pref_dta = $pref->get_pref_id($pg, $line->[3]);
    if (!$pref_dta){
        $utils->logger($line->[3].' is pref ?');
        return undef;
    }
    my $sql = 'INSERT INTO dtb_customer_address(';
    $sql .= 'customer_id,pref,name01,name02,kana01,kana02,company_name,zip01,zip02,zipcode,';
    $sql .= 'addr01,addr02,addr03,tel01,fax01,create_date,update_date,del_flg,';
    $sql .= 'rrr_customer_address_id,delivery_name,client_code) VALUES (';
    $sql .= "$data->{'customer_id'}, $pref_dta->{'id'}, '$line->[4]', '$line->[5]', '$line->[6]', '$line->[7]', '$line->[8]', '$line->[11]',";
    $sql .= "'$line->[12]', '$line->[11]$line->[12]', '$line->[13]', '$line->[14]', '$line->[15]', '$line->[16]', '$line->[17]',";
    $sql .= "'$dt', '$dt', 0, '$line->[2]', '$line->[9]', '$line->[0]')";
    my $ret = undef;
    eval{
        $ret = $pg->db->query($sql);
    };
    local $@;
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }
    my $next = $pg->db->query("select nextval('dtb_customer_address_customer_address_id_seq')");
    my $nextv = $next->hash->{'nextval'};
    return $nextv;

}

1;
