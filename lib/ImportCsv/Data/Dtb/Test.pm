package ImportCsv::Data::Dtb::Test;

use Mojo::Base qw/Mojolicious::Command ImportCsv::Data::Base/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use CGI::Session;
use Text::CSV;
use File::Copy;
#use ImportCsv::Data::Base;
use ImportCsv::Commons::Config;
use ImportCsv::Data::Base;
use ImportCsv::Data::Mtb::Pref;
use Moment;
use Data::Dumper;

use constant DEBUG => 0; # 1:true
#has common_config => sub {print 1;};
has description => "import shohin.\n";
has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};
#sub new {
#    my $class = shift;
#    my $self = {};
#    return bless $self, $class;
#}

sub findTest
{
    my $self = shift;
    #warn Dumper  $self->config->{database};
    my $pref = ImportCsv::Data::Mtb::Pref->new;
    my $pg = ImportCsv::Data::Base->new;

    warn Dumper $self->commons_config;
    warn Dumper $pref->get_pref_id($pg->get_conenction(), '埼玉県');
}


1;

