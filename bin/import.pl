#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
BEGIN {
    # パスは環境にあわせて変更してください
    unshift @INC, "$FindBin::Bin/../lib";
    $ENV{MOJO_HOME} = $FindBin::Bin
      unless $ENV{MOJO_HOME};
}

require Mojolicious::Commands;
my $cmd = Mojolicious::Commands->new;
$cmd->namespaces([qw/MyApp::CLI/]); # Mojolicious::Command::* は利用しない
$cmd->namespaces([qw/ImportCsv::CLI/]); # Mojolicious::Command::* は利用しない

$cmd->run(@ARGV);

