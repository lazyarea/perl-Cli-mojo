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
    my $class = shift;
    my $self = {};
    my $dbhost = DBHOST;
    my $dbname = DBNAME;
    my $dbuser = DBUSER;
    my $dbpasswd = DBPASSWD;
    my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$host;port=$port;options=$options",
            $username,$password,
            {AutoCommit => 0, RaiseError => 1, PrintError => 0});
    return bless $self, $class, $dbh;
}

1;

