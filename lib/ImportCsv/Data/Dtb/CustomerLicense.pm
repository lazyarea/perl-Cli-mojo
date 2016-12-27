package ImportCsv::Data::Dtb::CustomerLicense;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use Text::CSV;
use File::Copy;
use ImportCsv::Data::Base;
use ImportCsv::Data::Dtb::Customer;
#use ImportCsv::Data::Plg::Point;
#use ImportCsv::Data::Plg::PointCustomer;
use Moment;
use Data::Dumper;
use constant DEBUG => 1; # 1:true

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
    my $last_customer = '';
    my $utils = ImportCsv::Commons::Utils->new;
    #my $po    = ImportCsv::Data::Plg::Point->new;
    #my $pc    = ImportCsv::Data::Plg::PointCustomer->new;
    my $file = $utils->get_file_name($self->commons_config->{'data'}->{'data_dir'}, 'shikaku');
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
    # BEGIN TRANSACTION
    #$pg->db->begin;
    local $@;
    eval{
        while ( my $row = $csv->getline( $fh ) ) {
            if ($c==0){ $c++; next}
            ##----------------------------validate start
            my $valid = undef;
            my $del_flg = 0;
            if ($file =~ /^NVH_SHIKAKU/i) {
                $valid = $utils->validateMemberShikaku($row);
                if ( $last_customer ne $row->[1] ) {
                    $del_flg=1;
                    $last_customer = $row->[1];
                }
            }elsif($file =~ /^FCH_SHIKAKU/i) {
                $valid = $utils->validateOnlineShikaku($row);
                if ( $last_customer ne $row->[0] ) {
                    $del_flg=1;
                    $last_customer = $row->[0];
                }
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

            #----------------------------del_flg
            my $customer_id = &createCustomerLicense($pg,$row, $file,$del_flg);
            #$po->addPointFromShikaku($pg,$customer_id,$row->[19],$row->[20]);
            #----------------------------
            $row = undef;
            $c++;
        }
        # END TRANS:w
        # ACTION
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
    if ( DEBUG == 0){ move $fpath, $self->commons_config->{'data'}->{'data_moved_dir'}.'/'.$file or die $!; }
    $utils->logger($file.': done');
}

sub createCustomerLicense
{
    my($pg, $line, $file, $del_flg) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $customer = &findCustomer($pg,$line,$file); #既存データ検索
    if ( !$customer ){
        $utils->logger("customer data: not found.");
    }
    my $license;
    $license = &findLicense($pg,{'name' => "$line->[2]"}) if ( $line->[2] !~ /^[0-9]+$/); # Online
    $license = &findLicense($pg,{'code' => "$line->[2]"}) if ( $line->[2] =~ /^[0-9]+$/); # Member
    return undef if (!$license);
    $line->[2] = $license->{'license_id'};

    &deleteCustomerLicense($pg, $customer->{'customer_id'}) if ( $del_flg);
    my $ret = undef;

    if ($file =~ /^NVH_SHIKAKU/i) {
        $ret = &createMember($pg,$customer->{'customer_id'},$line->[2]);
    }elsif($file =~ /^FCH_SHIKAKU/i){
        $ret = &createOnline($pg,$customer->{'customer_id'},$line->[2]);
    }
}

sub findCustomer
{
    my ($pg,$line,$file) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $sql = 'SELECT * FROM dtb_customer';
    if ($file =~ /^NVH_SHIKAKU/i) {
        $sql .= " WHERE craft_number='$line->[1]'" if $line->[1];
    }elsif($file =~ /^FCH_SHIKAKU/i) {
        $sql .= " WHERE client_code='$line->[0]'" if $line->[0];
    }
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        exit 1;
    }
    #$utils->logger($sql) if DEBUG==1;
    my $hash = $ret->hash;
    return $hash;

}

sub findCustomerLicense
{
    my ($pg,$customer_id,$license_id) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $sql = 'SELECT * FROM dtb_customer_license';
    $sql .= " WHERE customer_id = $customer_id AND license_id = $license_id";
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        exit 1;
    }
    #$utils->logger($sql) if DEBUG==1;
    my $hash = $ret->hash;
    return $hash;

}

sub findLicense
{
    my ($pg,$cond) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $sql = 'SELECT * FROM dtb_license';
    $sql .= " WHERE 1=1";
    for (keys $cond) {
        $sql .= " AND $_ = $cond->{$_}" if ($utils->is_numeric($_));
        $sql .= " AND $_ = '$cond->{$_}'" if (!$utils->is_numeric($_));
    }
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        return undef;
    }
    my $hash = $ret->hash;
    return $hash;
}

sub deleteCustomerLicense
{
    my ($pg,$customer_id) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $sql = 'DELETE FROM dtb_customer_license WHERE customer_id = '.$customer_id;
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        return undef;
    }
    return 1;
}

