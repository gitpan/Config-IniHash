# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test::More tests => 208;
#use diagnostics;
use strict;
use File::Spec;

BEGIN { use_ok( 'Config::IniHash' ); }

use Config::IniHash qw(ReadINI WriteINI AddDefaults);

my %orig_data = (
	sec1 => {
		foo => 5,
		BAR => 'Hello World!'
	},
	seC2 => {
		What => 'sgfdfg=wtert',
		other => 'fsdgfg;dfhfdghfg',
	},
);

if (!exists $ENV{TEMP} or !-d $ENV{TEMP}) {
	$ENV{TEMP} = File::Spec->tmpdir;
}

my $script_file = $0;
if (! File::Spec->file_name_is_absolute($script_file)) {
	$script_file = File::Spec->rel2abs($script_file);
}

{
	(my $filename = $script_file) =~ s/\.pl$/-write.ini/;
	ok( WriteINI( $filename, \%orig_data), "WriteINI => $filename");
	END { unlink $filename }

	{
		my $read_data = ReadINI( $filename, {case => 'sensitive'});
		ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename'");

		is_deeply( \%orig_data, $read_data, "Read data match the original");
	}

	{
		my $read_data = ReadINI( $filename);
		ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename'");

		my $read_data2 = ReadINI( $filename, {case => 'lower'});
		ok( (defined($read_data2) and ref($read_data2)), "ReadINI '$filename', {case => 'lower'}");

		is_deeply( $read_data, $read_data2, "case => 'lower' is the default");
	}
}

(my $filename = $script_file) =~ s/\.pl$/.ini/;

{
	my $read_data = ReadINI( $filename);
	ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename' (different data)");

	is( $read_data->{Two}{temp}, $ENV{temp}, "System variables are interpolated by default");
}

{
	my $read_data = ReadINI( $filename, {systemvars => 0});
	ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename', {systemvars => 0}");

	is( $read_data->{Two}{temp}, '%TEMP%', "System variables are not interpolated if not wanted");
}

{
	my $read_data = ReadINI( $filename, {systemvars => 1});
	ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename', {systemvars => 1}");

	is( $read_data->{Two}{temp}, $ENV{temp}, "System variables are interpolated if asked to");
}

{
	my $read_data = ReadINI( $filename, {systemvars => {TEMP => 'subverted'}});
	ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename', {systemvars => {...}}");

	is( $read_data->{Two}{TEMP}, 'subverted', "System variables are interpolated using a custom hash");
}


{
	my $read_data = ReadINI( $filename, {allowmultiple => 0});
	ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename', {allowmultiple => 0}");

	is( $read_data->{Four}{foo}, 3, "Multiple values overwrite each other");
}
{
	my $read_data = ReadINI( $filename, {allowmultiple => 1});
	ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename', {allowmultiple => 1}");

	is_deeply( $read_data->{Four}{foo}, [1,2,3], "Multiple values produce an array");
	is_deeply( $read_data->{Four}{bar}, 'U Trech Sudu', "But single values still produce a scalar");
}
{
	my $read_data = ReadINI( $filename, {allowmultiple => {Four => 'foo,bar'}});
	ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename', {allowmultiple => {Four => 'foo,bar'}}");

	is_deeply( $read_data->{Four}{foo}, [1,2,3], "Specified multiple values produce an array");
	is_deeply( $read_data->{Four}{bar}, ['U Trech Sudu'], "Single values as well if specified");
	is_deeply( $read_data->{Two}{foo}, 'dva', "Multiple values that are not specified produce scalars");

	my $read_data2 = ReadINI( $filename, {allowmultiple => {Four => [qw(foo bar)]}});
	ok( (defined($read_data2) and ref($read_data2)), "ReadINI '$filename', {allowmultiple => {Four => [qw(foo bar)]}}");

	is_deeply( $read_data, $read_data2, "Comma separated lists and arrayrefs both work");
}


{
	my $read_data = ReadINI( $filename, {allowmultiple => {'*' => 'foo,bar'}});
	ok( (defined($read_data) and ref($read_data)), "ReadINI '$filename', {allowmultiple => {'*' => 'foo,bar'}}");

	is_deeply( $read_data->{Four}{foo}, [1,2,3], "Specified multiple values produce an array");
	is_deeply( $read_data->{Two}{foo}, ['jedna','dva'], "Specified multiple values produce an array in all sections");
}

