package ImportCsv::Data::Dtb::PointHistory;

use Data::Dumper;
use File::Copy;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use ImportCsv::Data::Base;
use ImportCsv::Commons::Utils;
use Mojo::Base qw/Mojolicious::Command/;
use Mojo::Pg;
use Moment;
use Text::CSV;
use Time::Seconds;

use constant DEBUG => 0;                # 1:true
use constant POINT_STATUS_FIX => 1;
use constant POINT_TYPE_ADD => 3;
use constant POINT_TYPE_USE => 4;
use constant DTB_POINT_STATUS_DONE => 2; #(+)付与済
use constant LOG_FILE => 'point.log';

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};
our $utils;

sub load_csv_from_file
{
    my $self = shift;
    my %res = ();
    $utils = ImportCsv::Commons::Utils->new('log_file_name' => LOG_FILE);
    my $file = $utils->get_file_name($self->commons_config->{'data'}->{'data_dir'}, 'point');
    if ( !$file ) {
        $utils->logger("target not found.");
        exit 1;
    }
    $utils->logger($file.": found.");
    my $fpath = $self->commons_config->{'data'}->{'data_dir'}.'/'.$file;
    if ( ! -f $fpath) {
        $res{'message'} = "file not found: ".$fpath;
        $utils->logger(\%res);
        exit 1;
    }

    # CSV READ START
    my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag();
    my $conn = ImportCsv::Data::Base->new;
    my $pg   = $conn->get_conenction(); # connection error を書く必要がある
    open my $fh, "<:encoding(utf8)", $file or die "$file: $!";

    if ($file =~ /^NVH_POINT/i) {
        load_csv_member($file, $utils, $csv, $pg, $fh);
    } elsif ($file =~ /^FCH_POINT/i) {
        load_csv_online($self, $file, $utils, $csv, $pg, $fh);
    }

    $csv->eof or $csv->error_diag();
    close $fh;

    if ( DEBUG == 0){ move $fpath, $self->commons_config->{'data'}->{'data_moved_dir'}.'/'.$file or die $!; }
    $utils->logger($file.': done');
}

sub load_csv_member
{
    my ($file, $utils, $csv, $pg, $fh) = @_;
    my $c = 0;
    my $prevData = undef;
    my @pointData = ();

    local $@;
    eval{
        my $plgPointInfoId = get_plg_point_info_id($pg);
        my $pointStatus = get_point_status($pg);

        while ( my $row = $csv->getline( $fh ) ) {
            if ($c==0) { $c++; next; }
            next if ($row->[10] !~ /[1-2]/);
            #----------------------------
            # validate start
            #----------------------------
            my $valid = $utils->validateMemberPointHistory($row);
            if ($valid) {
                $valid->{'line_no'} = $c;
                for (keys $valid) {
                    my $k=$_;
                    my $v=$valid->{$k};
                    $utils->logger( "$k => $v");
                }

                next;
            }
            #----------------------------
            # validate end
            #----------------------------

            my $data = parse_member($row);

            if ($prevData && $prevData->{craft_number} ne $data->{craft_number}) {
                register_member($utils, $pg, $plgPointInfoId, $pointStatus, \@pointData);
                @pointData = ();
            }

            push(@pointData, $data);
            $prevData = $data;

            $c++;
        }

        if ($#pointData > -1) {
            register_member($utils, $pg, $plgPointInfoId, $pointStatus, \@pointData);
        }
    };
    if ($@) {
        $utils->logger('FAILED INSERT: '.$file);
        $utils->logger($@);
    }
}

sub load_csv_online
{
    my ($self, $file, $utils, $csv, $pg, $fh) = @_;
    my $c = 0;

    local $@;
    eval{
        while ( my $row = $csv->getline( $fh ) ) {
            if ($c==0) { $c++; next; }
            #----------------------------
            # validate start
            #----------------------------
            my $valid = $utils->validateOnlinePointHistory($row);
            if ($valid) {
                $valid->{'line_no'} = $c;
                for (keys $valid)
                {
                    my $k=$_;
                    my $v=$valid->{$k};
                    $utils->logger( "$k => $v");
                }

                next;
            }

            #----------------------------
            # validate end
            #----------------------------

            my $data = parse_online($row);
            #my $errorFilePath = get_error_file_path($self, $file);
            #register_online($errorFilePath, $utils, $pg, $data);
            my $ret = register_online(undef, $utils, $pg, $data);
            if ( ref $ret){
                $ret->{line_no} = $c;
                for( keys $ret){ $utils->logger( $_.": ".$ret->{$_});}
            }
            $c++;
        }
    };
    if ($@) {
        $utils->logger('FAILED INSERT: '.$file);
        $utils->logger($@);
    }
}

