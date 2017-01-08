package ImportCsv::Data::Plg::Sample;

use Mojo::Base qw/Mojolicious::Command/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Pg;
use ImportCsv::Data::Base;
use ImportCsv::Commons::Utils;
use Moment;
use Data::Dumper;
use threads ('yield',
             'stack_size' => 64*4096,
             'exit' => 'threads_only',
             'stringify');
use Thread::Queue;
use constant MAX_THREADS_NUM => 5;
use constant COLLECT_WAIT_INTV => 30000; # cllect data interval
use constant DEBUG => 1; # 1:true

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};
has utils => sub{
     return ImportCsv::Commons::Utils->new;
};

our $pg;
our $queue;

sub new
{
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}


sub threads_if
{
    my $self = shift;
    my $utils = ImportCsv::Commons::Utils->new;
    my $dt = Moment->now->get_dt();

    # collect data
    $queue = new Thread::Queue;
    my $file = '/home/lazyarea/GITWORKS/perl-Cli-mojo/data/sample.txt';
    my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag();
    open my $fh, "<:encoding(shiftjis)", $file or die "$file: $!";
    my $c=0;
    while (my $row = $csv->getline( $fh ) ) {
        $queue->enqueue($row->[0]);
        sleep 1 if (($c % COLLECT_WAIT_INTV)== 0);
        warn Dumper $c if (($c % COLLECT_WAIT_INTV)== 0);
        $c++;
        $row = undef;
    }
    $csv->eof or $csv->error_diag();
    close $fh;

    # create thread
    my @threads;
    #for(my $i=0; $i<5; $i++){
    #    my $thread = threads->new(\&my_thread, $i);
    foreach(1 .. MAX_THREADS_NUM){
        my $thread = threads->new(\&my_thread, $_);
        push(@threads, $thread);
        $queue->enqueue(undef);
    }
    for (@threads){
        my($ret) = $_->join;
        print "ret close\n";
    }
}

sub my_thread
{
    my $i = shift;
    while( my $q = $queue->dequeue){
        print "Thread $i($q)\n";
        threads->yield();
        sleep 1/10;
    }
}

sub my_thread1
{
    my $i = shift;
    foreach(0..3){
        print "Thread $i($_)\n";
        threads->yield();
        #sleep(1);
    }
    return ($i);
}

sub create_data
{
    my $self = shift;
}
1;
