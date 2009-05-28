use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Config::IniHash',
    license             => 'perl',
    dist_author         => 'Jenda Krynicky <Jenda@Krynicky.cz>',
    dist_version_from   => 'lib/Config/IniHash.pm',
    build_requires => {
		'Hash::Case'	=> '0', # or a minimum workable version
		'Hash::WithDefaults' => '0.04',
    },
    add_to_cleanup      => [ 'Config-IniHash-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
