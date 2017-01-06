# perl-Cli
## SETUP
    yum install -y perl-local-lib
    yum install -y postgresql-devel      # for PostgreSQL
    perl -Mlocal::lib >> ~/.bash_profile
    cpan -i DBD::Pg Mojolicious Mojo::Pg Digest::MD5 DBD::Pg \
        Text::CSV Moment CGI CGI::Session DBI version Encode　\
        YAML YAML::XS
## HOW 2 USE
### DB SETTING
    vim lib/ImportCsv/Commons/Config
    #edit constants.
### SHOW OPTIONS
    ./bin/import.pl
    Commands:
     Customer  import kihon.
     Product   import shohin.
     ....
