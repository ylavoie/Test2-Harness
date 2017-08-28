package Test2::Harness::Feeder::JSONL;
use strict;
use warnings;

our $VERSION = '0.001001';

use Carp qw/croak/;

use Test2::Harness::Event;
use Test2::Harness::Job;
use Test2::Harness::Run;
use Test2::Harness::Util::File::JSONL;

use Test2::Harness::Util qw/open_file/;

use IO::Uncompress::Bunzip2 qw($Bunzip2Error);
use IO::Uncompress::Gunzip qw($GunzipError) ;

BEGIN { require Test2::Harness::Feeder; our @ISA = ('Test2::Harness::Feeder') }

use Test2::Harness::Util::HashBase qw{ -file };

sub complete { 1 }

sub init {
    my $self = shift;

    $self->SUPER::init();

    my $file = delete $self->{+FILE} or croak "'file' is a required attribute";

    my $fh;
    if ($file =~ m/\.bz2$/) {
        $fh = IO::Uncompress::Bunzip2->new($file) or die "Could not open bz2 file '$file': $Bunzip2Error";
    }
    elsif ($file =~ m/\.gz/) {
        $fh = IO::Uncompress::Gunzip2->new($file) or die "Could not open gz file '$file': $GunzipError";
    }
    else {
        $fh = open_file($file, '<');
    }

    $self->{+FILE} = Test2::Harness::Util::File::JSONL->new(
        name => $file,
        fh   => $fh,
    );
}

sub poll {
    my $self = shift;
    my ($max) = @_;

    my @out;
    while (my $line = $self->{+FILE}->read_line) {
        bless($line->{facet_data}->{harness_run}, 'Test2::Harness::Run')
            if $line->{facet_data}->{harness_run};

        bless($line->{facet_data}->{harness_job}, 'Test2::Harness::Job')
            if $line->{facet_data}->{harness_job};

        push @out => Test2::Harness::Event->new(%$line);
        last if $max && @out >= $max
    }

    return @out;
}

1;
