package Test2::Harness::Util::JSON;
use strict;
use warnings;

BEGIN {
    local $@ = undef;
    my $ok = eval {
        require JSON::MaybeXS;
        JSON::MaybeXS->import('JSON');
        1;
    };

    unless($ok) {
        require JSON::PP;
        *JSON = sub() { 'JSON::PP' };
    }
}

our @EXPORT = qw{JSON encode_json decode_json encode_pretty_json};
BEGIN { require Exporter; our @ISA = qw(Exporter) }

my $json = JSON->new->utf8(1);
my $pretty = JSON->new->utf8(1)->pretty(1)->canonical(1);

sub encode_json { $json->encode(@_) }
sub encode_pretty_json { $pretty->encode(@_) }

sub decode_json {
    my ($input) = @_;
    my $data;
    my $ok = eval { $data = $json->decode($input); 1 };
    my $error = $@;
    return $data if $ok;
    die "JSON decode error: $error$input\n";
}

1;
