package ImportCsv::Data::Wktb::YmstArea;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use Text::CSV;
use File::Copy;
use ImportCsv::Commons::Config;
use ImportCsv::Commons::Utils;
use ImportCsv::Data::Base;
use Moment;
use Data::Dumper;

use constant DEBUG => 0; # 1:true
use constant LOG_FILE => 'ymst.log';

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};

our $utils;

sub new {
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}

sub load_csv_from_file
{
    my $self = shift;
    my %res = ();
    $utils = ImportCsv::Commons::Utils->new('log_file_name' => LOG_FILE);
    my $file = $utils->get_file_name($self->commons_config->{'data'}->{'data_dir'}, 'YMSTAREA');
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
    open my $fh, "<:encoding(shiftjis)", $file or die "$file: $!";
    my $conn = ImportCsv::Data::Base->new;
    my $pg   = $conn->get_conenction(); # connection error を書く必要がある
    my $c = 0;
    # BEGIN TRANSACTION
    #$pg->db->begin;
    local $@;
    eval{
        &truncateArea( $pg );
        while ( my $row = $csv->getline( $fh ) ) {
            #if ($c==0){ $c++; next} # non header file.
            &createArea( $pg, $row );
            $row = undef;
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
    local $@;
    eval{
        &insertArea($pg);
    };
    if ($@){
        $utils->logger('FAILED (wktb to dtb): '.$file);
        $utils->logger($@);
        exit 1;
    }
    if ( DEBUG == 0){ move $fpath, $self->commons_config->{'data'}->{'data_moved_dir'}.'/'.$file or die $!; }
    $utils->logger($file.': done');
}

sub truncateArea
{
    my ($pg) = @_;
    my $sql = 'TRUNCATE wktb_ymstarea';
    local $@;
    eval{
        $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        $utils->logger("FAILED TRUNCATE wktb_ymstarea.");
    }
    $sql = undef;
    $sql = 'TRUNCATE dtb_ymstarea';
    local $@;
    eval{
        $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        $utils->logger("FAILED TRUNCATE dtb_ymstarea.");
    }
}

sub createArea
{
    my ($pg,$line) = @_;

    my $sql = "INSERT INTO wktb_ymstarea (text) VALUES ('$line->[0]')";
    local $@;
    eval{
        $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }
    $line = undef;
}

sub insertArea
{
    my $pg = shift;

    my $cols = '';
    for( my $i=0; $i<35;$i++){$cols .= ',col'.$i;}
    $cols =~ s/^,//;
    my $sql = 'INSERT INTO dtb_ymstarea ('.$cols.') SELECT * from vtb_ymstarea';
    local $@;
    eval{
        $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }
}

1;
