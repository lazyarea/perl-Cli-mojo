package ImportCsv;
use Mojo::Base 'Mojolicious';

has commands => sub {
    my $commands = shift->SUPER::commands;
    push @{ $commands->namespaces }, 'ImportCSV::CLI';
    return $commands;
};

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
}

1;
