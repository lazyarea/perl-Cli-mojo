package ImportCsv::Data::Wktb::YmstPost;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use CGI::Session;
use ImportCsv::Data::Base;
use Moment;
use Data::Dumper;

use constant DEBUG => 0; # 1:true
use constant DATA_DIR => '/var/www/doc/data';
use constant DATA_MOVED_DIR => '/var/www/doc/data/moved';

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};
has utils => sub{
     return ImportCsv::Commons::Utils->new;
};


1;
