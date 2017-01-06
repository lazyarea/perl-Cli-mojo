package ImportCsv::Data::Wktb::YmstMtrx;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use Text::CSV;
use File::Copy;
use ImportCsv::Commons::Config;
use ImportCsv::Data::Base;
use Moment;
use Data::Dumper;

use constant DEBUG => 0; # 1:true

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};
has utils => sub{
     return ImportCsv::Commons::Utils->new;
};

sub new {
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}

sub load_csv_from_file
{
    my $self = shift;
    my %res = ();
    my $utils = ImportCsv::Commons::Utils->new;
    my $file = $self->utils->get_file_name($self->commons_config->{'data'}->{'data_dir'}, 'YMSTMTRX');
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
        &truncateMtrx( $pg );
        while ( my $row = $csv->getline( $fh ) ) {
            #if ($c==0){ $c++; next} # non header file.
            &createMtrx( $pg, $row );
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
        &insertMtrx($pg);
    };
    if ($@){
        $utils->logger('FAILED (wktb to dtb): '.$file);
        $utils->logger($@);
        exit 1;
    }
    if ( DEBUG == 0){ move $fpath, $self->commons_config->{'data'}->{'data_moved_dir'}.'/'.$file or die $!; }
    $utils->logger($file.': done');
}

sub truncateMtrx
{
    my ($pg) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $sql = 'TRUNCATE wktb_ymstmtrx';
    local $@;
    eval{
        $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        $utils->logger("FAILED TRUNCATE wktb_ymstmtrx.");
    }
    $sql = undef;
    $sql = 'TRUNCATE dtb_ymstmtrx';
    local $@;
    eval{
        $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
        $utils->logger("FAILED TRUNCATE dtb_ymstmtrx.");
    }
}

sub createMtrx
{
    my ($pg,$line) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
    my $sql = "INSERT INTO wktb_ymstmtrx (text) VALUES ('$line->[0]')";
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

sub insertMtrx
{
    my $pg = shift;
    my $utils = ImportCsv::Commons::Utils->new;
    my $cols = '';
    for( my $i=0; $i<305;$i++){$cols .= ',col'.$i;}
    $cols =~ s/^,//;
    my $sql = 'INSERT INTO dtb_ymstmtrx ('.$cols.') SELECT * from vtb_ymstmtrx';
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

