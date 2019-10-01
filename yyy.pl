use strict;
use warnings;

use POSIX ":sys_wait_h";

pipe(my ($out_rh, $out_wh)) or die "Could not open pipe for stdout: $!";
pipe(my ($err_rh, $err_wh)) or die "Could not open pipe for stderr: $!";
my $pid = fork();
if ($pid) {    # Middle process
    close($out_wh);
    close($err_wh);

    $out_rh->blocking(0) or die "$!";
    $err_rh->blocking(0) or die "$!";

    my $exit;
    my $found;
    while (1) {
        $found = 0;

        if (defined(my $line = <$out_rh>)) {
            $found++;
            chomp($line);
            print "PROXY STDOUT: $line\n";
        }
        if (defined(my $line = <$err_rh>)) {
            $found++;
            chomp($line);
            print "PROXY STDERR: $line\n";
        }

        unless (defined($exit)) {
            my $out = waitpid($pid, WNOHANG);
            next unless $out;
            $exit = $?;
            next;
        }

        next if $found;

        last;
    }

    print "Parent: $$ | ALL DONE!\n";
    exit(0);
}

close($out_rh);
close($err_rh);

open(\*STDOUT, '>&', $out_wh) or die "Could not redirect STDOUT\n";
open(\*STDERR, '>&', $err_wh) or die "Could not redirect STDOUT\n";

print "CHILD: $$ | STARTING!\n";

for (1 .. 10) {
    print STDOUT "A LINE OF STDOUT!!!!!!!\n";
    print STDERR "A LINE OF STDERR!!!!!!!\n";
}

print STDOUT "NO NEWLINE";
print STDERR "NO NEWLINE";

exit(0);
