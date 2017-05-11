package Test2::Harness::Run::Job;
use strict;
use warnings;

use File::Spec;
use Test2::Harness::Event;
use Test2::Harness::TestFile;
use Test2::Harness::Util::File;
use Test2::Harness::Util::File::JSON;
use Test2::Harness::Util::File::JSONL;
use Test2::Harness::Util::File::Stream;
use Test2::Harness::Util::File::Value;

use Carp qw/croak confess/;
use Time::HiRes qw/time/;

use Test2::Harness::Util::HashBase qw{
    -dir -data -id -test_file -env_vars -_proc -test
};

sub init {
    my $self = shift;

    my $file;
    if (my $path = delete $self->{path}) {
        if (-f $path) {
            $file = $path;
        }
        elsif (-d $path) {
            $self->{+DIR} = $path;
        }
        else {
            croak "'$path' is not a valid file or directory";
        }
    }

    $file ||= delete $self->{file};

    if ($file) {
        my $run_file = Test2::Harness::Util::File::JSON->new(name => File::Spec->catfile($file));
        $self->{+DATA} = $run_file->read;
    }

    croak "One of 'dir', 'data', 'file' or 'path' is required"
        unless $self->{+DIR} || $self->{+DATA};

    if ($self->{+DATA}) {
        $self->{+ID}        ||= $self->{+DATA}->{id};
        $self->{+TEST_FILE} ||= $self->{+DATA}->{test_file};
        $self->{+ENV_VARS}  ||= $self->{+DATA}->{env_vars};
    }

    croak "The 'id' attribute is required"
        unless $self->{+ID};

    croak "One of 'test_file' or 'test' must be specified"
        unless $self->{+TEST_FILE} || $self->{+TEST};

    $self->{+TEST_FILE} ||= $self->{+TEST}->filename;
    $self->{+TEST}      ||= Test2::Harness::TestFile->new(filename => $self->{+TEST_FILE});

    $self->{+ENV_VARS} ||= {};
}

sub complete {
    my $self = shift;

    return 1 if $self->{+DATA};
    return 1 if $self->stop_stamp;
    return 1 if defined $self->exit;

    my $proc = $self->{+_PROC} or return undef;

    return 0 unless $proc->complete;

    $self->set_stop_stamp(time);
    $self->set_exit($proc->exit);

    return 1;
}

sub path {
    my $self = shift;
    confess "'path' only works when using a directory" unless $self->{+DIR};
    return $self->{+DIR} unless @_;
    return File::Spec->catfile($self->{+DIR}, @_);
}

sub events_file {
    my $self = shift;
    $self->{events_File} ||= Test2::Harness::Util::File::JSONL->new(name => $self->path('events.jsonl'));
}

sub events {
    my $self = shift;

    # Do not cache from file
    return map { Test2::Harness::Event->new(facet_data => $_) } $self->events_file->maybe_read
        unless $self->{+DATA};

    # Ok to cache from data
    return @{$self->{events} ||= [map { Test2::Harness::Event->new(facet_data => $_) } @{$self->{+DATA}->{events} || []}]}
        if $self->{+DATA};
}

sub poll_events {
    my $self = shift;

    # Delegate to the file
    return map { Test2::Harness::Event->new(facet_data => $_) } $self->events_file->poll
        unless $self->{+DATA};

    # Return everything the first time, nothing after that
    return if $self->{poll_events}++;
    return $self->events;
}

my %ATTRS = (
    stdout      => {file => 'stdout',      type => 'Test2::Harness::Util::File::Stream'},
    stderr      => {file => 'stderr',      type => 'Test2::Harness::Util::File::Stream'},
    muxed       => {file => 'muxed',       type => 'Test2::Harness::Util::File::JSONL'},
    pid         => {file => 'pid',         type => 'Test2::Harness::Util::File::Value'},
    start_stamp => {file => 'start_stamp', type => 'Test2::Harness::Util::File::Value'},
    stop_stamp  => {file => 'stop_stamp',  type => 'Test2::Harness::Util::File::Value'},
    exit        => {file => 'exit',        type => 'Test2::Harness::Util::File::Value'},
);

sub TO_JSON {
    my $self = shift;

    return {
        id        => $self->{+ID},
        test_file => $self->{+TEST_FILE},
        env_vars  => $self->{+ENV_VARS},
        events => [map { $_->facet_data } $self->events],
        map {( $_ => $ATTRS{$_}->{type}->isa('Test2::Harness::Util::File::Stream') ? [$self->$_] : $self->$_ )} keys %ATTRS,
    };
}

{
    my %SUBS;

    for my $attr (keys %ATTRS) {
        my $spec = $ATTRS{$attr};
        my $file = $spec->{file};
        my $type = $spec->{type};

        my $file_attr = "${attr}_file";

        $SUBS{$file_attr} = sub {
            my $self = shift;
            $self->{$file_attr} ||= $type->new(name => $self->path($file));
        };

        # This includes JSONL, which is a subclass of Stream
        if ($type->isa('Test2::Harness::Util::File::Stream')) {
            $SUBS{$attr} = sub {
                my $self = shift;

                if ($self->{+DATA}) {
                    return @{$self->{$attr}} if defined $self->{$attr};
                    return @{$self->{$attr} = $self->{+DATA}->{$attr} || []};
                }

                # Do not cache it
                return $self->$file_attr->maybe_read;
            };

            $SUBS{"poll_$attr"} = sub {
                my $self = shift;

                # Delegate to the file
                return $self->$file_attr->poll unless $self->{+DATA};

                # Return everything the first time, nothing after that
                return if $self->{"poll_$attr"}++;
                return $self->$attr;
            };
        }
        else {
            $SUBS{"set_$attr"} = sub {
                my $self = shift;
                my ($val) = @_;
                croak "Job is read only" if $self->{+DATA};

                $self->$file_attr->write($val);
                $self->{$attr} = $val;
            };

            $SUBS{$attr} = sub {
                my $self = shift;

                #cache it
                return $self->{$attr} if defined $self->{$attr};

                return $self->{$attr} = $self->{+DATA}->{$attr}
                    if $self->{+DATA};

                return $self->{$attr} = $self->$file_attr->maybe_read;
            };
        }
    }

    no strict 'refs';
    *{__PACKAGE__ . '::' . $_} = $SUBS{$_} for keys %SUBS;
}

sub proc { $_[0]->{+_PROC} }

sub set_proc {
    my $self = shift;
    my ($proc) = @_;

    $self->{+_PROC} = $proc;
    $self->set_pid($proc->pid);

    return $proc;
}

1;