=pod
確定済みのポイント数一覧を返す
\PLugin\Point\Repository\PoingRepository::getFixPointNum($id)
=cut
sub get_fix_point_num
{
    my ($pg, $customer_id) = @_;
    my $sql = "SELECT SUM(p.plg_dynamic_point) AS point_sum
    FROM plg_point AS p
    LEFT JOIN plg_point_customer AS pc on p.plg_point_customer_id = pc.plg_point_customer_id
    INNER JOIN plg_point_status  AS ps on pc.plg_point_customer_id = ps.plg_point_customer_id
    WHERE 1=1
    AND p.customer_id = ? AND ps.status = 1 AND ps.del_flg = 0";
    my $ret = $pg->db->query($sql,$customer_id);
    return $ret->hash->{point_sum} if ($ret->rows > 0);
    # warn Dumper $sql;
    # warn Dumper $ret->hash;
}

sub get_plg_point_info_id
{
    my $pg = $_[0];
    my $ret = $pg->db->query('SELECT max(plg_point_info_id) AS id FROM plg_point_info');
    return $ret->hash->{id} if ($ret->rows > 0);
    return -1;
}

sub get_point_status
{
    my $pg = $_[0];
    my $ret = $pg->db->query('SELECT point_status_id, code FROM dtb_point_status');
    my %status;

    $ret->hashes->each(sub {
            my $d = $_[0];
            $status{$d->{code}} = $d->{point_status_id};
        });
    return \%status;
}

sub parse_member
{
    my $line = $_[0];
    return {craft_number => $line->[1],
            seq_history => $line->[2],
            order_id => int($line->[3]),
            plg_point_before => $line->[4],
            plg_point_current => $line->[5],
            point_status_code => $line->[6],
            point_allocation => $line->[7],
            plg_point_use => $line->[8],
            plg_point_add => $line->[9],
            plg_point_kbn => $line->[10],
            rrr_order_no => $line->[11],
            order_date => $line->[12],
            uri_date => $line->[13]};
}

sub parse_online
{
    my $line = $_[0];
    return {client_code => $line->[0],
#            point_allocation => $line->[9],
            plg_point_add => $line->[9],
            rrr_order_no => $line->[11],
            order_date => $line->[12],
            uri_date => $line->[13]};
}

sub register_member
{
    my ($utils, $pg, $plgPointInfoId, $pointStatus, $dataList) = @_;
    my $tx = $pg->db->begin;
    # 現在保有ポイントが ID の最大値のためリバース
    my @reverseData = reverse(@$dataList);
    my $craftNumber = $reverseData[0]->{'craft_number'};
    my $customerId = get_customer_id_by_craft_number($pg, $craftNumber);

    local $@;
    eval {
        if ($customerId == -1) {
            $utils->logger('ERROR: Unknown craft_number. ' . $craftNumber);
            return;
        }

        return if (!delete_point($utils, $pg, $customerId, $craftNumber) ||
                   !delete_point_status($utils, $pg, $customerId, $craftNumber) ||
                   !delete_point_snapshot($utils, $pg, $customerId, $craftNumber) ||
                   !delete_point_customer($utils, $pg, $customerId, $craftNumber));

        return if (!register_point_customers($utils, $pg, $customerId, \@reverseData) ||
                   !register_point_snapshot($utils, $pg, $customerId, \@reverseData) ||
                   !register_point_status($utils, $pg, $customerId, \@reverseData) ||
                   !register_point($utils, $pg, $plgPointInfoId, $pointStatus, $customerId, \@reverseData));

        $tx->commit;
    };
    if ($@) {
        $utils->logger('ERROR: Failed to register member. customer_id: ' . $customerId . ' craft_number: ' . $craftNumber);
        $utils->logger($@);
    }
    kakutei_kbn2($pg,$utils,$dataList);
}

