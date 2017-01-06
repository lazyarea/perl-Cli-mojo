package ImportCsv::Commons::Utils;

use Mojo::Base qw/Mojolicious::Command/;
use Mojo::Log;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use constant DEBUG => 0;
use constant DATA_DIR => '/var/www/doc/data';
use constant LOG_DIR  => '/tmp';
use constant LOG_FILE  => '/mojo.log';
use Text::CSV;
use Data::Dumper;
use ImportCsv::Commons::Config;
use Time::Piece;

has commons_config => sub {
    my $config = ImportCsv::Commons::Config->new;
    $config->load_config();
};

sub new {
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}

sub get_file_name
{
    my ($self, $path, $fname ) = @_;
    chdir($path);
    my @file = glob "*.csv *.DAT *.dat)";
    # warn Dumper join( "\t", @file ), "\n";
    foreach my $file (@file){
        if ($file =~ /$fname/i){
            return $file;
        }
    }
}

#    my %valid = ();
#    if ( my $res = &len('aaaaa', 3) ){
#        $valid{'aaaaa'} = 'too long:'.$res;
#    }
#    if ( my $res = &len('bbbb', 3) ){
#        $valid{'bbbb'} = 'too long:'.$res;
#    }
#    my $log = Mojo::Log->new;
#    $log = Mojo::Log->new(path => '/tmp/mojo.log', level => 'info');
#    $log->info(%valid);
#    for(keys %valid){
#        my $k=$_;
#        my $v=$valid{$k};
#        $log->info( "$k => $v");
#    }
#
sub logger
{
    my ($self,$data) = @_;
    my $log = Mojo::Log->new(path => $self->commons_config->{'log'}->{'log_dir'}
	.$self->commons_config->{'log'}->{'log_file'}, level => 'info');
    $log->info($data);
}

sub len
{
    my ($str, $limit) = @_;
    if ( length($str) > $limit){
        return length($str);
    }
    return undef;
}

sub is_numeric
{
    my $str = shift;
    if ( $str =~ /^-\d+$/ ){
        return 1;
    }elsif ( $str =~ /^\d+$/ ){
        return 1;
    }
    return undef;
}

sub generate_str
{
    my $self = shift;
    my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);
    return join '', map $alphanumeric[rand @alphanumeric], 0..8;

}

sub escape_quote
{
    my $str = shift;
    return $str =~ s/'/''/g;
}


sub validateOnlineShohin
{
    my ($self,$line) = @_;
    my %valid = ();
    if ( &len($line->[0], 40) ){
        $valid{$line->[0]} = 'too long';
    }
    if ( !&is_numeric($line->[1]) ){
        $valid{$line->[1]} = 'is not numeric.';
    }
    if ( !&is_numeric($line->[2]) ){
        $valid{$line->[2]} = 'is not numeric.';
    }
    if ( !&is_numeric($line->[3]) ){
        $valid{$line->[3]} = 'is not numeric.';
    }
    if ( 0 != $line->[4] ){
        $valid{$line->[4]} = 'is not 0.';
    }
    if ( &len($line->[6],11) ){
        $valid{$line->[6]} = 'is too long.';
    }
    if ( $line->[7] =~ /^-[0-9]+$/ ){
    }elsif ( !&is_numeric($line->[7] ) ){
        $valid{$line->[7]."_length"} = ' stock is too long.';
    }
#    if ( !&is_numeric($line->[7]) ){
#        $valid{$line->[7]."_numeric"} = ' stock is not numeric.';
#    }
    if ( !&is_numeric($line->[8]) ){
        $valid{$line->[8]} = 'is not numeric.';
    }
    return \%valid if (keys %valid);
}

