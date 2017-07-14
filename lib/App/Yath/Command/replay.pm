package App::Yath::Command::replay;
use strict;
use warnings;

use Test2::Util qw/pkg_to_file/;

use Test2::Harness::Feeder::JSONL;
use Test2::Harness::Run;
use Test2::Harness;

use App::Yath::Util qw/fully_qualify/;

use parent 'App::Yath::Command';
use Test2::Harness::Util::HashBase qw{
    -help

    -log_file

    -verbose
    -formatter
    -renderer
    -show_job_info
    -show_run_info
    -show_job_launch
    -show_job_end
};

use Getopt::Long qw/GetOptionsFromArray/;

sub summary { "replay from a test log" }

sub usage {
    my $self = shift;
    my $name = $self->name;

    return <<"    EOT";
Usage: $0 $name [options] event_log.jsonl[.gz|.bz2]

  Simple Options:

    -h --help           Exit after showing this help message

  Rendering/Display Options:

    -v --verbose        Turn on verbosity, specify it multiple times to increase
                        verbosity

    -r '+Fully::Qualified::Renderer'
    --renderer 'Renderer::Postfix'

                        Specify an alternative renderer, this is what is
                        responsible for displaying events. If you do not prefix
                        with a '+' then 'Test2::Harness::Renderer::' will be
                        prefixed to your argument.
                        Default: '+Test2::Harness::Renderer::Formatter'

        Options specific to The 'Formatter' renderer:

          --show-job-end        Notify when a job ends (Default: On)
          --no-show-job-end

          --show-job-launch     Notify when a job starts
          --no-show-job-launch  (Default: on in verbose level 1+)

          --show-job-info       Print each jobs settings as JSON
          --no-show-job-info    (Default: Off, on when verbose > 1)

          --show-run-info       Print the run settings as JSON
          --no-show-run-info    (Default: Off, on when verbose > 1)

          --formatter '+Fully::Qualified::Formatter'
          --formatter 'Formatter::Postfix'

                                Specify which Test2 formatter to use
                                (Default: '+Test2::Formatter::Test2')


    EOT
}

sub init {
    my $self = shift;

    if ($self->args && @{$self->args}) {
        my (@args, $file);

        my $last_mark = '';
        for my $arg (@{$self->args}) {
            if ($last_mark eq '--') {
                die "Too many files specified.\n" if $file;
                $file = $arg;
            }
            else {
                if ($arg eq '--' || $arg eq '::') {
                    $last_mark = $arg;
                    next;
                }
                push @args => $arg;
            }
        }

        Getopt::Long::Configure("bundling");

        my $args_ok = GetOptionsFromArray \@args => (
            'r|renderer'       => \($self->{+RENDERER}),
            'v|verbose+'       => \($self->{+VERBOSE}),
            'h|help'           => \($self->{+HELP}),
            'formatter=s'      => \($self->{+FORMATTER}),
            'show-job-end!'    => \($self->{+SHOW_JOB_END}),
            'show-job-info!'   => \($self->{+SHOW_JOB_INFO}),
            'show-job-launch!' => \($self->{+SHOW_JOB_LAUNCH}),
            'show-run-info!'   => \($self->{+SHOW_RUN_INFO}),
        );
        die "Could not parse the command line options given.\n" unless $args_ok;

        ($file) = shift @args unless $file;

        die "No file specified.\n" if !$file;
        die "Too many files specified.\n" if $file && @args;

        $self->{+LOG_FILE} = $file;
    }

    # Defaults
    $self->{+FORMATTER} ||= '+Test2::Formatter::Test2';
    $self->{+RENDERER} ||= '+Test2::Harness::Renderer::Formatter';

    if ($self->{+VERBOSE}) {
        $self->{+SHOW_JOB_INFO}   = $self->{+VERBOSE} - 1 unless defined $self->{+SHOW_JOB_INFO};
        $self->{+SHOW_RUN_INFO}   = $self->{+VERBOSE} - 1 unless defined $self->{+SHOW_RUN_INFO};
        $self->{+SHOW_JOB_LAUNCH} = 1                     unless defined $self->{+SHOW_JOB_LAUNCH};
        $self->{+SHOW_JOB_END}    = 1                     unless defined $self->{+SHOW_JOB_END};
    }
    else {
        $self->{+VERBOSE} = 0; # Normalize
        $self->{+SHOW_JOB_INFO}   = 0 unless defined $self->{+SHOW_JOB_INFO};
        $self->{+SHOW_RUN_INFO}   = 0 unless defined $self->{+SHOW_RUN_INFO};
        $self->{+SHOW_JOB_LAUNCH} = 0 unless defined $self->{+SHOW_JOB_LAUNCH};
        $self->{+SHOW_JOB_END}    = 1 unless defined $self->{+SHOW_JOB_END};
    }
}

sub run {
    my $self = shift;

    if ($self->{+HELP}) {
        print $self->usage;
        exit 0;
    }

    my $feeder = Test2::Harness::Feeder::JSONL->new(file => $self->{+LOG_FILE});

    my $renderers = [];
    if (my $r = $self->{+RENDERER}) {
        if ($r eq '+Test2::Harness::Renderer::Formatter' || $r eq 'Formatter') {
            require Test2::Harness::Renderer::Formatter;

            my $formatter = $self->{+FORMATTER} or die "No formatter specified.\n";
            my $f_class;

            if ($formatter eq '+Test2::Formatter::Test2' || $formatter eq 'Test2') {
                require Test2::Formatter::Test2;
                $f_class = 'Test2::Formatter::Test2';
            }
            else {
                $f_class = fully_qualify('Test2::Formatter', $formatter);
                my $file = pkg_to_file($f_class);
                require $file;
            }

            push @$renderers => Test2::Harness::Renderer::Formatter->new(
                show_job_info   => $self->{+SHOW_JOB_INFO},
                show_run_info   => $self->{+SHOW_RUN_INFO},
                show_job_launch => $self->{+SHOW_JOB_LAUNCH},
                show_job_end    => $self->{+SHOW_JOB_END},
                formatter       => $f_class->new(verbose => $self->{+VERBOSE}),
            );
        }
        elsif ($self->{+FORMATTER}) {
            die "The formatter option is only available when the 'Formatter' renderer is in use.\n";
        }
        else {
            my $r_class = fully_qualify('Test2::Harness::Renderer', $r);
            require $r_class;
            push @$renderers => $r_class->new(verbose => $self->{+VERBOSE});
        }
    }

    use Carp::Always;
    my $harness = Test2::Harness->new(
        live      => 0,
        feeder    => $feeder,
        renderers => $renderers,
    );

    my $stat = $harness->run();

    my $exit = 0;
    my $bad = $stat->{fail};
    if (@$bad) {
        print "\nThe following test files failed:\n";
        print "  ", $_, "\n" for @$bad;
        print "\n";
        $exit += @$bad;
    }
    else {
        print "\nAll tests were successful!\n\n";
    }

    $exit = 255 if $exit > 255;

    return $exit;
}

1;
