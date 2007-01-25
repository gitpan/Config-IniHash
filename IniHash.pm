package Config::IniHash;

use Carp;
use strict;
use Symbol;
use IO::Scalar;

use Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
@ISA = qw(Exporter);
@EXPORT = qw(&ReadINI &WriteINI &PrintINI);
@EXPORT_OK = qw(&ReadINI &WriteINI &PrintINI &AddDefaults &ReadSection);
$VERSION = '2.8.2';

if (0) { # for PerlApp/PerlSvc/PerlCtrl/Perl2Exe
	require 'Hash/WithDefaults.pm';
	require 'Hash/Case/Lower.pm';
	require 'Hash/Case/Upper.pm';
	require 'Hash/Case/Preserve.pm';
}

#use vars qw(heredoc systemvars withdefaults forValue);
$Config::IniHash::case = 'lower';
	# upper, preserve, toupper, tolower
$Config::IniHash::heredoc = 0;
$Config::IniHash::systemvars = 1;
$Config::IniHash::withdefaults = 0;
$Config::IniHash::sectionorder = 0;
$Config::IniHash::comment = qr/^\s*[#;]/;
sub BREAK () {1}

sub prepareOpt {
	my $opt = shift();

	$opt->{case} = $Config::IniHash::case unless exists $opt->{case};
	$opt->{case} = $opt->{insensitive} if exists $opt->{insensitive}; # for backwards compatibility
	$opt->{heredoc} = $Config::IniHash::heredoc unless exists $opt->{heredoc};
	$opt->{systemvars} = $Config::IniHash::systemvars unless exists $opt->{systemvars};
	$opt->{withdefaults} = $Config::IniHash::withdefaults unless exists $opt->{withdefaults};
	$opt->{forValue} = $Config::IniHash::forValue unless exists $opt->{forValue};
	$opt->{sectionorder} = $Config::IniHash::sectionorder unless exists $opt->{sectionorder};
	$opt->{comment} = $Config::IniHash::comment unless exists $opt->{comment};

	for ($opt->{case}) {
		$_ = lc $_;
		$_ = 'no' unless $_;

		local $Carp::CarpLevel = 1;
		/^lower/ and do {
			$opt->{class} = 'Hash::Case::Lower';
			undef $opt->{forName};
			BREAK}
		or
		/^upper/ and do {
			$opt->{class} = 'Hash::Case::Upper';
			undef $opt->{forName};
			BREAK}
		or
		/^preserve/ and do {
			$opt->{class} = 'Hash::Case::Preserve';
			undef $opt->{forName};
			BREAK}
		or
		/^toupper/ and do {
			undef $opt->{class};
			$opt->{forName} = 'uc';
			BREAK}
		or
		/^tolower/ and do {
			undef $opt->{class};
			$opt->{forName} = 'lc';
			BREAK}
		or
		/^(?:no|sensitive)/ and do {
			undef $opt->{class};
			undef $opt->{forName};
			BREAK}
		or
			croak "Option 'case' may be set only to:\n\t'lower', 'upper', 'preserve', 'toupper', 'tolower' or 'no'\n";

	}

	if ($opt->{class}) {
		my $class = $opt->{class};
		my $file = $class;
		$file =~ s{::}{/}g;
		if (!$INC{$file.'.pm'}) {
			eval "use $class;\n1"
				or die "ERROR autoloading $class : $@";
		}
	}

	if ($opt->{withdefaults} and !$INC{'Hash/WithDefaults.pm'}) {
		eval "use Hash::WithDefaults;\n1"
			or die "ERROR autoloading Hash::WithDefaults : $@";
	}

	$opt->{heredoc} = ($opt->{heredoc} ? 1 : 0);
	if (defined $opt->{systemvars} and $opt->{systemvars}) {
		$opt->{systemvars} = \%ENV unless (ref $opt->{systemvars});
	} else {
		$opt->{systemvars} = 0;
	}

	if (! ref $opt->{comment}) {
		$opt->{comment} = qr/^\s*[$opt->{comment}]/;
	}
}

sub ReadINI {
    my $file = shift;
	my %opt;
	if (@_ == 1 and ref $_[0]) {
		%opt = %{$_[0]};
	} elsif (@_ % 2 == 0) {
		%opt = @_;
	} else {
		croak("ReadINI expects the filename plus either a reference to a hash of options or a list with even number of items!");
	}
	prepareOpt(\%opt);

    my $hash;
	if ($opt{hash}) {
		$hash = $opt{hash};
	} else {
		$hash = {};
		tie %$hash, $opt{class}
			if $opt{class};
	}

    my $section = '';
	my $IN;
	if (ref $file) {
		my $ref = ref $file;
		if ($ref eq 'SCALAR') {
			$IN = gensym();
			tie *$IN, 'IO::Scalar', $file;
		} elsif ($ref eq 'ARRAY') {
			my $data = join "\n", map {chomp;$_} @$file;
			$IN = gensym();
			tie *$IN, 'IO::Scalar', \$data;
		} elsif ($ref eq 'HASH') {
			croak "ReadINI cannot accept a HASH reference as it's parameter!";
		} else {
			$IN = $file; #assuming it's a glob or an object that'll know what to do
		}
	} else {
		open $IN, $file or return undef;
	}

	my ($lc,$uc) = ( (defined $opt{forName} and $opt{forName} eq 'lc'), (defined $opt{forName} and $opt{forName} eq 'uc'));
	my $forValue = $opt{forValue};

	$hash->{'__SECTIONS__'} = [] if $opt{sectionorder};
    while (<$IN>) {
        $_ =~ $opt{comment} and next;

        if (/^\[(.*)\]/) {
            $section = $1;
			if ($lc) { $section = lc $section} elsif ($uc) { $section = uc $section };
			push @{$hash->{'__SECTIONS__'}}, $section if $opt{sectionorder};
            unless ($hash->{$section}) {
                my %tmp = ();
				if ($opt{withdefaults}) {
					tie %tmp, 'Hash::WithDefaults', $opt{case};
				} else {
					tie %tmp, $opt{class}
						if $opt{class};
				}
                $hash->{$section} = \%tmp;
                next;
            }
        }

        if (/^([^=]*?)\s*=\s*(.*?)\s*$/) {
            my ($name,$value) = ($1,$2);
			if ($opt{heredoc} and $value =~ /^<<(.+)$/) {
				my $terminator = $1;
				$value = '';
				while (<$IN>) {
					chomp;
					last if $_ eq $terminator;
					$value .= "\n".$_;
				}
				croak "Heredoc value for [$section]$name not closed at end of file!"
				 unless defined $_;
				substr ($value, 0, 1) = '';
			}
            $value =~ s/%([^%]*)%/$opt{systemvars}{$1} || "%$1%"/eg if $opt{systemvars};
			if ($lc) { $name = lc $name} elsif ($uc) { $name = uc $name };
			if ($forValue) {
				$value = $forValue->($name, $value, $section, $hash);
			}
            $hash->{$section}{$name} = $value if defined $value;
        }
    }
    close $IN;
    return $hash;
}

sub WriteINI {
    my ($file,$hash) = @_;
    open OUT, ">$file" or return undef;
	if (exists $hash->{'__SECTIONS__'}) {
		my $all_have_order = (scalar(@{$hash->{'__SECTIONS__'}}) == scalar(keys %$hash));
		foreach my $section (@{$hash->{'__SECTIONS__'}}) {
			print OUT "[$section]\n";
			my $sec;
			if (exists $hash->{$section}) {
				my $sec = $hash->{$section};
				foreach my $key (keys %{$hash->{$section}}) {
					if ($key =~ /^[#';]/ and ! defined($sec->{$key})) {
						print OUT"$key\n";
					} elsif ($sec->{$key} =~ /\n/) {
						print OUT"$key=<<*END_$key*\n$sec->{$key}\n*END_$key*\n";
					} else {
						print OUT"$key=$sec->{$key}\n";
					}
				}
			} else {
				$all_have_order = 0;
			}
			print OUT "\n";
		}
		if (!$all_have_order) {
			my %ordered; @ordered{@{$hash->{'__SECTIONS__'}}} = ();
			foreach my $section (keys %$hash) {
				next if exists($ordered{$section}) or $section eq '__SECTIONS__';
				print OUT "[$section]\n";
				my $sec = $hash->{$section};
				foreach my $key (keys %{$hash->{$section}}) {
					if ($key =~ /^[#';]/ and ! defined($sec->{$key})) {
						print OUT"$key\n";
					} elsif ($sec->{$key} =~ /\n/) {
						print OUT"$key=<<*END_$key*\n$sec->{$key}\n*END_$key*\n";
					} else {
						print OUT"$key=$sec->{$key}\n";
					}
				}
				print OUT "\n";
			}
		}
	} else {
		foreach my $section (keys %$hash) {
			print OUT "[$section]\n";
			my $sec = $hash->{$section};
			foreach my $key (keys %{$hash->{$section}}) {
				if ($key =~ /^[#';]/ and ! defined($sec->{$key})) {
					print OUT"$key\n";
				} elsif ($sec->{$key} =~ /\n/) {
					print OUT"$key=<<*END_$key*\n$sec->{$key}\n*END_$key*\n";
				} else {
					print OUT"$key=$sec->{$key}\n";
				}
			}
			print OUT "\n";
		}
	}
    close OUT;
    return 1;
}
*PrintINI = \&WriteINI;

sub AddDefaults {
	my ($ini,$subsection,$mainsection) = @_;

	croak "$subsection doesn't exist in the hash!"
		unless exists $ini->{$subsection};

	croak "$mainsection doesn't exist in the hash!"
		unless exists $ini->{$mainsection};

	if ( tied(%{$ini->{$subsection}})->isa('Hash::WithDefaults') ) {
		tied(%{$ini->{$subsection}})->AddDefault($ini->{$mainsection});
	} else {
		croak "You can call AddDefaults ONLY on hashes created with\n\$Win32::IniHash::withdefaults=1 !"
	}
}


sub ReadSection {
    my $text = shift;
	my %opt = @_;
	prepareOpt(\%opt);

	my $hash= {};
	if ($opt{withdefaults}) {
		tie %$hash, 'Hash::WithDefaults', $opt{case};
	} else {
		tie %$hash, $opt{class}
			if $opt{class};
	}
	my $IN = gensym();
	tie *$IN, 'IO::Scalar', \$text;

	my ($lc,$uc) = ( $opt{forName} eq 'lc', $opt{forName} eq 'uc');
	my $forValue = $opt{forValue};
    while (<$IN>) {
        /^\s*;/ and next;

        if (/^([^=]*?)\s*=\s*(.*?)\s*$/) {
            my ($name,$value) = ($1,$2);
			if ($opt{heredoc} and $value =~ /^<<(.+)$/) {
				my $terminator = $1;
				$value = '';
				while (<$IN>) {
					chomp;
					last if $_ eq $terminator;
					$value .= "\n".$_;
				}
				croak "Heredoc value for $name not closed at end of string!"
					unless defined $_;
				substr ($value, 0, 1) = '';
			}
            $value =~ s/%(.*?)%/$opt{systemvars}{$1}/g if $opt{systemvars};
			if ($lc) { $name = lc $name} elsif ($uc) { $name = uc $name };
			if ($forValue) {
				$value = $forValue->($name, $value, undef, $hash);
			}
            $hash->{$name} = $value;
        }
    }
    close $IN;
    return $hash;
}

1;
__END__

=head1 NAME

Config::IniHash - Perl extension for reading and writing INI files

version 2.7

=head1 SYNOPSIS

  use Config::IniHash;
  $Config = ReadINI 'c:\some\file.ini';

=head1 DESCRIPTION

This module reads and writes INI files.

=head2 Functions

=head3 ReadINI

	$hashreference = ReadINI ($filename, %options)
	$hashreference = ReadINI (\$data, %options)
	$hashreference = ReadINI (\@data, %options)
	$hashreference = ReadINI ($filehandle, %options)

The returned hash contains a reference to a hash for each section of
the INI.

    [section]
    name=value
  leads to
    $hash->{section}->{name}  = value;

The available options are:

=over 4

=item heredoc

- controls whether the module supports the heredoc syntax :

	name=<<END
	the
	many lines
	long value
	END
	othername=value

Default: 0 = OFF

=item systemvars

- controls whether the (system) variables enclosed in %% are
interpolated and optionaly contains the values in a hash ref.

    name=%USERNAME%
  leads to
    $data->{section}->{name} = "Jenda"

	systemvars = 1	- yes, take values from %ENV
	systemvars = \%hash	- yes, take values from %hash
	systemvars = 0	- no

=item case

- controls whether the created hash is case insensitive. The possible values are

  sensitive	- the hash will be case sensitive
  tolower	- the hash will be case sensitive, all keys are made lowercase
  toupper	- the hash will be case sensitive, all keys are made uppercase
  preserve	- the hash will be case insensitive, the case is preserved
  lower	- the hash will be case insensitive, all keys are made lowercase
  upper	- the hash will be case insensitive, all keys are made uppercase

=item withdefaults

- controls whether the created section hashes support defaults.

=item sectionorder

- if set to a true value then created hash will contain

	$config->{'__SECTIONS__'} = [ 'the', 'names', 'of', 'the', 'sections', 'in', 'the',
		'order', 'they', 'were', 'specified', 'in', 'the', 'INI file'];

=item forValue

- allows you to install a callback that will be called for each value as soon as it is read
but before it is stored in the hash.
The function is called like this:

  $value = $forValue->($name, $value, $sectionname, $INIhashref);

If the callback returns an undef, the value will not be stored.

=item comment

- regular expression used to identify comments or a string containing the list of characters starting a comment.
Each line is tested against the regexp is ignored if matches. If you specify a string a regexp like this will be created:

	qr/^\s*[the_list]/

The default is

	qr/^\s*[#;]

=back

You may also set the defaults for the options by modifying the $Config::IniHash::optionname
variables. These default settings will be used if you do not specify the option in the ReadINI()
or ReadSection() call.

=head3 ReadSection

  $hashreference = ReadSection ($string)

This function parses a string as if it was a section of an INI file and creates a hash with the values.
It accepts the same options as ReadINI.

=head3 WriteINI

  WriteINI ($filename, $hashreference)

Writes the hash of hashes to a file.

=head3 PrintINI

The same as WriteINI().

=head1 AUTHOR

Jan Krynicky <Jenda@Krynicky.cz>
http://Jenda.Krynicky.cz

=head1 COPYRIGHT

Copyright (c) 2002-2005 Jan Krynicky <Jenda@Krynicky.cz>. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
