requires "Carp" => "0";
requires "Config" => "0";
requires "Data::Dumper" => "0";
requires "Exporter" => "0";
requires "Fcntl" => "0";
requires "File::Find" => "0";
requires "File::Spec" => "0";
requires "File::Temp" => "0";
requires "Getopt::Long" => "2.36";
requires "IO::Compress::Bzip2" => "0";
requires "IO::Compress::Gzip" => "0";
requires "IO::Handle" => "1.27";
requires "IO::Uncompress::Bunzip2" => "0";
requires "IO::Uncompress::Gunzip" => "0";
requires "IPC::Cmd" => "0";
requires "IPC::Open3" => "0";
requires "Importer" => "0.024";
requires "JSON::PP" => "0";
requires "List::Util" => "0";
requires "POSIX" => "0";
requires "Scalar::Util" => "0";
requires "Symbol" => "0";
requires "Test2" => "1.302095";
requires "Test2::V0" => "0.000074";
requires "Time::HiRes" => "0";
requires "base" => "0";
requires "parent" => "0";
requires "perl" => "5.008001";
suggests "Cpanel::JSON::XS" => "0";
suggests "JSON::MaybeXS" => "0";
suggests "Term::ANSIColor" => "0";

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Test::Pod" => "1.41";
  requires "Test::Spelling" => "0.12";
};