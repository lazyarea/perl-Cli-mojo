package ImportCsv::CLI::Product;

use strict;
use warnings;
use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use constant DEBUG => 0;
use Data::Dumper;

has description => "say 'Product'.\n";
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

    if ($ARGV[1])    { say 'Product'.$ARGV[1] }
    elsif($ARGV[2] ) { say 'Product'.$ARGV[2] }
    else { say 'Product' }
    &check_file(DEBUG);

};

sub check_file {
    my ($self, $name) = @_;
    warn Dumper $name;
};
1;