sub register_online
{
    my ($errorFilePath, $utils, $pg, $data) = @_;
    my $customer_id = get_customer_id_by_client_code($pg,$data->{client_code});
    my %valid = ();
    my $point_snapshot= get_rrr_order_no_from_snapshot($pg, $data,$customer_id);
    if ( !$point_snapshot  ){
        $valid{message} = 'customer_id:'.$customer_id.' AND rrr_order_no: '
        .$data->{rrr_order_no}.' is not found from plg_point_snapshot';
        return \%valid;
    }

    local $@;
    eval{
        update_point_status($utils, $pg, $data,$customer_id);

        my $cur_plg_point_customer = get_last_point_customer($pg, $customer_id); #　紐づけ前のplg_point_customerから最後のレコード抽出
        my $plg_point_customer_id = calculate_point($utils, $pg, $data, $point_snapshot); # 保有ポイント再計算後、plg_point_customerへ最新データを作る
        # plg_point, plg_point_snapshot, plg_point_status のplg_point_customer_idを$plg_point_customer_idへ変える。
        rebind_plg_point($pg, {'new_plg_point_customer_id' => $plg_point_customer_id, 'cur_plg_point_customer_id' => $cur_plg_point_customer->{plg_point_customer_id}});
        ch_dtb_point_stat($pg, $customer_id,{'new_plg_point_customer_id' => $plg_point_customer_id});
    };
    if ($@) {
        $utils->logger($@);
        return {'message' => "Failed at 'sub register_online'"};
    }
=pod
    eval {
        my $count = update_point_status($utils, $pg, $data);
        write_online_error($errorFilePath, $data) if ($count == 0);
    };
    if ($@) {
        $utils->logger('ERROR: Failed to register online. client_code: ' . $data->{'client_code'} .
                      ' rrr_order_no: ' . $data->{'rrr_order_no'});
        $utils->logger($@);
        write_online_error($errorFilePath, $data);
        exit 1;
    }
=cut
}

sub kakutei_kbn2
{
    my ($pg,$utils,$dataList) = @_;
    my $find_cust = 'SELECT plg_point_customer_id FROM plg_point_snapshot WHERE rrr_order_no = ?';
    my $updt_stat = 'UPDATE plg_point_status SET del_flg = 1 WHERE plg_point_customer_id = ?';
#    my $customer_id = -1;

    foreach my $d (@$dataList) {
        next if ($d->{plg_point_kbn} != 2);
        my $plg_point_customer_id = $pg->db->query($find_cust,($d->{rrr_order_no}));
        $pg->db->query($updt_stat,($plg_point_customer_id->hash->{plg_point_customer_id}));
#        my $customer_id = get_customer_id_by_craft_number($pg,$d->{craft_number});
#warn Dumper get_fix_point_num($pg, $customer_id);
    }
}

=pod
plg_point, plg_point_snapshot, plg_point_status のplg_point_customer_idを$plg_point_customer_idへ変える。
=cut
sub rebind_plg_point
{
    my ($pg,$data) = @_;
    $pg->db->query('UPDATE plg_point_status SET plg_point_customer_id = ? WHERE plg_point_customer_id = ?',
        ($data->{new_plg_point_customer_id},$data->{cur_plg_point_customer_id}));
    $pg->db->query('UPDATE plg_point_snapshot SET plg_point_customer_id = ? WHERE plg_point_customer_id = ?',
        ($data->{new_plg_point_customer_id},$data->{cur_plg_point_customer_id}));
    $pg->db->query('UPDATE plg_point SET plg_point_customer_id = ? WHERE plg_point_customer_id = ?',
        ($data->{new_plg_point_customer_id},$data->{cur_plg_point_customer_id}));
}

sub ch_dtb_point_stat
{
    my ($pg, $customer_id,$data) = @_;
    my $sql = "UPDATE plg_point SET dtb_point_status_id = ".DTB_POINT_STATUS_DONE." WHERE 1=1 AND plg_point_customer_id = ? AND dtb_point_status_id = 1";
    local $@;
    eval{
        $pg->db->query($sql,($data->{new_plg_point_customer_id}));
    };
    if ( $@){
        # my $utils = ImportCsv::Commons::Utils->new;
        $utils->logger($@);
    }
}

sub get_customer_id_by_craft_number
{
    my ($pg, $craftNumber) = @_;
    my $ret = $pg->db->query('SELECT customer_id FROM dtb_customer WHERE craft_number = ? ' .
                             'ORDER BY customer_id desc LIMIT 1', ($craftNumber));
    return $ret->hash->{customer_id} if ($ret->rows > 0);
    return -1;
}

