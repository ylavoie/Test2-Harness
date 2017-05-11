package Test2::Harness::Run;
use strict;
use warnings;

use File::Find();
use File::Spec();
use Test2::Harness::TestFile;
use Test2::Harness::Run::Job;
use Test2::Harness::Util::File::JSON;
use Test2::Harness::Util::File::JSONL;

use Test2::Util qw/IS_WIN32/;

use Carp qw/croak confess/;
use Scalar::Util qw/blessed/;

use Test2::Harness::Util::HashBase qw{
    -id
    -dir -data
    -_jobs -_jobs_file

    -job_count
    -switches
    -libs -lib -blib
    -preload

    -output_merging -output_events -output_muxing
    -event_stream

    -chdir
    -search
    -unsafe_inc

    -env_vars
};

my @CONFIG_KEYS = (
    ID(),
    JOB_COUNT(),
    SWITCHES(),
    LIBS(), LIB(), BLIB(),
    PRELOAD(),
    OUTPUT_MERGING(), OUTPUT_EVENTS(), OUTPUT_MUXING(),
    EVENT_STREAM(),
    CHDIR(),
    SEARCH(),
    UNSAFE_INC(),
    ENV_VARS()
);

sub TO_JSON {
    my $self = shift;

    return {
        %{$self->config_data},

        jobs => [map { $_->TO_JSON } @{$self->jobs}],
        system_env_vars => {%ENV},
    };
}

sub config_data {
    my $self = shift;
    my %out = map { ($_ => $self->{$_}) } @CONFIG_KEYS;
    return \%out;
}

sub save {
    my $self = shift;
    my ($file, %params) = @_;
    my $run = Test2::Harness::Util::File::JSON->new(name => $file, %params);
    $run->write($self->TO_JSON);
}

sub save_config {
    my $self = shift;
    my $run = Test2::Harness::Util::File::JSON->new(name => $self->path('config.json'));
    $run->write($self->config_data);
}

sub load_config {
    my $self = shift;

    my $fh = Test2::Harness::Util::File::JSON->new(name => $self->path('config.json'));
    my $data = $fh->read;
    $self->{$_} = $data->{$_} for @CONFIG_KEYS;
}

sub init {
    my $self = shift;

    # Put this here, before loading data, loaded data means a replay without
    # actually running tests, this way we only die if we are starting a new run
    # on windows.
    croak "preload is not supported on windows"
        if IS_WIN32 && $self->{+PRELOAD};

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
        my $run_file = Test2::Harness::Util::File::JSON->new(name => $file);
        $self->{+DATA} = $run_file->read;
    }

    $self->{+ID} ||= $self->{+DATA}->{id}
        if $self->{+DATA};

    croak "One of 'dir', 'data', 'file' or 'path' is required"
        unless $self->{+DIR} || $self->{+DATA};

    $self->load_config if delete $self->{load_config};

    croak "The 'id' attribute is required"
        unless $self->{+ID};

    $self->{+CHDIR}          ||= undef;
    $self->{+SEARCH}         ||= ['t'];
    $self->{+PRELOAD}        ||= undef;
    $self->{+SWITCHES}       ||= [];
    $self->{+LIBS}           ||= [];
    $self->{+LIB}            ||= 0;
    $self->{+BLIB}           ||= 0;
    $self->{+OUTPUT_MERGING} ||= 0;
    $self->{+OUTPUT_EVENTS}  ||= 0;
    $self->{+OUTPUT_MUXING}  ||= 0;
    $self->{+JOB_COUNT}      ||= 1;

    $self->{+EVENT_STREAM} = 1 unless defined $self->{+EVENT_STREAM};

    unless(defined $self->{+UNSAFE_INC}) {
        if (defined $ENV{PERL_USE_UNSAFE_INC}) {
            $self->{+UNSAFE_INC} = $ENV{PERL_USE_UNSAFE_INC};
        }
        else {
            $self->{+UNSAFE_INC} = 1;
        }
    }

    my $env = $self->{+ENV_VARS} ||= {};
    $env->{PERL_USE_UNSAFE_INC} = $self->{+UNSAFE_INC} unless defined $env->{PERL_USE_UNSAFE_INC};

    $env->{T2_HARNESS_RUN_DIR} = $self->{+DIR} if $self->{+DIR};
    $env->{T2_HARNESS_RUN_ID}  = $self->{+ID};
    $env->{T2_HARNESS_JOBS}    = $self->{+JOB_COUNT};
    $env->{HARNESS_JOBS}       = $self->{+JOB_COUNT};
}

