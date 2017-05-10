package Test2::Harness::Util::File::JSON;
use strict;
use warnings;

use Carp qw/croak/;
use Test2::Harness::Util::JSON qw/encode_json decode_json encode_pretty_json/;

use parent 'Test2::Harness::Util::File';
use Test2::Harness::Util::HashBase qw/pretty/;

sub decode { shift; decode_json(@_) }
sub encode { shift->pretty ? encode_pretty_json(@_) : encode_json(@_) }

sub reset { croak "line reading is disabled for json files" }
sub read_line  { croak "line reading is disabled for json files" }

1;