sub get_customer_id_by_client_code
{
    my ($pg, $clientCode) = @_;
    my $ret = $pg->db->query('SELECT customer_id FROM dtb_customer WHERE client_code = ? ' .
                             'ORDER BY customer_id desc LIMIT 1', ($clientCode));
    return $ret->hash->{customer_id} if ($ret->rows > 0);
    return -1;
}

sub delete_point
{
    my ($utils, $pg, $customerId, $craftNumber) = @_;

    my $ret = $pg->db->query('DELETE FROM plg_point WHERE customer_id = ?', ($customerId));
    return 1 if ($ret);

    $utils->logger('ERROR: Failed to delete plg_point. customer_id: ' . $customerId . ' craft_number: ' . $craftNumber);
    return 0;
}

sub delete_point_status
{
    my ($utils, $pg, $customerId, $craftNumber) = @_;

    my $ret = $pg->db->query('DELETE FROM plg_point_status WHERE customer_id = ?', ($customerId));
    return 1 if ($ret);

    $utils->logger('ERROR: Failed to delete plg_point_status. customer_id: ' . $customerId .
                   ' craft_number: ' . $craftNumber);
    return 0;
}

sub delete_point_snapshot
{
    my ($utils, $pg, $customerId, $craftNumber) = @_;

    my $ret = $pg->db->query('DELETE FROM plg_point_snapshot WHERE customer_id = ?', ($customerId));
    return 1 if ($ret);

    $utils->logger('ERROR: Failed to delete plg_point_snapshot. customer_id: ' . $customerId .
                   ' craft_number: ' . $craftNumber);
    return 0;
}

sub delete_point_customer
{
    my ($utils, $pg, $customerId, $craftNumber) = @_;

    my $ret = $pg->db->query('DELETE FROM plg_point_customer WHERE customer_id = ?', ($customerId));
    return 1 if ($ret);

    $utils->logger('ERROR: Failed to delete plg_point_customer. customer_id: ' . $customerId .
                   ' craft_number: ' . $craftNumber);
    return 0;
}

sub register_point_customers
{
    my ($utils, $pg, $customerId, $pointData) = @_;

    foreach my $d (@$pointData)
    {
        next if ($d->{plg_point_kbn} == 2);
        my $id = register_point_customer($utils, $pg, $customerId, $d);
        return 0 if ($id == -1);
        $d->{'plg_point_customer_id'} = $id;
    }
    return 1;
}

sub register_point_customer
{
    my ($utils, $pg, $customerId, $data) = @_;

    my $sql = <<'EOS';
INSERT INTO plg_point_customer(plg_point_customer_id, customer_id, plg_point_current, create_date, update_date)
  VALUES(nextval('plg_point_customer_plg_point_customer_id_seq'), ?, ?, now(), now()) RETURNING plg_point_customer_id
EOS
    my $ret = $pg->db->query($sql, ($customerId, $data->{'point_allocation'}));
    return $ret->hash->{plg_point_customer_id} if ($ret);

    $utils->logger('ERROR: Failed to insert plg_point_customer. customer_id: ' . $customerId .
                   ' craft_number: ' . $data->{craft_number});
    return 0;
}

sub register_point_snapshot
{
    my ($utils, $pg, $customerId, $pointData) = @_;

    my $sql = <<'EOS';
INSERT INTO plg_point_snapshot(
  plg_point_snapshot_id
  , order_id
  , customer_id
  , plg_point_use
  , plg_point_current
  , plg_point_add
  , plg_point_snap_action_name
  , create_date
  , update_date
  , plg_point_before
  , order_date
  , uri_date
  , point_allocation
  , seq_history
  , plg_point_customer_id
  , rrr_order_no
  , craft_number)
  VALUES
EOS

    my @values = ();
    my @params = ();

    foreach my $d (@$pointData) {
        next if ($d->{plg_point_kbn} == 2);
        my $value = <<'EOS';
(nextval('plg_point_snapshot_plg_point_snapshot_id_seq')
, ?
, ?
, ?
, ?
, ?
, 'CSV'
, now()
, now()
, ?
, ?
, ?
, ?
, ?
, ?
, ?
, ?)
EOS
        push(@values, $value);
        push(@params, $d->{order_id}, $customerId, abs($d->{plg_point_use}), abs($d->{plg_point_current}), abs($d->{plg_point_add}),
             $d->{plg_point_before}, $d->{order_date}, $d->{uri_date}, $d->{point_allocation}, $d->{seq_history},
             $d->{plg_point_customer_id}, $d->{rrr_order_no}, $d->{craft_number});
    }

    my $ret = $pg->db->query($sql . join(',', @values), @params);
    return 1 if ($ret);

    $utils->logger('ERROR: Failed to insert plg_point_snapshot. customer_id: ' . $customerId .
                   ' craft_number: ' . $pointData->[0]->{craftNumber});
    return 0;
}

