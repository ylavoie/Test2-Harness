package App::Yath::Plugin::TCM;
use strict;
use warnings;

use parent 'App::Yath::Plugin';

# TODO:
# * subclass TestFile so that queue_item sets 'via' to a TCM based runner
# * subclass Open3 so that it injects the tcm script just before the file in the command
# * subclass Fork so that it wraps the returned file in the sub
# * implement find_files to use all this

sub options {
    my $class = shift;
    my ($cmd, $settings) = @_;

    return (
        {
            spec => 'tcm=s@',
            field => 'tcm',
            used_by => {runner => 1, jobs => 1},
            section => 'Harness Options',
            usage   => ['--tcm path/to/tests'],
            summary => ["Run TCM tests from the path", "Can be specified multiple times"],
            long_desc => "This will tell Test2::Harness to handle TCM tests. Any test file matching /tcm.t\$/ will be excluded automatically in favor of handling the tests internally. Note that tcm tests inside your search path will normally be found automatically and run",
        },

        {
            spec => 'no-tcm',
            field => 'no_tcm',
            used_by => {runner => 1, jobs => 1},
            section => 'Harness Options',
            usage   => ['--no-tcm'],
            summary => ["Disable all automatic handling of tcm. --tcm will still work"],
        },
    );
}

1;


    my $has_tcm    = $settings->{tcm}    && @{$settings->{tcm}};
    unless ($has_tcm || $settings->{no_tcm}) {
        my @dirs = grep { -d $_ } @{$settings->{search} || []};

        my $tcm = $settings->{tcm} = [];
        require File::Find;
        File::Find::find(
            sub {
                return unless -d $_;
                return unless $File::Find::name =~ m{TestsFor$};
                push @$tcm => $File::Find::name;
            },
            @dirs
        ) if @dirs;

        if (@$tcm) {
            push @{$settings->{exclude_patterns}} => "(tcm|TCM)\\.t\$";

            my $libs = $settings->{libs} ||= [];
            push @$libs => File::Spec->rel2abs(File::Spec->catdir($_, File::Spec->updir)) for @$tcm;
        }
    }

    my $tcm = $self->tcm;

    if ($tcm && @$tcm) {
        @dirs = ();

        for my $item (@$tcm) {
            push @files => Test2::Harness::Util::TestFile->new(file => $item, tcm => 1) and next if -f $item;
            push @dirs  => $item and next if -d $item;
            die "'$item' does not appear to be either a file or a directory.\n";
        }

        if (@dirs) {
            require File::Find;
            File::Find::find(
                {
                    no_chdir => 1,
                    wanted   => sub {
                        no warnings 'once';
                        return unless -f $_ && m/\.pm$/;
                        push @files => Test2::Harness::Util::TestFile->new(
                            file => $File::Find::name,
                            tcm  => 1,
                        );
                    },
                },
                @dirs,
            );
        }
    }

    if ($job->tcm) {
        my $sub = sub {
            require Test2::Require::Module;
            Test2::Require::Module->import('Test::Class::Moose::Runner');
            require $file;
            require Test::Class::Moose::Runner;
            Test::Class::Moose::Runner->import();
            Test::Class::Moose::Runner->new->runtests();
        };

        return (undef, $sub);
    }


sub find_tcm_script {
    my $self = shift;

    my $script = $ENV{T2_HARNESS_TCM_SCRIPT} || 'yath-tcm';
    return $script if -f $script;

    if ($0 && $0 =~ m{(.*)\byath(-.*)?$}) {
        return "$1$script" if -f "$1$script";
    }

    # Do we have the full path?
    # Load IPC::Cmd only if needed, it indirectly loads version.pm which really
    # screws things up...
    require IPC::Cmd;
    if(my $out = IPC::Cmd::can_run($script)) {
        return $out;
    }

    die "Could not find '$script' in execution path";
}


# Open3
        $job->tcm ? ($class->find_tcm_script) : (),
