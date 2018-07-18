use ExtUtils::MakeMaker 6.48;

require 5.008;

eval "use Test::Manifest 1.21";

# if you want to install this you have to find and remove this message
# You probably want https://github.com/andk/cpanpm
die "The latest version of App::cpan is in the CPAN.pm distribution: https://github.com/andk/cpanpm";

WriteMakefile(
	'NAME'		    => 'App::Cpan',
	'VERSION_FROM'  => 'lib/App/Cpan.pm',
	'ABSTRACT'      => 'Interact with CPAN from the command line',
	'LICENSE'       => 'artistic_2',
	'AUTHOR'        => 'brian d foy <bdfoy@cpan.org>',

	'EXE_FILES' =>  [ 'script/cpan' ],

	'META_MERGE'    => {
		no_index => {
			directory => [qw(t inc examples)],
			}
		},

	'PREREQ_PM' => {
		'Test::More' => '0.95',
		'CPAN'       => '1.9301',
		},

	clean => { FILES => '*.bak App-* cpan-* cover_db' },
	);
