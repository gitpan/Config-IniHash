package Config::IniHash;

use 5.8.0;
use Carp;
use strict;
use Symbol;

use Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
@ISA = qw(Exporter);
@EXPORT = qw(&ReadINI &WriteINI &PrintINI);
@EXPORT_OK = qw(&ReadINI &WriteINI &PrintINI &AddDefaults &ReadSection);
$VERSION = '3.00.05';

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
$Config::IniHash::allowmultiple = 0;
$Config::IniHash::comment = qr/^\s*[#;]/;

*Config::IniHash::allow_multiple = \$Config::IniHash::allowmultiple;

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
	$opt->{allowmultiple} = $opt->{allow_multiple} unless exists $opt->{allowmultiple};
	$opt->{allowmultiple} = $Config::IniHash::allowmultiple unless exists $opt->{allowmultiple};
	$opt->{comment} = $Config::IniHash::comment unless exists $opt->{comment};

	if ($opt->{class}) {
		delete $opt->{withdefaults};
	} else {
		for ($opt->{case}) {
			$_ = lc $_;
			$_ = 'no' unless $_;

			local $Carp::CarpLevel = 1;
			/^lower/ and do {
				if ($opt->{sectionorder} and !ref($opt->{sectionorder})) {
					$opt->{class} = 'Hash::Case::LowerX';
				} else {
					$opt->{class} = 'Hash::Case::Lower';
				}
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

		if ($opt->{class} and $opt->{class} ne 'Hash::Case::LowerX') {
			my $class = $opt->{class};
			my $file = $class;
			$file =~ s{::}{/}g;
			if (!$INC{$file.'.pm'}) {
				eval "use $class;\n1"
					or croak "ERROR autoloading $class : $@";
			}
		}

		if ($opt->{withdefaults} and !$INC{'Hash/WithDefaults.pm'}) {
			eval "use Hash::WithDefaults;\n1"
				or croak "ERROR autoloading Hash::WithDefaults : $@";
		}
	}

	if (! $opt->{heredoc}) {
		$opt->{heredoc} = 0;
	} elsif (lc($opt->{heredoc}) eq 'perl') {
		$opt->{heredoc} = 'perl'
	} else {
		$opt->{heredoc} = 1;
	}
	if (defined $opt->{systemvars} and $opt->{systemvars}) {
		$opt->{systemvars} = \%ENV unless (ref $opt->{systemvars});
	} else {
		$opt->{systemvars} = 0;
	}

	if (! ref $opt->{comment}) {
		$opt->{comment} = qr/^\s*[$opt->{comment}]/;
	}

	if (ref $opt->{allowmultiple}) {
		croak "The allowmultiple option must be a true or false scalar or a reference to a hash of arrays, hashes, regexps or comma separated lists of names!"
			unless ref $opt->{allowmultiple} eq 'HASH';

		foreach my $section (values %{$opt->{allowmultiple}}) {
			if (! ref $section) {
				$section = {map( ($_ => undef), split( /\s*,\s*/, $section))};
			} elsif (ref $section eq 'ARRAY') {
				$section = {map( ($_ => undef), @$section)};
			} elsif (ref $section eq 'Regexp') {
			} elsif (ref $section ne 'HASH') {
				croak "The allowmultiple option must be a true or false scalar or a reference to a hash of arrays, hashes, regexps or comma separated lists of names!"
			}
		}
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
			open $IN, '<', $file; # will read from the referenced scalar
		} elsif ($ref eq 'ARRAY') {
			my $data = join "\n", map {chomp;$_} @$file;
			open $IN, '<', \$data; # will read from the referenced scalar
		} elsif ($ref eq 'HASH') {
			croak "ReadINI cannot accept a HASH reference as it's parameter!";
		} else {
			$IN = $file; #assuming it's a glob or an object that'll know what to do
		}
	} else {
		open $IN, $file or return undef;
	}

	my ($lc,$uc) = ( (defined $opt{forName} and $opt{forName} eq 'lc'), (defined $opt{forName} and $opt{forName} eq 'uc'));
	if ($opt{sectionorder}) {
		my $arrayref;
		if (ref $opt{sectionorder}) {
			$arrayref = $opt{sectionorder}
		} else {
			$arrayref = $hash->{'__SECTIONS__'} = [];
		}
		if ($opt{case} eq 'lower' or $opt{case} eq 'tolower') {
			$opt{sectionorder} = sub {push @$arrayref, lc($_[0])}
		} elsif ($opt{case} eq 'upper' or $opt{case} eq 'toupper') {
			$opt{sectionorder} = sub {push @$arrayref, uc($_[0])}
		} else {
			$opt{sectionorder} = sub {push @$arrayref, $_[0]}
		}
	}
	my $forValue = $opt{forValue};

    while (<$IN>) {
        $_ =~ $opt{comment} and next;

        if (/^\[(.*)\]/) {
            $section = $1;
			$opt{sectionorder}->($section) if $opt{sectionorder};
			if ($lc) { $section = lc $section} elsif ($uc) { $section = uc $section };
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
			if ($opt{heredoc} eq 'perl' and $value =~ /^<<(['"])?(.+)\1\s*$/) {
				my $type = $1;
				my $terminator = $2;
				$value = '';
				while (<$IN>) {
					chomp;
					last if $_ eq $terminator;
					$value .= "\n".$_;
				}
				croak "Heredoc value for [$section]$name not closed at end of file!"
				 unless defined $_;
				substr ($value, 0, 1) = '';

				if ($type eq '') {
					$value =~ s/%([^%]*)%/exists($opt{systemvars}{$1}) ? $opt{systemvars}{$1} : "%$1%"/eg if $opt{systemvars};
				} elsif ($type eq q{"}) {
					if ($opt{systemvars}) {
						$value =~ s/%([^%]*)%/$opt{systemvars}{$1}/g;
					} else {
						$value =~ s/%([^%]*)%/$ENV{$1}/g;
					}
				}

			} elsif ($opt{heredoc} and $value =~ /^<<(.+)\s*$/) {
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
				$value =~ s/%([^%]*)%/exists($opt{systemvars}{$1}) ? $opt{systemvars}{$1} : "%$1%"/eg if $opt{systemvars};

			} else {
				$value =~ s/%([^%]*)%/exists($opt{systemvars}{$1}) ? $opt{systemvars}{$1} : "%$1%"/eg if $opt{systemvars};
			}

			if ($lc) { $name = lc $name} elsif ($uc) { $name = uc $name };
			if ($forValue) {
				$value = $forValue->($name, $value, $section, $hash);
			}
			if (defined $value) {
				if (!$opt{allowmultiple}) {
					$hash->{$section}{$name} = $value; # overwrite
				} elsif (!ref $opt{allowmultiple}) {
					if (exists $hash->{$section}{$name}) {
						if (ref $hash->{$section}{$name}) {
							push @{$hash->{$section}{$name}}, $value;
						} else {
							$hash->{$section}{$name} = [ $hash->{$section}{$name}, $value]; # second value
						}
					} else {
						$hash->{$section}{$name} = $value; # set
					}
				} else {
					if (exists $opt{allowmultiple}{$section}{$name} or exists $opt{allowmultiple}{'*'}{$name}) {
						push @{$hash->{$section}{$name}}, $value;
					} else {
						$hash->{$section}{$name} = $value; # set
					}
				}
			}
        }
    }
    close $IN;
    return $hash;
}

sub WriteINI {
    my ($file,$hash) = @_;
    open OUT, ">$file" or return undef;
	if (exists $hash->{'__SECTIONS__'}) {
		my $all_have_order = (scalar(@{$hash->{'__SECTIONS__'}}) == scalar(keys %$hash)-1);
		foreach my $section (@{$hash->{'__SECTIONS__'}}) {
			print OUT "[$section]\n";
			my $sec;
			if (exists $hash->{$section}) {
				my $sec = $hash->{$section};
				foreach my $key (sort keys %{$hash->{$section}}) {
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
				foreach my $key (sort keys %{$hash->{$section}}) {
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
	my ($ini, $section, $defaults) = @_;

	croak "$section doesn't exist in the hash!"
		unless exists $ini->{$section};

	croak "You can call AddDefaults ONLY on hashes created with\n\$Config::IniHash::withdefaults=1 !"
		unless tied(%{$ini->{$section}}) and tied(%{$ini->{$section}})->isa('Hash::WithDefaults');

	if (ref $defaults) {
		croak "The defaults must be a section name or a hash ref!"
			unless ref $defaults eq 'HASH';

		tied(%{$ini->{$section}})->AddDefault($defaults);
	} else {
		croak "$defaults doesn't exist in the hash!"
			unless exists $ini->{$defaults};

		tied(%{$ini->{$section}})->AddDefault($ini->{$defaults});
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

	open my $IN, '<', \$text;

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

package Hash::Case::LowerX;
use base 'Hash::Case';

use strict;
use Carp;

sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::native_init($args);

    croak "No options possible for ".__PACKAGE__
        if keys %$args;

    $self;
}

sub FETCH($)  { $_[0]->{($_[1] eq '__SECTIONS__' ? $_[1] : lc $_[1])} }
sub STORE($$) { $_[0]->{($_[1] eq '__SECTIONS__' ? $_[1] : lc $_[1])} = $_[2] }
sub EXISTS($) { exists $_[0]->{($_[1] eq '__SECTIONS__' ? $_[1] : lc $_[1])} }
sub DELETE($) { delete $_[0]->{($_[1] eq '__SECTIONS__' ? $_[1] : lc $_[1])} }

1;
__END__

=head1 NAME

Config::IniHash - Perl extension for reading and writing INI files

version 3.00.05

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

	0 : heredocs are ignored, $data->{section}{name} will be '<<END'
	1 : heredocs are supported, $data->{section}{name} will be "the\nmany lines\nlong value"
	    The Perl-lie extensions of name=<<"END" and <<'END' are not supported!
	'Perl' : heredocs are supported, $data->{section}{name} will be "the\nmany lines\nlong value"
	    The Perl-lie extensions of name=<<"END" and <<'END' are supported.
		The <<'END' never interpolates %variables%, the "END" always interpolates variables,
		unlike in other values, the %variables% that are not defined do not stay in the string!

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
  preserve	- the hash will be case insensitive, the case is preserved (tied)
  lower	- the hash will be case insensitive, all keys are made lowercase (tied)
  upper	- the hash will be case insensitive, all keys are made uppercase (tied)

=item withdefaults

- controls whether the created section hashes support defaults. See L<Hash::WithDefaults>.

=item class

- allows you to specify the class into which to tie the created hashes. This option overwrites
the "case" and "withdefaults" options!

=item sectionorder

- if set to a true value then created hash will contain

	$config->{'__SECTIONS__'} = [ 'the', 'names', 'of', 'the', 'sections', 'in', 'the',
		'order', 'they', 'were', 'specified', 'in', 'the', 'INI file'];

- if set to an array ref, then the list will be stored in that array, and no $config->{'__SECTIONS__'}
is created. The case of the section names stored in this array is controled by the "case" option even
in case you specify the "class".

=item allowmultiple

- if set to a true scalar value then multiple items with the same names in a section
do not overwrite each other, but result in an array of the values.

- if set to a hash of hashes (or hash of arrays or hash of comma separated item names)
specifies what items in what sections will end up as
hashes containing the list of values. All the specified items will be arrays, even if
there is just a single value. To affect the items in all sections use section name '*'.

By default false.

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

=head3 AddDefaults

  AddDefaults( $config, 'normal section name', 'default section name');
  AddDefaults( $config, 'normal section name', \%defaults);

This subroutine adds a some default values into a section. The values are NOT copied into the section,
but rather the section knows to look up the missing options in the default section or hash.

Eg.

  if (exists $config->{':default'}) {
    foreach my $section (keys %$config) {
      next if $section =~ /^:/;
      AddDefaults( $config, $section, ':default');
    }
  }

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
