package ImportCsv::Data::Dtb::CustomerAddress;

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
            if ($file =~ /^NVH_NOHIN/i) {
                $valid = $utils->validateMemberKihon($row);
            }elsif($file =~ /^FCH_NOHIN/i) {
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
            &create_or_updateCustomerAddress($pg,$row, $file);
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

sub create_or_updateCustomerAddress
{
    my($pg, $line, $file) = @_;
    my $data = &findCustomerAddress($pg,$line,$file); #既存データ検索

    my $ret = undef;
    if ( !$data ){
        if ($file =~ /^NVH_NOHIN/i) {
            $ret = &createMember($pg,$line);
        }elsif($file =~ /^FCH_NOHIN/i){
            $ret = &createOnline($pg,$line);
        }

#        return $ret;
    }else{
        if ($file =~ /^NVH_NOHIN/i) {
            $ret = &updateMember($pg,$line);
        }elsif($file =~ /^FCH_NOHIN/i){
            $ret = &updateOnline($pg,$line);
        }
        return undef;
    }
}

sub findCustomerAddress
{
    my ($pg,$line,$file) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
=pod
    my $sql = 'SELECT * FROM dtb_customer';
    if ($file =~ /^NVH_NOHIN/i) {
        $sql .= " WHERE craft_number='$line->[18]'" if $line->[18];
    }elsif($file =~ /^FCH_NOHIN/i) {
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
=cut
}

sub createMember
{
    my ($pg,$line) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
=pod
    $utils->logger($sql) if DEBUG==1;
    my $next = $pg->db->query("select nextval('dtb_customer_customer_id_seq')");
    my $nextv = $next->hash->{'nextval'};
    return $nextv;
=cut
}

sub createOnline
{
    my ($pg,$line) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
=pod
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
=cut
}

sub updateMember
{
    my ($pg,$line) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
=pod
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
=cut
}

sub updateOnline
{
    my ($pg,$line) =@_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();
=pod
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
=cut
}

1;

