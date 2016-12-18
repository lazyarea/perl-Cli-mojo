package ImportCsv::Data::Base;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use Data::Dumper;
use constant DEBUG => 0;
use constant DBHOST   => 'localhost';
use constant DBNAME   => 'eccube';
use constant DBUSER   => 'eccube';
use constant DBPASSWD => 'eccube';


sub new {
    # SEE: http://mojolicious.org/perldoc/Mojo/Pg
    my $self = shift;
    my $pg = Mojo::Pg->new('postgresql://eccube@/eccube');
    $pg->password('Password1');
    $pg->options({AutoCommit => 1, RaiseError => 1});
}

1;

