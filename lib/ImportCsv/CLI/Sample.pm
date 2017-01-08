package ImportCsv::CLI::Sample;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use ImportCsv::Commons::Utils;
use ImportCsv::Data::Plg::Sample;

use constant DEBUG => 0;
use Data::Dumper;

has description => "import point.\n";
has usage => <<EOF;
usage: $0 hoge
These options are available:
  -d --debug debug mode
EOF

sub run {
    my ($self, @args) = @_;

    GetOptionsFromArray(\@args, 'd|debug' => \(my $debug))
        or die $self->usage;

    if ($debug) {
        # $self->appでMojolicious(::Lite)インスタンスが取得できます。
        say "MOJO_HOME: " . $self->app->home;
        say "MOJO_MODE: " . $self->app->mode;
        say "---";
    }

#--------- use Data::Plg::Sample
    my $p = new ImportCsv::Data::Plg::Sample();
    my $res = $p->threads_if();
};


1;

