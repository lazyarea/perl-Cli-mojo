package ImportCsv::Data::Base;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use CGI::Session;
use Data::Dumper;
use constant DEBUG => 0;
use constant DBHOST   => 'localhost';
use constant DBNAME   => 'eccube';
use constant DBUSER   => 'eccube';
use constant DBPASSWD => 'eccube';

sub get_conenction
{
    my ($self, @args) = @_;
#    my $session = CGI::Session->new(undef,undef,{Directory => '/tmp'});
#    $session->expire('+30m');
#    $session->param('pg',1);
#    warn Dumper  $session->param('pg');
    my $pg = Mojo::Pg->new('postgresql://eccube@/eccube');
    $pg->password('Password1');
    return $pg;
}

1;

