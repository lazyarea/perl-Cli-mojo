package ImportCsv::CLI::YmstMtrx;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use ImportCsv::Data::Wktb::YmstMtrx;

use constant DEBUG => 0;
use Data::Dumper;

has description => "import YmstMtrx.\n";
has usage => <<EOF;
usage: $0 hoge
These options are available:
  -d --debug debug mode
EOF

sub run {
    my ($self, @args) = @_;

    GetOptionsFromArray(\@args, 'd|debug' => \(my $debug))
        or die $self->usage;
#--------- use Data::DTB::Product
    my $p = new ImportCsv::Data::Wktb::YmstMtrx();
    my $res = $p->load_csv_from_file();
};


1;
