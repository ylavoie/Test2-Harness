package Test2::Harness::Util::File::Stream;
use strict;
use warnings;

use Carp qw/croak/;
use Fcntl qw/LOCK_EX LOCK_UN/;

use parent 'Test2::Harness::Util::File';
use Test2::Harness::Util::HashBase qw/use_write_lock/;

sub poll_with_index {
    my $self = shift;
    my %params = @_;

    my $max = delete $params{max} || 0;

    my $pos = $params{from};
    $pos = $self->{+LINE_POS} ||= 0 unless defined $pos;

    my @out;
    while (!$max || @out < $max) {
        my ($spos, $epos, $line) = $self->read_line(%params, from => $pos);
        last unless defined $line;

        $self->{+LINE_POS} = $epos unless $params{peek} || defined $params{from};
        push @out => [$spos, $epos, $line];
        $pos = $epos;
    }

    return @out;
}

sub read {
    my $self = shift;

    return $self->poll(from => 0);
}

sub poll {
    my $self = shift;
    my @lines = $self->poll_with_index(@_);
    return map { $_->[-1] } @lines;
}

sub write {
    my $self = shift;

    my $name = $self->{+NAME};

    my $fh = $self->open_file('>>');

    flock($fh, LOCK_EX) or die "Could not lock file '$name': $!"
        if $self->{+USE_WRITE_LOCK};

    print $fh $self->encode($_) for @_;
    $fh->flush;

    flock($fh, LOCK_UN) or die "Could not unlock file '$name': $!"
        if $self->{+USE_WRITE_LOCK};

    close($fh) or die "Could not clone file '$name': $!";

    return @_;
}

1;
