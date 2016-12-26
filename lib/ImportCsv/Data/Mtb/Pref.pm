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
has utils => sub{
     return ImportCsv::Commons::Utils->new;
};

sub get_pref_id
{
    my ($self, $pg, $val) = @_;
    my $utils = ImportCsv::Commons::Utils->new;
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
