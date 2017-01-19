package ImportCsv::Data::Mtb::BlackRank;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use ImportCsv::Data::Base;
use Moment;
use Data::Dumper;

use constant DEBUG => 0; # 1:true

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};

sub get_black_rank_id
{
    my ($self, $pg, $val) = @_;
    # my $utils = ImportCsv::Commons::Utils->new;
    my $sql = "SELECT id from mtb_black_rank WHERE name like '$val%'";
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        # $utils->logger($sql);
        # $utils->logger($@);
    }
    my $hash = $ret->hash;
    return $hash;
}

1;