sub register_point_status
{
    my ($utils, $pg, $customerId, $pointData) = @_;

    my $sql = <<'EOS';
INSERT INTO plg_point_status(
  point_status_id
  , customer_id
  , status
  , point_fix_date
  , plg_point_customer_id
  , order_id
  , point_expire_date)
  VALUES
EOS

    my @values = ();
    my @params = ();

    foreach my $d (@$pointData) {
        next if ($d->{plg_point_kbn} == 2);
        push(@values, "(nextval('plg_point_status_point_status_id_seq'), ?, ?, ?, ?, ?, ?)");
        my $fixDate = $utils->yyyyMMdd2TimePiece($d->{uri_date});
        push(@params, $customerId, POINT_STATUS_FIX, $fixDate->strftime('%Y-%m-%d'),
             $d->{plg_point_customer_id}, $d->{order_id}, ($fixDate + ONE_YEAR - ONE_DAY)->strftime('%Y-%m-%d 23:59:59'));
    }

    my $ret = $pg->db->query($sql . join(',', @values), @params);
    return 1 if ($ret);

    $utils->logger('ERROR: Failed to insert plg_point_status. customer_id: ' . $customerId .
                   ' craft_number: ' . $pointData->[0]->{craftNumber});
    return 0;
}

sub register_point
{
    my ($utils, $pg, $plgPointInfoId, $pointStatus, $customerId, $pointData) = @_;

    my $sql = <<'EOS';
INSERT INTO plg_point(
  plg_point_id
  , order_id
  , customer_id
  , plg_point_info_id
  , plg_dynamic_point
  , plg_point_type
  , plg_point_action_name
  , create_date
  , update_date
  , plg_point_customer_id
  , dtb_point_status_id)
  VALUES
EOS

    my @values = ();
    my @params = ();

    foreach my $d (@$pointData) {
        next if ($d->{plg_point_kbn} == 2);
        my $pointStatusCode = int($d->{point_status_code});
        push(@values, "(nextval('plg_point_plg_point_id_seq'), ?, ?, ?, ?, ?, 'CSV', now(), now(), ?, ?)");
        push(@params, $d->{order_id}, $customerId, $plgPointInfoId, $d->{plg_point_use},
             POINT_TYPE_USE, $d->{plg_point_customer_id},
             exists($pointStatus->{$pointStatusCode}) ? $pointStatus->{$pointStatusCode} : undef);

        push(@values, "(nextval('plg_point_plg_point_id_seq'), ?, ?, ?, ?, ?, 'CSV', now(), now(), ?, ?)");
        push(@params, $d->{order_id}, $customerId, $plgPointInfoId, $d->{plg_point_add},
             POINT_TYPE_ADD, $d->{plg_point_customer_id},
             exists($pointStatus->{$pointStatusCode}) ? $pointStatus->{$pointStatusCode} : undef);
    }

    my $ret = $pg->db->query($sql . join(',', @values), @params);
    return 1 if ($ret);

    $utils->logger('ERROR: Failed to insert plg_point. customer_id: ' . $customerId .
                   ' craft_number: ' . $pointData->[0]->{craftNumber});
    return 0;
}

=pod
ポイント再計算させる
=cut
sub calculate_point
{
    my ($utils, $pg, $data, $point_snapshot) = @_;
    my $customer_id = get_customer_id_by_client_code($pg, $data->{client_code});
    my $calculateCurrentPoint = get_fix_point_num($pg, $customer_id);
    my %params=();
    $params{customer_id} = $customer_id;
    $params{plg_point_current} = $calculateCurrentPoint; # ポイント更新後の値
    $params{last_point_customer_id} = $point_snapshot->{plg_point_customer_id};
    my $id = register_point_customer($utils, $pg, $customer_id, {'point_allocation' => $calculateCurrentPoint});
    return $id;
}

