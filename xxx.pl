use strict;
use warnings;

my $x = 1;

no warnings 'void';
print("A\n") => print("B\n") if 1;

__END__
package My::Preload;
# Adds the test2_harness_preload() method that returns the results of the DSL
# that is also added
use Test2::Harness::Preload;

stage default => sub {
    # List modules to load
    preload 'A Module';
    preload 'Module1', 'Module2';

    # A callback to run
    preload sub { ... };

    # Now load these after the callback
    preload 'more modules';

    # Specify pre-fork, post-fork, and pre-launch callbacks. Can be coderefs
    # and/or sub names. Can also specify args to pass in.
    run_pre_fork sub { my $job = shift; ... };
    run_pre_fork 'name_of_sub-in-this-package' => @args;
    run_post_fork sub  { my $job = shift; ... };
    run_pre_launch sub { my $job = shift; ... };

    # Now specify nested stages
    stage child_stage => sub {
        ...
    };
};

stage parallel_to_default => sub {
    ...
};



__END__
my $x = 'a';
for my $y (qw/a b c/) {
    my $x = "$x - $y";
    for my $z (qw/e f g/) {
        my $x = "$x - $z";
        print "$x\n";
    }
}

__END__
my $state = {foo => 1, bar => 2};

while (my ($k, $v) = each %$state) {
    $v++;
}

use Data::Dumper;
print Dumper($state);

__END__
sub do_it {
    my ($x, $y) = @_;

    print "X: $x, Y: $y\n";

    @_ = ($_[0] x 2, $y);

    return if length($_[0]) > 3;

    goto &do_it;
}

do_it('x', 'y');


__END__
use strict;
use warnings;

use Test2::Harness::IPC::Util qw/await_task return_task/;

my $go = sub {
    my $pid = fork;

    eval {
        if($pid) {
            print "$$ Parent is waiting\n";
            waitpid($pid, 0);
        }
        else {
            print "$$ Child is starting\n";
            eval { return_task("foo"); 1 } or die $@;
        }

        1;
    } or die $@;
};

my $task = &await_task($go);

print "$$: " . ($task ? "'$task'" : 'undef') . "\n";

__END__
use strict;
use warnings;

use Time::HiRes qw/sleep/;
use Scalar::Util qw/openhandle/;

use Test2::Harness::Process;

if (@ARGV) {
    if ($ARGV[0] == 1) {
        print "FIRST CHILD: $$ | STARTING!\n";
        pipe(my ($out_rh, $out_wh)) or die "Could not open pipe for stdout: $!";
        pipe(my ($err_rh, $err_wh)) or die "Could not open pipe for stderr: $!";
        my $process = Test2::Harness::Process->new(
            command => [$^X, '-Ilib', __FILE__, 2],
            stdout => $out_wh,
            stderr => $err_wh,
        );
        $process->start;
        close($out_wh);
        close($err_wh);

        my $found;
        while (1) {
            $found = 0;
            while (my $line = <$out_rh>) {
                $found++;
                print "PROXY STDOUT: $line";
            }
            while (my $line = <$err_rh>) {
                $found++;
                print "PROXY STDERR: $line";
            }

            next if $process->is_running;
            next if $found;
            last;
        }

        $process->wait;
        print "NESTED CHILD EXIT: " . $process->exit . "\n";
        print "FIRST CHILD: $$ | ALL DONE!\n";
    }
    else {
        print "NESTED CHILD: $$ | STARTING!\n";

        for (1 .. 10) {
            for (1 .. 100) {
                print STDOUT ("A LINE OF STDOUT!!!!!!!" x 100) . "\n";
                print STDERR ("A LINE OF STDOUT!!!!!!!" x 100) . "\n";
            }
            sleep 0.1;
        }

        print "NESTED CHILD: $$ | ALL DONE!\n";
    }
}
else {
    my $process = Test2::Harness::Process->new(command => [$^X, '-Ilib', __FILE__, 1]);
    $process->start;
    $process->wait;
    print "FIRST CHILD EXIT: " . $process->exit . "\n";
    print "PARENT: $$ | ALL DONE!\n";
}
