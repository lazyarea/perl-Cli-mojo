package ImportCsv::Data::Mtb::Pref;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use ImportCsv::Data::Base;
use Moment;
use Data::Dumper;

use constant DEBUG => 0; # 1:true
#use constant DATA_DIR => '/var/www/doc/data';
#use constant DATA_MOVED_DIR => '/var/www/doc/data/moved';

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};

our $log_file_name;

sub new {
    my ($class, %args) = @_;
    my $self = {%args};
    $log_file_name = $self->{log_file_name};
    return bless $self, $class;
}

sub get_pref_id
{
    my ($self, $pg, $val) = @_;
    my $utils = ImportCsv::Commons::Utils->new('log_file_name' => $log_file_name);
    my $sql = "SELECT id from mtb_pref WHERE name = '$val'";
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        $utils->logger($sql);
        $utils->logger($@);
    }
    my $hash = $ret->hash;
    return $hash;
}

1;
