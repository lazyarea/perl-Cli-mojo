package ImportCsv::Data::Dtb::CustomerLicense;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use Text::CSV;
use File::Copy;
use ImportCsv::Data::Base;
use ImportCsv::Data::Dtb::Customer;
use Moment;
use Data::Dumper;
use constant DEBUG => 0; # 1:true
use constant LOG_FILE => 'customer_license.log';
use constant CUSTOMER_KIND_CODE_1 => 2; # 有料会員1
use constant CUSTOMER_KIND_CODE_2 => 3; # 有料会員2

our $utils;

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};

sub load_csv_from_file
{
    my $self = shift;
    my %res = ();
    my $last_customer = '';
    $utils = ImportCsv::Commons::Utils->new('log_file_name' => LOG_FILE);
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
    my $customer = &findCustomer($pg,$line,$file); #既存データ検索
    if ( !$customer ){
        $utils->logger("customer data: not found.");
    }
    my $license;
    $license = &findLicense($pg,{'rrr_name' => "$line->[2]"}) if ( $line->[2] !~ /^[0-9]+$/); # Online
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
    $utils->logger('data not found. from dtb_license.') if (!$hash);
    return $hash;
}

sub deleteCustomerLicense
{
    my ($pg,$customer_id) =@_;
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

sub updateCustomer
{
    my ($pg,$customer_id,$license_id) =@_;
    return undef if ($license_id !~ /^(15|16|17)$/ );
    my $dt = Moment->now->plus(hour=>9)->get_dt();

    my $sql = 'UPDATE dtb_customer SET customer_kind_id=';
    if ($license_id =~ /^(15|16)$/ ){ $sql .= CUSTOMER_KIND_CODE_1;} # 有料会員1
    if ($license_id == 17 ){$sql .= CUSTOMER_KIND_CODE_2;} # 有料会員2
    $sql .=   " WHERE customer_id = $customer_id";
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
}

sub createMember
{
    my ($pg,$customer_id,$license_id) =@_;
    my $dt = Moment->now->plus(hour=>9)->get_dt();
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
    &updateCustomer($pg,$customer_id,$license_id) if ($license_id =~ /^(15|16|17)$/ );
    return $currv;
}

sub createOnline
{
    my ($pg,$customer_id,$license_id) =@_;
    my $dt = Moment->now->plus(hour=>9)->get_dt();
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
    my $next = $pg->db->query("select nextval('dtb_customer_customer_id_seq')");
    my $nextv = $next->hash->{'nextval'};
    &updateCustomer($pg,$customer_id,$license_id) if ($license_id =~ /^(15|16|17)$/ );
    return $nextv;
}
1;