sub validateMemberShohin
{
    my ($self,$line) = @_;
    my %valid = ();
    if ( &len($line->[0], 40) ){
        $valid{$line->[0]} = 'too long';
    }
    if ( !&is_numeric($line->[1]) ){
        $valid{$line->[1]} = 'is not numeric.';
    }
    if ( !&is_numeric($line->[2]) ){
        $valid{$line->[2]} = 'is not numeric.';
    }
    if ( $line->[3] != 1 ){
        $valid{$line->[3]} = 'is not 1.';
    }
#    if ( 1 === $line->[4] ){
#        $valid{$line->[4]} = 'is not 0.';
#    }
    if ( &len($line->[6],11) ){
        $valid{$line->[6]} = 'is too long.';
    }
    if ( &len($line->[7],9) ){
        $valid{$line->[7]."_length"} = 'is too long.';
    }
    if ( $line->[7] =~ /^-[0-9]+$/ ){
    }elsif ( !&is_numeric($line->[7]) ){
        $valid{$line->[7]."_numeric"} = 'is not numeric.';
    }
    if ( !&is_numeric($line->[8]) ){
        $valid{$line->[8]} = 'is not numeric.';
    }
    return \%valid if (keys %valid);
}


sub validateMemberKihon
{
    my ($self,$line) = @_;
    my %valid = ();
    if ( &len($line->[3],20) ){
        $valid{$line->[3]} = 'is too long.';
    }
    if ( &len($line->[4],20) ){
        $valid{$line->[4]} = 'is too long.';
    }
    if ( &len($line->[5],20) ){
        $valid{$line->[5]} = 'is too long.';
    }
    if ( &len($line->[6],20) ){
        $valid{$line->[6]} = 'is too long.';
    }
#    $line->[8] = &escape_quote($line->[8]);
#    $line->[9] = &escape_quote($line->[9]);
#    warn Dumper $line;
    if ( &len($line->[11],40) ){
        $valid{$line->[11]} = 'is too long.';
    }
    if ( &len($line->[12],30) ){
        $valid{$line->[12]} = 'is too long.';
    }
    if ( &len($line->[13],30) ){
        $valid{$line->[13]} = 'is too long.';
    }
    if ( !$line->[18] ){
        $valid{$line->[18]} = 'craft_number is not exists.';
    }
    return \%valid if (keys %valid);
}

sub validateOnlineKihon
{
    my ($self,$line) = @_;
    my %valid = ();
    if ( &len($line->[3],20) ){
        $valid{$line->[3]} = 'is too long.';
    }
    if ( &len($line->[4],20) ){
        $valid{$line->[4]} = 'is too long.';
    }
    if ( &len($line->[5],20) ){
        $valid{$line->[5]} = 'is too long.';
    }
    if ( &len($line->[6],20) ){
        $valid{$line->[6]} = 'is too long.';
    }
    if ( &len($line->[11],40) ){
        $valid{$line->[11]} = 'is too long.';
    }
    if ( &len($line->[12],30) ){
        $valid{$line->[12]} = 'is too long.';
    }
    if ( &len($line->[13],30) ){
        $valid{$line->[13]} = 'is too long.';
    }
    if ( !$line->[17] ){
        $valid{$line->[17]} = 'client_code is not exists.';
    }
    return \%valid if (keys %valid);
}

sub validateMemberNohin
{
    my ($self,$line) = @_;
    my %valid = ();

    if ( &len($line->[3],20) ){
        $valid{$line->[3]} = 'is too long.';
    }
    if ( &len($line->[3],20) ){
        $valid{$line->[3]} = 'is too long.';
    }
    if ( &len($line->[3],20) ){
        $valid{$line->[3]} = 'is too long.';
    }
    return \%valid if (keys %valid);
}

sub validateOnlineNohin
{
    my ($self,$line) = @_;
    my %valid = ();

    if ( &len($line->[3],20) ){
        $valid{$line->[3]} = 'is too long.';
    }
    if ( &len($line->[3],20) ){
        $valid{$line->[3]} = 'is too long.';
    }
    if ( &len($line->[3],20) ){
        $valid{$line->[3]} = 'is too long.';
    }
    return \%valid if (keys %valid);
}

sub validateMemberShikaku
{
    my ($self,$line) = @_;
    my %valid = ();
    if ( $line->[1] !~ /^[0-9]{6}$/ ){
        $valid{$line->[1]} = 'is wrong pattern(6strings).';
    }
    if ( $line->[2] !~ /^[0-9]{2}$/ ){
        $valid{$line->[2]} = 'is wrong pattern(2strings).';
    }
    return \%valid if (keys %valid);
}

