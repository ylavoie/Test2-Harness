use Test2::Bundle::Extended;
use Test2::Formatter::TAP;
use Test2::Tools::Subtest qw/subtest_buffered subtest_streamed/;

print STDOUT "STDOUT BEFORE TESTING\n";
print STDERR "STDERR BEFORE TESTING\n";

ok(1, "pass 1");
ok(0, "fail 1");
print STDOUT "STDOUT IN TESTING\n";
ok(0, "fail 2");
ok(1, "pass 2");

subtest_buffered foo => sub {
    ok(1, "pass 1");
    ok(1, "pass 2");

    subtest_buffered bar => sub {
        ok(1, "pass 1");
        ok(1, "pass 2");
    };
};

subtest_streamed foo => sub {
    ok(1, "pass 1");
    ok(1, "pass 2");

    subtest_streamed bar => sub {
        ok(1, "pass 1");
        ok(1, "pass 2");
    };
};

diag("a diag message 1");
print STDERR "STDERR IN TESTING\n";
diag("a diag message 2");

done_testing;

print STDOUT "STDOUT AFTER TESTING\n";
print STDERR "STDERR AFTER TESTING\n";

