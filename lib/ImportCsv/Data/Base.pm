package ImportCsv::Data::Base;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
# use ImportCsv::Commons::Utils;
use Data::Dumper;
use constant DEBUG => 0;

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};

sub get_conenction
{
    my ($self, @args) = @_;
    my $pg = undef;
    eval{
        $pg = Mojo::Pg->new('postgresql://'.$self->commons_config->{'database'}->{'user'}.'@'
            .$self->commons_config->{'database'}->{'host'}.'/'.$self->commons_config->{'database'}->{'dbname'});
        $pg->password($self->commons_config->{'database'}->{'password'});
#        $pg->options({AutoCommit => 1, RaiseError => 1});
    };
    local $@;
    if ($@){
        # $u->logger($@);
        exit 1;
    }
    &check_connected($pg);
    return $pg;
}

sub check_connected
{
    my ($pg) = @_;
    # my $utils = ImportCsv::Commons::Utils->new;
    my $sql = 'SELECT version();';
    my $ret = undef;
    local $@;
    eval{
        $ret = $pg->db->query($sql);
    };
    if ($@) {
        # $utils->logger('DB connection error');
        # $utils->logger($@);
        exit 1;
    }
}


1;
