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
use threads::shared;
use Thread::Queue;
use constant MAX_THREADS_NUM => 4;
use constant COLLECT_WAIT_INTV => 50000; # cllect data interval
use constant DEBUG => 1; # 1:true

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};

our $utils;
our $queue;
#our $pg;

sub new
{
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}


sub threads_if
{
    my $self = shift;
    $utils = ImportCsv::Commons::Utils->new;
    my $conn = ImportCsv::Data::Base->new;
    my $pg = $conn->get_conenction();
    my $dt = Moment->now->get_dt();

    # collect data
    $queue = new Thread::Queue;
    my $file = '/var/www/doc/data/YMSTTIME.DAT';
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
#        print "Thread $i($q)\n";
#        create_data($pg,$q);
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
    my ($pg,$d) = @_;
    my $sql = 'INSERT INTO wktb_ymsttime(text)VALUES(?)';
    $pg->db->query($sql,($d));
}
1;
