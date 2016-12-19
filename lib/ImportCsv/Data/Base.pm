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
use constant DBPASSWD => 'Password1';
use constant AUTOCOMMIT => 0;
use constant RAISEERROR => 1;

sub get_conenction
{
    my ($self, @args) = @_;
#    my $session = CGI::Session->new(undef,undef,{Directory => '/tmp'});
#    if ( !$session->param('pg') ){
#        warn Dumper " not found Session: pg";
#        $session->expire('+30m');
#        warn Dumper  $session->param('pg');
        my $pg = Mojo::Pg->new('postgresql://eccube@/eccube');
        $pg->password(DBPASSWD);
#       $pg->options({AutoCommit => 0, RaiseError => 1});
#        $session->param('pg',$pg);
#    }
#    return $session->param('pg');
    return $pg;
}

1;