sub validateOnlineShikaku
{
    my ($self,$line) = @_;
    my %valid = ();
    if ( $line->[0] !~ /^[0-9]{7}$/ ){
        $valid{$line->[0]} = 'is wrong pattern(7strings).';
    }
    if ( $line->[2] !~ /^[0-9]{1,3}$/ ){
#        $valid{$line->[2]} = 'is {wrong pattern,too long}.';
    }
    if ( length($line->[2]) > 3 ){
        $valid{$line->[2]} = 'is too long.';
    }
    return \%valid if (keys %valid);
}

sub validateMemberPointHistory
{
    my ($self,$line) = @_;
    my %valid = ();
    # ポイント確定区分
    if ( $line->[10] !~ /^[0-9]$/ ){
        $valid{$line->[10]} = 'is wrong pattern(1strings).';
    }

    return \%valid if (keys %valid);
    return undef if ($line->[10] != 1);

    if ( $line->[1] !~ /^[0-9]{6}$/ ){
        $valid{$line->[1]} = 'is wrong pattern(6strings).';
    }
    if ( $line->[2] !~ /^[0-9]{8}$/ ){
        $valid{$line->[2]} = 'is wrong pattern(8strings).';
    }
    if ( $line->[3] !~ /^[0-9]{10}$/ ){
        $valid{$line->[3]} = 'is wrong pattern(10strings).';
    }
    if ( $line->[4] !~ /^-?[0-9]{1,10}$/ ){
        $valid{$line->[4]} = 'is wrong pattern.';
    }
    if ( $line->[5] !~ /^-?[0-9]{1,10}$/ ){
        $valid{$line->[5]} = 'is wrong pattern.';
    }
    if ( $line->[6] !~ /^[0-9]{2}$/ ){
        $valid{$line->[6]} = 'is wrong pattern(2strings).';
    }
    if ( $line->[7] !~ /^-?[0-9]{1,10}$/ ){
        $valid{$line->[7]} = 'is wrong pattern.';
    }
    if ( $line->[8] !~ /^-?[0-9]{1,10}$/ ){
        $valid{$line->[8]} = 'is wrong pattern.';
    }
    if ( $line->[9] !~ /^-?[0-9]{1,10}$/ ){
        $valid{$line->[9]} = 'is wrong pattern.';
    }
    # 伝票 NO が無い場合も対応
    if ( $line->[11] !~ /^([0-9]{8})?$/ ){
        $valid{$line->[11]} = 'is wrong pattern(8strings).';
    }
    if ( $line->[12] !~ /^[0-9]{8}$/ ){
        $valid{$line->[12]} = 'is wrong pattern(8strings).';
    }
    if ( $line->[13] !~ /^[0-9]{8}$/ ){
        $valid{$line->[13]} = 'is wrong pattern(8strings).';
    }
    return \%valid if (keys %valid);
}

sub validateOnlinePointHistory
{
    my ($self,$line) = @_;
    my %valid = ();
    if ( $line->[0] !~ /^[0-9]{7}$/ ){
        $valid{$line->[0]} = 'is wrong pattern(7strings).';
    }
    if ( $line->[9] !~ /^-?[0-9]{1,10}$/ ){
        $valid{$line->[9]} = 'is wrong pattern.';
    }
    if ( $line->[11] !~ /^[0-9]{8}$/ ){
        $valid{$line->[11]} = 'is wrong pattern(8strings).';
    }
    if ( $line->[12] !~ /^[0-9]{8}$/ ){
        $valid{$line->[12]} = 'is wrong pattern(8strings).';
    }
    if ( $line->[13] !~ /^[0-9]{8}$/ ){
        $valid{$line->[13]} = 'is wrong pattern(8strings).';
    }
    return \%valid if (keys %valid);
}

sub yyyyMMdd2TimePiece
{
	my ($self,$str) = @_;
	# デリミタなしだと strptime が使えない
	return Time::Piece->strptime(substr($str, 0, 4) . '-' . substr($str, 4, 2) . '-' . substr($str, 6, 2), '%Y-%m-%d');
}

1;
