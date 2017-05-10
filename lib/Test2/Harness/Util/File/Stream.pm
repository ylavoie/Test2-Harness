package Test2::Harness::Util::File::Stream;
use strict;
use warnings;

use Carp qw/croak/;

use parent 'Test2::Harness::Util::File';
use Test2::Harness::Util::HashBase qw{-line_cache -idx};

sub poll {
    my $self = shift;

    $self->{+IDX} = 0 unless defined $self->{+IDX};
    my $idx = $self->{+IDX};
    my $cache = $self->{+LINE_CACHE} ||= [];

    while (1) {
        my $line = $self->read_line;
        last unless defined $line;
    }

    return @{$cache}[$idx .. $#$cache];
}

sub read_line {
    my $self = shift;

    $self->{+IDX} = 0 unless defined $self->{+IDX};

    my $cache = $self->{+LINE_CACHE} ||= [];

    return $cache->[$self->{+IDX}++] if @$cache > $self->{+IDX};

    my $line = $self->SUPER::read_line(@_);

    if (defined $line) {
        push @$cache => $line;
        $self->{+IDX}++;
    }

    return $line;
}

sub maybe_read {
    my $self = shift;
    return unless -e $self->{+NAME};
    return $self->read;
}

sub read {
    my $self = shift;

    $self->{+IDX} = 0 unless defined $self->{+IDX};
    local $self->{+IDX} = $self->{+IDX};

    my $cache = $self->{+LINE_CACHE} ||= [];

    $self->poll;

    return @$cache;
}

sub reset {
    my $self = shift;

    $self->SUPER::reset();

    delete $self->{+LINE_CACHE};
    delete $self->{+IDX};
}

sub write {
    my $self = shift;

    my $fh = $self->open_file('>>');

    print $fh $self->encode($_) for @_;
    $fh->flush;

    return @_;
}

1;
