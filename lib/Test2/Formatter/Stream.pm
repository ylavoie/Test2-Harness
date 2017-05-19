package Test2::Formatter::Stream;
use strict;
use warnings;

use Time::HiRes qw/time/;

use Test2::Harness::Util qw/open_file/;
use Test2::Harness::Util::JSON qw/JSON/;

use base qw/Test2::Formatter/;
use Test2::Util::HashBase qw/filename io _encoding/;

sub no_header      { 0 }
sub no_numbers     { 0 }
sub set_no_header  { 0 }
sub set_no_numbers { 0 }

{
    my $J = JSON->new;
    $J->indent(0);
    $J->convert_blessed(1);
    $J->allow_blessed(1);
    $J->utf8(1);

    sub ENCODER() { $J }
}

my $DEFAULT_FILE;
sub import {
    my $class = shift;

    $class->SUPER::import();

    return unless @_;

    die "$class already imported with an argument"
        if $DEFAULT_FILE && $DEFAULT_FILE ne $_[0];

    $DEFAULT_FILE = shift;
}

sub hide_buffered { 0 }

sub init {
    my $self = shift;

    $self->{+FILENAME} ||= $DEFAULT_FILE or die "No file specified";
    $self->{+IO} ||= open_file($self->{+FILENAME}, '>>');

    $self->{+IO}->autoflush(1);
}

sub record {
    my $self = shift;
    Carp::confess($self) unless ref($self);

    my $io = $self->{+IO};

    no warnings 'once';
    local *UNIVERSAL::TO_JSON = sub { "$_[0]" };

    for my $item (@_) {
        my $json = ENCODER->encode($item);
        print $io "$json\n";
    }

    $io->flush;
}

sub encoding {
    my $self = shift;

    if (@_) {
        my ($enc) = @_;
        $self->record({control => {encoding => $enc}});
        $self->set_encoding($enc);
    }

    return $self->{+_ENCODING};
}

sub set_encoding {
    my $self = shift;

    if (@_) {
        my ($enc) = @_;

        # https://rt.perl.org/Public/Bug/Display.html?id=31923
        # If utf8 is requested we use ':utf8' instead of ':encoding(utf8)' in
        # order to avoid the thread segfault.
        if ($enc =~ m/^utf-?8$/i) {
            binmode($self->{+IO}, ":utf8");
        }
        else {
            binmode($self->{+IO}, ":encoding($enc)");
        }
        $self->{+_ENCODING} = $enc;
    }

    return $self->{+_ENCODING};
}

if ($^C) {
    no warnings 'redefine';
    *write = sub {};
}
sub write {
    my ($self, $e, $num, $f) = @_;
    $f ||= $e->facet_data;

    $self->set_encoding($f->{control}->{encoding}) if $f->{control}->{encoding};

    $self->record(
        {
            facets       => $f,
            assert_count => $num,
            stamp        => time,
        }
    );
}

sub DESTROY {
    my $self = shift;
    my $IO = $self->{+IO} or return;
    eval { $IO->flush };
}

1;
