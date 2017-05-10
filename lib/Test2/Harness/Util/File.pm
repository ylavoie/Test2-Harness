package Test2::Harness::Util::File;
use strict;
use warnings;

use IO::Handle;

use Test2::Harness::Util();

use Carp qw/croak/;

use Test2::Harness::Util::HashBase qw{ -name -_fh -_buffer done };

sub exists { -e $_[0]->{+NAME} }

sub decode { shift; $_[0] }
sub encode { shift; $_[0] }

sub init {
    my $self = shift;

    croak "'name' is a required attribute" unless $self->{+NAME};

    if (my $fh = delete $self->{fh}) {
        $fh->blocking(0);
        $self->{+_FH} = $fh;
    }

    $self->{+_BUFFER} = '';
}

sub open_file {
    my $self = shift;
    return Test2::Harness::Util::open_file($self->{+NAME}, @_)
}

sub maybe_read {
    my $self = shift;
    return undef unless -e $self->{+NAME};
    return $self->read;
}

sub read {
    my $self = shift;
    my $out = Test2::Harness::Util::read_file($self->{+NAME});
    return $self->decode($out);
}

sub write {
    my $self = shift;
    return Test2::Harness::Util::write_file_atomic($self->{+NAME}, $self->encode(@_));
}

sub reset {
    my $self = shift;
    delete $self->{+_FH};
    delete $self->{+DONE};
    $self->{+_BUFFER} = '';
    return;
}

sub fh {
    my $self = shift;
    return $self->{+_FH} if $self->{+_FH};

    $self->{+_FH} = Test2::Harness::Util::maybe_open_file($self->{+NAME}) or return undef;
    $self->{+_FH}->blocking(0);
    return $self->{+_FH};
}

# When reading from a file that is still growing we have to reset EOF
# frequently, and also may get a partial line if we read halway thorugh a line
# being written, so we need to add our own buffering.
sub read_line {
    my $self = shift;

    my $fh = $self->fh or return undef;

    $self->{+_BUFFER} = '' unless defined $self->{+_BUFFER};

    my $line;
    until ($line) {
        seek($fh,0,1); # Clear EOF
        my $got = <$fh>;

        $self->{+_BUFFER} .= $got if defined $got;

        # If the line does not end in a newline we will return for now and try
        # to read the rest of the line later. However if 'done' is set we want
        # to skip this check and return the data anyway as a newline will never
        # come.
        return undef unless ($self->{+DONE} && length $self->{+_BUFFER}) || substr($self->{+_BUFFER}, -1, 1) eq "\n";

        $line = $self->{+_BUFFER};
        $self->{+_BUFFER} = '';
        last;
    }

    return $self->decode($line);
}

1;
