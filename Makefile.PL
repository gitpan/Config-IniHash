use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Config::IniHash',
    'VERSION_FROM'	=> 'IniHash.pm', # finds $VERSION
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'IniHash.pm', # retrieve abstract from module
       AUTHOR     => 'Jenda Krynicky (Jenda@Krynicky.cz)') : ()),
	PREREQ_PM   => {
	'Hash::Case'	=> '0', # or a minimum workable version
	'Hash::WithDefaults' => '0.04',
	'IO::Scalar' => 0,
    },
);