sub update_point_status
{
    my ($utils, $pg, $data, $customer_id) = @_;

    my $sql = <<'EOS';
UPDATE plg_point_status SET
  status = ?, point_fix_date = ?
WHERE
  plg_point_customer_id IN (SELECT plg_point_customer_id
    FROM plg_point_snapshot WHERE customer_id = ? AND rrr_order_no = ?)
EOS

    my $ret = $pg->db->query($sql, (POINT_STATUS_FIX, $utils->yyyyMMdd2TimePiece($data->{uri_date})->strftime('%Y-%m-%d'),
            $customer_id, $data->{rrr_order_no}));
    return $ret->rows;
}

sub update_point_snapshots_re
{
    my ($pg, $data) = @_;
    # my $sql = create_update_sql('plg_point_status', $data);
    my $sql = 'UPDATE plg_point_snapshot SET plg_point_customer_id = ? WHERE 1=1  AND plg_point_customer_id = ?';
    my $ret = $pg->db->query($sql, ($data->{plg_point_customer_id},$data->{last_point_customer_id}));
}

sub update_point_status_re
{
    my ($pg, $data) = @_;
    # my $sql = create_update_sql('plg_point_status', $data);
    my $sql = 'UPDATE plg_point_status SET plg_point_customer_id = ? WHERE 1=1  AND plg_point_customer_id = ?';
    my $ret = $pg->db->query($sql, ($data->{plg_point_customer_id},$data->{last_point_customer_id}));
}

sub update_point_snapshots
{
    my ($utils, $pg, $data) = @_; # いらなくなった感じ
#    my $sql = 'update plg_point_snapshot SET plg_point_add = ? WHERE rrr_order_no = ? AND client_code = ?';
#    my $ret = $pg->db->query($sql, ($data->{plg_point_add}, $data->{rrr_order_no}, $data->{client_code}));
}

sub create_point_customer{
    my ($pg,$data) = @_;
    # my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->plus(hour=>9)->get_dt();
    my $nextval = $pg->db->query("SELECT nextval('plg_point_customer_plg_point_customer_id_seq')");
    my $sql = 'INSERT INTO plg_point_customer(plg_point_customer_id,customer_id, plg_point_current,
         create_date,update_date) VALUES (?,?,?,?,?)';
    my $ret = $pg->db->query($sql,($nextval->hash->{nextval},$data->{customer_id},$data->{plg_point_current},$dt,$dt));

    # get lastval from plg_point_customer
    $ret = undef;
    $ret = $pg->db->query("select currval('plg_point_customer_plg_point_customer_id_seq')"); # get currval
    my $hash = $ret->hash;
    my %params = ();
    $params{plg_point_customer_id} = $hash->{currval};
    $params{last_point_customer_id} = $data->{last_point_customer_id};
    update_point_snapshots_re ($pg, \%params);
    update_point_status_re($pg, \%params);
}

sub get_rrr_order_no_from_snapshot
{
    my ($pg,$data,$customer_id) = @_;
    return undef if ( !$data->{rrr_order_no});
    my $sql = 'SELECT * FROM plg_point_snapshot WHERE customer_id = ? AND rrr_order_no = ?';
    my $ret = $pg->db->query($sql, ($customer_id,$data->{rrr_order_no}));
    my $hash = $ret->hash;
    if ( !$hash ){
        return undef;
    }
    return $hash;
}

sub get_last_point_customer
{
    my ($pg,$customer_id) = @_;
    return undef if (!$customer_id);
    my $sql = "SELECT * FROM plg_point_customer WHERE customer_id = ? ORDER BY plg_point_customer_id DESC LIMIT 1";
    my $ret = $pg->db->query($sql, ($customer_id));
    my $hash = $ret->hash;
    return $hash;
}

sub get_error_file_path
{
    my ($self, $file) = @_;
    return $self->commons_config->{'data'}->{'log_dir'}.'/err_'.$file;
}

sub write_online_error
{
    my ($errorFilePath, $data) = @_;
    # my $utils = ImportCsv::Commons::Utils->new;
    for(keys $data){
        my $k=$_;
        my $v=$data->{$k};
        $utils->logger( "$k => $v");
    }
    return undef;

#    my $csv = Text::CSV->new ( { binary => 1, eol => "\n" } ) or die "Cannot use CSV: ".Text::CSV->error_diag();
#    open my $fh, ">>:encoding(utf8)", $errorFilePath or die "$errorFilePath: $!";
#    $csv->print($fh, [$data->{client_code}, $data->{rrr_order_no}]);
#    close $fh;
}

1;
