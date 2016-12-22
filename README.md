# perl-Cli-mojo
## SETUP
    yum install -y perl-local-lib
    yum install -y postgresql-devel      # for PostgreSQL
    perl -Mlocal::lib >> ~/.bash_profile
    cpan -i DBD::Pg Mojolicious Mojo::Pg Digest::MD5 DBD::Pg \
        Text::CSV Time::Moment CGI CGI::Session
## HOW 2 USE
### DB SETTING
    vim lib/ImportCsv/Data/Base.pm
#### local
    $pg = Mojo::Pg->new('postgresql://eccube@/eccube');
#### 153
    $pg = Mojo::Pg->new('postgresql://eccube@153.149.156.108/eccube_dev_share');
### SHOW OPTIONS
    ./bin/import.pl
    Commands:
     Customer  import kihon.
     Product   import shohin.
     ....
