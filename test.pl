# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test::More tests => 4;
#use diagnostics;

BEGIN { use_ok( 'Config::IniHash' ); }

my %orig_data = (
	sec1 => {
		foo => 5,
		bar => 'Hello World!'
	},
	seC2 => {
		what => 'sgfdfg=wtert',
		other => 'fsdgfg;dfhfdghfg',
	},
);

my $filename = "$ENV{TEMP}\\test_Config_IniHash_$$.INI";
ok( WriteINI( $filename, \%orig_data), "WriteINI => $filename");
END { unlink $filename }

my $read_data = ReadINI( $filename, {case => 'sensitive'});
ok( (defined($read_data) and ref($read_data)), "ReadINI <= $filename");

is_deeply( \%orig_data, $read_data, "Read data match the original");
