package Test2::Harness::Logger::JSONL;
use strict;
use warnings;

use IO::Handle;

use Test2::Harness::Util::JSON qw/encode_canon_json/;

BEGIN { require Test2::Harness::Logger; our @ISA = ('Test2::Harness::Logger') }
use Test2::Harness::Util::HashBase qw/-fh -prefix/;

sub init {
    my $self = shift;

    $self->{+PREFIX} = '' unless defined $self->{+PREFIX};

    unless($self->{+FH}) {
        open(my $fh, '>&', fileno(STDOUT)) or die "Could not clone STDOUT: $!";
        $fh->autoflush(1);
        $self->{+FH} = $fh;
    }
}

sub log_event {
    my $self = shift;
    my ($event) = @_;

    my $fh = $self->{+FH};
    my $prefix = $self->{+PREFIX};
    print $fh $prefix, encode_canon_json($event), "\n";
}

1;