{
	my $read_data = ReadINI( $filename, {});

	is( $read_data->{Five}{'#com1'}, undef, "# is a comment char by default");
	is( $read_data->{Five}{';com2'}, undef, "; is a comment char by default");
	is( $read_data->{Five}{'\'com3'}, 'hu', "' is NOT a comment char by default");
	is( $read_data->{Five}{'//com4'}, 'hy', "// is NOT a comment char by default");
}

{
	my $read_data = ReadINI( $filename, {comment => ";'"});

	is( $read_data->{Five}{'#com1'}, 'hi', "# is NOT a specified comment char");
	is( $read_data->{Five}{';com2'}, undef, "; is a specified comment char");
	is( $read_data->{Five}{'\'com3'}, undef, "' is a specified comment char");
	is( $read_data->{Five}{'//com4'}, 'hy', "// is NOT a specified comment char");
}

{
	my $read_data = ReadINI( $filename, {comment => qr{^\s*//}});

	is( $read_data->{Five}{'#com1'}, 'hi', "# is NOT a specified comment char");
	is( $read_data->{Five}{';com2'}, 'ho', "; is NOT a specified comment char");
	is( $read_data->{Five}{'\'com3'}, 'hu', "' is NOT a specified comment char");
	is( $read_data->{Five}{'//com4'}, undef, "// is the specified comment char");
}

{
	my $read_data = ReadINI( $filename);

	is( $read_data->{Six}{long}, "<<*END*", "heredocs are not allowed by default");
	is( $read_data->{Six}{short}, "Hello", "short value is read fine");
}
{
	my $read_data = ReadINI( $filename, {heredoc => 1});

	is( $read_data->{Six}{long}, "blah\nblah blah\nblah", "heredoc works if allowed");
	is( $read_data->{Six}{short}, "Hello", "short value is read fine");
}

{
	use File::Copy qw(copy);
	(my $filename2 = $filename) =~ s/\.ini/-2.ini/;
	copy $filename => $filename2;
	END {unlink $filename2};
	open my $FH, '>>', $filename2 or die "Unable to append to $filename2: $^E\n";
	print $FH <<'*EnD*';
long2=<<"*END*"
blah
blah blah %TEMP%
blah %NONSE_NS%
*END*
long3=<<'*END*'
blah
blah blah %TEMP%
blah %NONSE_NS%
*END*
long4=<<*END*
the temp directory is %TEMP%
nonsense is %NONSE_NS%
*END*
*EnD*
	close $FH;
	{
		my $read_data = eval {ReadINI( $filename2, {heredoc => 0})};
		ok(ref($read_data), "Extended heredocs are ignored if heredoc => 0")
	}

	{
		my $read_data = eval {ReadINI( $filename2, {heredoc => 1})};
		ok(! defined ($read_data), "Extended heredocs cause errors if heredoc => 1");
		ok(scalar($@ =~ /^\QHeredoc value for [Six]long2 not closed at end of file!\E/), "With the right error message (\$\@=$@)");
	}

	{
		my $read_data = eval {ReadINI( $filename2, {heredoc => 'Perl'})};
		ok(ref($read_data), "Extended heredocs are allowed if heredoc => 'Perl'");

		is( $read_data->{Six}{long}, "blah\nblah blah\nblah", "heredoc works if allowed");
		is( $read_data->{Six}{short}, "Hello", "short value is read fine");
		is( $read_data->{Six}{long2}, "blah\nblah blah $ENV{TEMP}\nblah ", "heredoc works if allowed, <<\"*END*\" interpolates");
		is( $read_data->{Six}{long3}, "blah\nblah blah %TEMP%\nblah %NONSE_NS%", "heredoc works if allowed, <<'*END*' doesn't interpolate");

		is( $read_data->{Six}{long4}, "the temp directory is $ENV{TEMP}\nnonsense is %NONSE_NS%", "heredoc works if allowed, <<*END* does interpolate by default");
	}

	{
		my $read_data = eval {ReadINI( $filename2, {heredoc => 'Perl', systemvars => 0})};
		ok(ref($read_data), "Extended heredocs are allowed if heredoc => 'Perl', systemvars => 0: \$\@=$@");

		is( $read_data->{Six}{long2}, "blah\nblah blah $ENV{TEMP}\nblah ", "heredoc works if allowed, <<\"*END*\" interpolates");
		is( $read_data->{Six}{long3}, "blah\nblah blah %TEMP%\nblah %NONSE_NS%", "heredoc works if allowed, <<'*END*' doesn't interpolate");
		is( $read_data->{Six}{long4}, "the temp directory is %TEMP%\nnonsense is %NONSE_NS%", "heredoc works if allowed, <<*END* doesn't interpolate by if systemvars => 0");
	}
}


{
	my $read_data = ReadINI( $filename, );

	ok( ! defined $read_data->{'__SECTIONS__'}, "the sections order is not remembered by default");
}

{
	my $read_data = ReadINI( $filename, {sectionorder => 1, case => 'sensitive'});

	ok( defined $read_data->{'__SECTIONS__'}, "the sections order is remembered if sectionorder => 1");
	is_deeply($read_data->{'__SECTIONS__'}, [qw(:default one Two Three Four Five Six)], "the sections order is remembered correctly");

	my $missing=0;
	foreach (@{$read_data->{'__SECTIONS__'}}) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in __SECTIONS__ are accessible");
}

{
	my @sections;
	my $read_data = ReadINI( $filename, {sectionorder => \@sections, case => 'sensitive'});

	ok( ! defined $read_data->{'__SECTIONS__'}, "\$config->{'__SECTIONS__'} is not defined sectionorder => \\\@array");
	is_deeply(\@sections, [qw(:default one Two Three Four Five Six)], "the sections order is remembered correctly");

	my $missing=0;
	foreach (@sections) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in \@sections are accessible");
}

{
	my $read_data = ReadINI( $filename, {sectionorder => 1, case => 'sensitive'});

	is($read_data->{Three}{aaaa}, 'asd', "case sensitive");
	is($read_data->{three}{aaaa}, undef, "case sensitive");
	is($read_data->{THREE}{aaaa}, undef, "case sensitive");

	is($read_data->{Three}{aaaa}, 'asd', "case sensitive");
	is($read_data->{Three}{Bbbb}, 'asd', "case sensitive");
	is($read_data->{Three}{CCCC}, 'asd', "case sensitive");

	is($read_data->{Three}{aaaa}, 'asd', "case sensitive");
	is($read_data->{Three}{bbbb}, undef, "case sensitive");
	is($read_data->{Three}{cccc}, undef, "case sensitive");

	is($read_data->{Three}{AAAA}, undef, "case sensitive");
	is($read_data->{Three}{BBBB}, undef, "case sensitive");
	is($read_data->{Three}{CCCC}, 'asd', "case sensitive");

	is_deeply($read_data->{'__SECTIONS__'}, [qw(:default one Two Three Four Five Six)], "the sections order is remembered with correct case");

	my $missing=0;
	foreach (@{$read_data->{'__SECTIONS__'}}) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in __SECTIONS__ are accessible");
}

{
	my $read_data = ReadINI( $filename, {sectionorder => 1, case => 'tolower'});

	is($read_data->{Three}{aaaa}, undef, "tolower");
	is($read_data->{three}{aaaa}, 'asd', "tolower");
	is($read_data->{THREE}{aaaa}, undef, "tolower");

	is($read_data->{three}{aaaa}, 'asd', "tolower");
	is($read_data->{three}{Bbbb}, undef, "tolower");
	is($read_data->{three}{CCCC}, undef, "tolower");

	is($read_data->{three}{aaaa}, 'asd', "tolower");
	is($read_data->{three}{bbbb}, 'asd', "tolower");
	is($read_data->{three}{cccc}, 'asd', "tolower");

	is($read_data->{three}{AAAA}, undef, "tolower");
	is($read_data->{three}{BBBB}, undef, "tolower");
	is($read_data->{three}{CCCC}, undef, "tolower");

	is_deeply($read_data->{'__SECTIONS__'}, [qw(:default one two three four five six)], "the sections order is remembered with correct case");

	my $missing=0;
	foreach (@{$read_data->{'__SECTIONS__'}}) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in __SECTIONS__ are accessible");
}

{
	my $read_data = ReadINI( $filename, {sectionorder => 1, case => 'toupper'});

	is($read_data->{Three}{AAAA}, undef, "toupper");
	is($read_data->{three}{AAAA}, undef, "toupper");
	is($read_data->{THREE}{AAAA}, 'asd', "toupper");

	is($read_data->{THREE}{aaaa}, undef, "toupper");
	is($read_data->{THREE}{Bbbb}, undef, "toupper");
	is($read_data->{THREE}{CCCC}, 'asd', "toupper");

	is($read_data->{THREE}{aaaa}, undef, "toupper");
	is($read_data->{THREE}{bbbb}, undef, "toupper");
	is($read_data->{THREE}{cccc}, undef, "toupper");

	is($read_data->{THREE}{AAAA}, 'asd', "toupper");
	is($read_data->{THREE}{BBBB}, 'asd', "toupper");
	is($read_data->{THREE}{CCCC}, 'asd', "toupper");

	is_deeply($read_data->{'__SECTIONS__'}, [qw(:DEFAULT ONE TWO THREE FOUR FIVE SIX)], "the sections order is remembered with correct case");

	my $missing=0;
	foreach (@{$read_data->{'__SECTIONS__'}}) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in __SECTIONS__ are accessible");
}

{
	my $read_data = ReadINI( $filename, {sectionorder => 1, case => 'preserve'});

	is($read_data->{Three}{AAAA}, 'asd', "preserve");
	is($read_data->{three}{AAAA}, 'asd', "preserve");
	is($read_data->{THREE}{AAAA}, 'asd', "preserve");

	is($read_data->{THREE}{aaaa}, 'asd', "preserve");
	is($read_data->{THREE}{Bbbb}, 'asd', "preserve");
	is($read_data->{THREE}{CCCC}, 'asd', "preserve");

	is($read_data->{THREE}{aaaa}, 'asd', "preserve");
	is($read_data->{THREE}{bbbb}, 'asd', "preserve");
	is($read_data->{THREE}{cccc}, 'asd', "preserve");

	is($read_data->{THREE}{AAAA}, 'asd', "preserve");
	is($read_data->{THREE}{BBBB}, 'asd', "preserve");
	is($read_data->{THREE}{CCCC}, 'asd', "preserve");

	is_deeply($read_data->{'__SECTIONS__'}, [qw(:default one Two Three Four Five Six)], "the sections order is remembered with correct case");

	my $missing=0;
	foreach (@{$read_data->{'__SECTIONS__'}}) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in __SECTIONS__ are accessible");
}

{
	my $read_data = ReadINI( $filename, {sectionorder => 1, case => 'lower'});

	is($read_data->{Three}{AAAA}, 'asd', "lower");
	is($read_data->{three}{AAAA}, 'asd', "lower");
	is($read_data->{THREE}{AAAA}, 'asd', "lower");

	is($read_data->{THREE}{aaaa}, 'asd', "lower");
	is($read_data->{THREE}{Bbbb}, 'asd', "lower");
	is($read_data->{THREE}{CCCC}, 'asd', "lower");

	is($read_data->{THREE}{aaaa}, 'asd', "lower");
	is($read_data->{THREE}{bbbb}, 'asd', "lower");
	is($read_data->{THREE}{cccc}, 'asd', "lower");

	is($read_data->{THREE}{AAAA}, 'asd', "lower");
	is($read_data->{THREE}{BBBB}, 'asd', "lower");
	is($read_data->{THREE}{CCCC}, 'asd', "lower");

	my %keys; @keys{keys %$read_data} = ();
	is_deeply(\%keys, {map {$_ => undef} qw(:default one two three four five six __SECTIONS__)}, "the sections are remembered with correct case");

	is_deeply($read_data->{'__SECTIONS__'}, [qw(:default one two three four five six)], "the sections order is remembered with correct case");

	my $missing=0;
	foreach (@{$read_data->{'__SECTIONS__'}}) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in __SECTIONS__ are accessible");
}

{
	my $read_data = ReadINI( $filename, {sectionorder => 1, case => 'upper'});

	is($read_data->{Three}{AAAA}, 'asd', "upper");
	is($read_data->{three}{AAAA}, 'asd', "upper");
	is($read_data->{THREE}{AAAA}, 'asd', "upper");

	is($read_data->{THREE}{aaaa}, 'asd', "upper");
	is($read_data->{THREE}{Bbbb}, 'asd', "upper");
	is($read_data->{THREE}{CCCC}, 'asd', "upper");

	is($read_data->{THREE}{aaaa}, 'asd', "upper");
	is($read_data->{THREE}{bbbb}, 'asd', "upper");
	is($read_data->{THREE}{cccc}, 'asd', "upper");

	is($read_data->{THREE}{AAAA}, 'asd', "upper");
	is($read_data->{THREE}{BBBB}, 'asd', "upper");
	is($read_data->{THREE}{CCCC}, 'asd', "upper");

	my %keys; @keys{keys %$read_data} = ();
	is_deeply(\%keys, {map {$_ => undef} qw(:DEFAULT ONE TWO THREE FOUR FIVE SIX __SECTIONS__)}, "the sections are remembered with correct case");

	is_deeply($read_data->{'__SECTIONS__'}, [qw(:DEFAULT ONE TWO THREE FOUR FIVE SIX)], "the sections order is remembered with correct case");

	is_deeply($read_data->{'__SECTIONS__'}, [qw(:DEFAULT ONE TWO THREE FOUR FIVE SIX)], "the sections order is remembered with correct case");

	my $missing=0;
	foreach (@{$read_data->{'__SECTIONS__'}}) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in __SECTIONS__ are accessible");
}

# defaults
{
	my $read_data = ReadINI( $filename, {case => 'preserve', withdefaults => 1});
	ok(ref($read_data), "withdefaults => 1, case => preserve");

	AddDefaults($read_data, 'one', ':default');

	is($read_data->{one}{int}, 1, "found the own value");
	is($read_data->{one}{foo}, 'dz_difolt', "found a default value");
	is($read_data->{one}{bar}, undef, "found a missing value");
}

{
	my $read_data = ReadINI( $filename, {case => 'preserve', withdefaults => 1});
	ok(ref($read_data), "withdefaults => 1, case => preserve with custom defaults");

	AddDefaults($read_data, 'one',  {int => 99, foo => 'custom'});

	is($read_data->{one}{int}, 1, "found the own value");
	is($read_data->{one}{foo}, 'custom', "found a default value");
	is($read_data->{one}{bar}, undef, "found a missing value");
}

{
	my $read_data = ReadINI( $filename, {case => 'toupper', withdefaults => 1});
	ok(ref($read_data), "withdefaults => 1, case => toupper");

	AddDefaults($read_data, 'ONE', ':DEFAULT');

	is($read_data->{ONE}{INT}, 1, "found the own value");
	is($read_data->{ONE}{FOO}, 'dz_difolt', "found a default value");
	is($read_data->{ONE}{BAR}, undef, "found a missing value");
}

{
	my $read_data = ReadINI( $filename, {case => 'preserve', sectionorder => 1});

	(my $filename2 = $filename) =~ s/\.ini$/-3.ini/;
	ok(WriteINI( $filename2, $read_data), "Wrote the ini file with case => preserve, sectionorder => 1");
	END {unlink $filename2};

	my $read_data2 = ReadINI( $filename2, {case => 'preserve', sectionorder => 1});

	is_deeply( $read_data2, $read_data, "Still have the same data")
}

{
	my $read_data = ReadINI( $filename, {case => 'tolower', sectionorder => 1});

	(my $filename2 = $filename) =~ s/\.ini$/-3.ini/;
	ok(WriteINI( $filename2, $read_data), "Wrote the ini file with case => tolower, sectionorder => 1");

	my $read_data2 = ReadINI( $filename2, {case => 'preserve', sectionorder => 1});

	is_deeply( $read_data2, $read_data, "Still have the same data")
}

{
	my $read_data = ReadINI( $filename, {case => 'toupper', sectionorder => 1});

	(my $filename2 = $filename) =~ s/\.ini$/-3.ini/;
	ok(WriteINI( $filename2, $read_data), "Wrote the ini file with case => toupper, sectionorder => 1");

	my $read_data2 = ReadINI( $filename2, {case => 'preserve', sectionorder => 1});

	is_deeply( $read_data2, $read_data, "Still have the same data")
}

{
	my $read_data = ReadINI( $filename, {case => 'lower', sectionorder => 1});

	(my $filename2 = $filename) =~ s/\.ini$/-3.ini/;
	ok(WriteINI( $filename2, $read_data), "Wrote the ini file with case => lower, sectionorder => 1");

	my $read_data2 = ReadINI( $filename2, {case => 'preserve', sectionorder => 1});

	is_deeply( $read_data2, $read_data, "Still have the same data")
}

{
	my $read_data = ReadINI( $filename, {case => 'upper', sectionorder => 1});

	(my $filename2 = $filename) =~ s/\.ini$/-3.ini/;
	ok(WriteINI( $filename2, $read_data), "Wrote the ini file with case => upper, sectionorder => 1");

	my $read_data2 = ReadINI( $filename2, {case => 'preserve', sectionorder => 1});

	is_deeply( $read_data2, $read_data, "Still have the same data")
}

{
	my $read_data = ReadINI( $filename, {case => 'preserve', sectionorder => 1});

	(my $filename2 = $filename) =~ s/\.ini$/-3.ini/;
	ok(WriteINI( $filename2, $read_data), "Wrote the ini file with case => preserve, sectionorder => 1");

	my $read_data2 = ReadINI( $filename2, {case => 'preserve', sectionorder => 1});

	is_deeply( $read_data2, $read_data, "Still have the same data")
}

{
	my $read_data = ReadINI( $filename, {case => 'preserve', sectionorder => 0});

	(my $filename2 = $filename) =~ s/\.ini$/-3.ini/;
	ok(WriteINI( $filename2, $read_data), "Wrote the ini file with case => preserve, sectionorder => 0");

	my $read_data2 = ReadINI( $filename2, {case => 'preserve', sectionorder => 0});

	is_deeply( $read_data2, $read_data, "Still have the same data")
}

{
	my $read_data = ReadINI( $filename, {sectionorder => 1, case => 'lower', class => 'Hash::Case::Lower'});

	is($read_data->{Three}{AAAA}, 'asd', "Hash::Case::Lower");
	is($read_data->{three}{AAAA}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{AAAA}, 'asd', "Hash::Case::Lower");

	is($read_data->{THREE}{aaaa}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{Bbbb}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{CCCC}, 'asd', "Hash::Case::Lower");

	is($read_data->{THREE}{aaaa}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{bbbb}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{cccc}, 'asd', "Hash::Case::Lower");

	is($read_data->{THREE}{AAAA}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{BBBB}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{CCCC}, 'asd', "Hash::Case::Lower");

	my %keys; @keys{keys %$read_data} = ();
	is_deeply(\%keys, {map {$_ => undef} qw(:default one two three four five six __sections__)}, "the sections are remembered with correct case");

	is_deeply($read_data->{'__SECTIONS__'}, [qw(:default one two three four five six)], "the sections order is remembered with correct case");

	my $missing=0;
	foreach (@{$read_data->{'__SECTIONS__'}}) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in __SECTIONS__ are accessible");
}

{
	my $read_data = ReadINI( $filename, {sectionorder => 1, case => 'preserve', class => 'Hash::Case::Lower'});

	is($read_data->{Three}{AAAA}, 'asd', "Hash::Case::Lower");
	is($read_data->{three}{AAAA}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{AAAA}, 'asd', "Hash::Case::Lower");

	is($read_data->{THREE}{aaaa}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{Bbbb}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{CCCC}, 'asd', "Hash::Case::Lower");

	is($read_data->{THREE}{aaaa}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{bbbb}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{cccc}, 'asd', "Hash::Case::Lower");

	is($read_data->{THREE}{AAAA}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{BBBB}, 'asd', "Hash::Case::Lower");
	is($read_data->{THREE}{CCCC}, 'asd', "Hash::Case::Lower");

	my %keys; @keys{keys %$read_data} = ();
	is_deeply(\%keys, {map {$_ => undef} qw(:default one two three four five six __sections__)}, "the sections are remembered with correct case");

	is_deeply($read_data->{'__SECTIONS__'}, [qw(:default one Two Three Four Five Six)], "the sections order is remembered with correct case");

	my $missing=0;
	foreach (@{$read_data->{'__SECTIONS__'}}) {
		$missing++ unless exists ($read_data->{$_});
	}
	is ($missing, 0, "All sections in __SECTIONS__ are accessible");
}