sub all_libs {
    my $self = shift;

    my @libs;

    push @libs => 'lib' if $self->{+LIB};
    push @libs => 'blib/lib', 'blib/arch' if $self->{+BLIB};
    push @libs => @{$self->{+LIBS}} if $self->{+LIBS};

    return @libs;
}

sub path {
    my $self = shift;
    confess "'path' only works when using a directory" unless $self->{+DIR};
    return $self->{+DIR} unless @_;
    return File::Spec->catfile($self->{+DIR}, @_);
}

sub jobs_file {
    my $self = shift;
    $self->{+_JOBS_FILE} ||= Test2::Harness::Util::File::JSONL->new(name => $self->path('jobs.jsonl'));
}

sub jobs {
    my $self = shift;

    return $self->{+_JOBS} ||= [map { Test2::Harness::Run::Job->new(data => $_) } @{$self->{+DATA}->{jobs}}]
        if $self->{+DATA};

    my $jobs = $self->{+_JOBS} ||= [];
    my $file = $self->jobs_file;

    while (my $job_data = $file->read_line) {
        my $id      = $job_data->{id};
        my $job_dir = $self->path($id);
        push @$jobs => Test2::Harness::Run::Job->new(
            %$job_data,
            dir => $job_dir,
        );
    }

    return $jobs;
}

sub add_job {
    my $self = shift;
    my ($job) = @_;

    croak "'add_jobs' only works when using a directory"
        unless $self->{+DIR};

    $self->jobs_file->write({id => $job->id, test_file => $job->test_file});

    return $job;
}

sub find_tests {
    my $self  = shift;
    my $tests = $self->{+SEARCH};

    my (@files, @dirs);

    for my $item (@$tests) {
        push @files => Test2::Harness::TestFile->new(filename => $item) and next if -f $item;
        push @dirs  => $item and next if -d $item;
        die "'$item' does not appear to be either a file or a directory.\n";
    }

    my $curdir = File::Spec->curdir();
    CORE::chdir($self->{+CHDIR}) if $self->{+CHDIR};

    my $ok = eval {
        File::Find::find(
            sub {
                no warnings 'once';
                return unless -f $_ && m/\.t2?$/;
                push @files => Test2::Harness::TestFile->new(filename => $File::Find::name);
            },
            @dirs
        );
        1;
    };
    my $error = $@;

    CORE::chdir($curdir);

    die $error unless $ok;

    return sort { $a->filename cmp $b->filename } @files;
}

sub perl_command {
    my $self   = shift;
    my %params = @_;

    my @cmd = ($^X);

    my @libs;
    if ($params{include_harness_lib} || $self->{+OUTPUT_MUXING} || $self->{+OUTPUT_EVENTS}) {
        my $path = $INC{"Test2/Harness.pm"};
        $path =~ s{Test2/Harness\.pm$}{};
        $path = File::Spec->rel2abs($path);
        push @libs => $path;
    }

    push @libs => $self->all_libs;
    push @libs => @{$params{libs}}  if $params{libs};

    push @cmd => @{$self->{+SWITCHES}} if $self->{+SWITCHES};
    push @cmd => @{$params{switches}}  if $params{switches};

    push @cmd => map { "-I$_" } @libs;

    return @cmd;
}

1;
