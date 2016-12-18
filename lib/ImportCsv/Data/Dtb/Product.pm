package ImportCsv::Data::Dtb::Product;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use ImportCsv::Data::Base;
use Data::Dumper;
use constant DEBUG => 0;


sub new
{
    my $class = shift;
    my $self = {};
#    my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$host;port=$port;options=$options",
#            $username,$password,
#            {AutoCommit => 0, RaiseError => 1, PrintError => 0});
#    return bless $self, $class, $dbh;
}

sub fild
{
    my $self = shift;

}

1;