sub createMember
{
    my ($pg,$customer_id,$license_id) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    my $sql = 'INSERT INTO dtb_customer_license (customer_id, license_id, create_date, update_date) VALUES ';
    $sql .=   "($customer_id,$license_id,'$dt','$dt' )";
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        return undef;
        #exit 1;
    }
    #$utils->logger($sql) if DEBUG==1;
    my $curr = $pg->db->query("select currval('dtb_customer_license_customer_license_id_seq')");
    my $currv = $curr->hash->{'currval'};
    return $currv;
}

sub createOnline
{
    my ($pg,$customer_id,$license_id) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    my $ret = undef;
    my $sql = 'INSERT INTO dtb_customer_license (customer_id, license_id, create_date, update_date) VALUES ';
    $sql .=   "($customer_id,$license_id,'$dt','$dt' )";
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        return undef;
    }
    #$utils->logger($sql) if DEBUG==1;
    my $next = $pg->db->query("select nextval('dtb_customer_customer_id_seq')");
    my $nextv = $next->hash->{'nextval'};
    return $nextv;
}

sub updateMember
{
    my ($pg,$line) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    my $sex = $line->[1];
    if ($line->[18]){
        $sex = 1 if $line->[1] == 2;
        $sex = 2 if $line->[1] == 1;
    }
    for(my $i=0; $i< keys $line; $i++) {$line->[$i] =~ s/'/''/g;}
    # $line->[19]保有ポイントTBD
    $line->[19] = 0 if ( !$line->[19]);
    # $line->[20]ポイント有効期限
    my $pexpired = $line->[20];
    if ( length($line->[20]) ){
        my $y = substr($line->[20],0,4);
        my $m = substr($line->[20],4,2);
        my $d = substr($line->[20],6,2);
        $pexpired = sprintf("%4s-%2s-%2s 00:00:00", $y,$m,$d);
    }else{$pexpired = '1970-01-01 00:00:00';}
    # $line->[21]支払い状況は会員の場合NULL
    # $line->[22]会員状況(2)
    $line->[22] = ($line->[22] =~ s/^0+//);
    # secret_key
    my $ramdom = $utils->generate_str();
    my $sql = 'UPDATE dtb_customer ';
    $sql .= "SET status=$line->[22],sex=$line->[1],pref=$line->[2],name01='$line->[3]',name02='$line->[4]',kana01='$line->[5]',";
    $sql .= " kana02='$line->[6]',company_name='$line->[7]',company_name2='$line->[8]',zip01='$line->[9]',zip02='$line->[10]',";
    $sql .= "addr01='$line->[11]',addr02='$line->[12]',addr03='$line->[13]',tel01='$line->[14]',tel02='$line->[15]',fax01='$line->[16]',";
    $sql .= "note='$line->[24]',update_date='$dt',customer_type_id=$line->[0]";
    $sql .= " WHERE craft_number='$line->[18]'";
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        return undef;
    }
    return 1;

}

sub updateOnline
{
    my ($pg,$line) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
    $line->[1] = "null" if $line->[1] eq '';
    for(my $i=0; $i< keys $line; $i++) {$line->[$i] =~ s/'/''/g;}
    # $line->[19]保有ポイントTBD
    $line->[19] = 0 if ( !$line->[19]);
    # $line->[20]ポイント有効期限
    my $pexpired = $line->[20];
    if ( length($line->[20]) ){
        my $y = substr($line->[20],0,4);
        my $m = substr($line->[20],4,2);
        my $d = substr($line->[20],6,2);
        $pexpired = sprintf("%4s-%2s-%2s 00:00:00", $y,$m,$d);
    }else{$pexpired = '1970-01-01 00:00:00';}
    # $line->[21]支払い状況は会員の場合NULL
    # $line->[22]会員状況(2)
    $line->[22] = ($line->[22] =~ s/^0+//);
    # secret_key
    my $ramdom = $utils->generate_str();
    my $sql = 'UPDATE dtb_customer ';
    $sql .= "SET status=$line->[22],sex=$line->[1],pref=$line->[2],name01='$line->[3]',name02='$line->[4]',kana01='$line->[5]',";
    $sql .= " kana02='$line->[6]',company_name='$line->[7]',company_name2='$line->[8]',zip01='$line->[9]',zip02='$line->[10]',";
    $sql .= "addr01='$line->[11]',addr02='$line->[12]',addr03='$line->[13]',tel01='$line->[14]',tel02='$line->[15]',fax01='$line->[16]',";
    $sql .= "note='$line->[24]',update_date='$dt',customer_type_id=$line->[0]";
    $sql .= " WHERE client_code='$line->[17]'";
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        return undef;
    }
    return 1;

}

1;

