# perl-Cli-mojo
## SETUP
    yum install -y perl-local-lib
    yum install -y postgresql-devel      # for PostgreSQL
    perl -Mlocal::lib >> ~/.bash_profile
    cpan -i DBD::Pg Mojolicious Mojo::Pg
