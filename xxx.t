#!/usr/bin/env perl

package TestExample {
    use Test::Class::Moose;
    {
        no warnings 'redefine';
        *Test2::Formatter::TAP::hide_buffered = sub { 0 };
    }

    sub test_method {
        ok 'first';
        ok 'second';
        sleep 10;
        ok 'third';
    }
}

use Test::Class::Moose::Runner;
Test::Class::Moose::Runner->new->runtests;
