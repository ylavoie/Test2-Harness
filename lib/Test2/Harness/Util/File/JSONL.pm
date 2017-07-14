package Test2::Harness::Util::File::JSONL;
use strict;
use warnings;

use Carp qw/croak/;
use Test2::Harness::Util::JSON qw/encode_json decode_json/;

use parent 'Test2::Harness::Util::File::Stream';
use Test2::Harness::Util::HashBase;

sub decode { shift; decode_json($_[0]) }
sub encode { shift; encode_json(@_) . "\n" }

1;
