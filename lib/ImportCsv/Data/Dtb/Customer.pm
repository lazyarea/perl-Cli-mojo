package ImportCsv::Data::Dtb::Customer;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use CGI::Session;
use Text::CSV;
use File::Copy;
use ImportCsv::Data::Base;
#use ImportCsv::Data::Dtb::ProductStock;
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
    my $file = $utils->get_file_name(DATA_DIR, 'kihon');
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
            #-----------------------------skip
            if ($row->[0] =~ /(3|4)/ ){
                $utils->logger($c.'行目：会員種別'.$row->[0]);
                next;
            }
            ##----------------------------validate start
            my $valid = undef;
            if ($file =~ /^NVH_KIHON/i) {
                $valid = $utils->validateMemberKihon($row);
            }elsif($file =~ /^FCH_KIHON/i) {
                $valid = $utils->validateOnlineKihon($row);
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
            &create_or_updateCustomer($pg,$row, $file);
            #----------------------------
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
    if ( DEBUG == 0){ move $fpath, DATA_MOVED_DIR.'/'.$file or die $!; }
    $utils->logger($file.': done');
}

sub create_or_updateCustomer
{
    my($pg, $line, $file) = @_;
    my $data = &findCustomer($pg,$line,$file); #既存データ検索

    my $ret = undef;
    if ( !$data ){
        if ($file =~ /^NVH_KIHON/i) {
            $ret = &createMember($pg,$line);
#        }elsif($file =~ /^FCH_KIHON/i){
        }

#        return $ret;
    }else{
        if ($file =~ /^NVH_KIHON/i) {
            $ret = &updateMember($pg,$line);
#        }elsif($file =~ /^FCH_KIHON/i){
        }
        #&updateCustomer($pg, $line);
        return undef;
    }
}

sub findCustomer
{
    my ($pg,$line,$file) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $sql = 'SELECT * FROM dtb_customer';
    if ($file =~ /^NVH_KIHON/i) {
        $sql .= " WHERE craft_number='$line->[18]'" if $line->[18];
    }elsif($file =~ /^FCH_KIHON/i) {
        $sql .= " WHERE client_code='$line->[17]'" if $line->[17];
    }
    my $ret = undef;
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

sub createMember
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
    my $sql = 'INSERT INTO dtb_customer(status,sex,pref,name01,name02,kana01,kana02,company_name,company_name2,zip01,zip02,addr01,addr02,addr03,tel01,tel02,fax01,note,create_date,update_date,del_flg,client_code,craft_number,customer_type_id,customer_kind_id,customer_situation_id,customer_division_id,black_rank,markup_rate,realize_point,point_expiration_date,secret_key) VALUES(';
    $sql .= "$line->[22], $line->[1], $line->[2], '$line->[3]', '$line->[4]', '$line->[5]', '$line->[6]', '$line->[7]', '$line->[8]', '$line->[9]', '$line->[10]', '$line->[11]', '$line->[12]', '$line->[13]', '$line->[14]', '$line->[15]', '$line->[16]', '$line->[24]', '$dt', '$dt', 0, null, '$line->[18]', $line->[0], 1, 1, 1, null, 1, $line->[19], '$pexpired', '$ramdom')";
    my $ret = undef;
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
    $sql .= "status=$line->[22],sex=$line->[1],pref=$line->[2],name01='$line->[3]',name02='$line->[4]',kana01='$line->[5]',";
    $sql .= " kana02='$line->[6]',company_name='$line->[7]',company_name2='$line->[8]',zip01='$line->[9]',zip02='$line->[10]',";
    $sql .= "addr01='$line->[11]',addr02='$line->[12]',addr03='$line->[13]',tel01='$line->[14]',tel02='$line->[15]',fax01='$line->[16]',";
    $sql .= "note='$line->[24]',update_date='$dt',customer_type_id=$line->[0],realize_point=$line->[19],point_expiration_date='$pexpired'";
    $sql .= " WHERE craft_number='$line->[18]'";
    my $ret = undef;
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

