use ExtUtils::MakeMaker;

require 5.008;

eval "use Test::Manifest 1.21";

WriteMakefile(
	'NAME'		    => 'App::Cpan',
	'VERSION_FROM'  => 'lib/App/Cpan.pm',
	'ABSTRACT'      => 'Interact with CPAN from the command line',
	'LICENSE'       => 'perl',
	'AUTHOR'        => 'brian d foy <bdfoy@cpan.org>',

	'EXE_FILES' =>  [ 'script/cpan' ],
	 
	'META_MERGE'    => {
		no_index => {
			directory => [qw(t inc examples)],
			}
		},
		
	'PREREQ_PM' => {
		'Test::More' => '0',
		'CPAN'       => '1.9301',
		},

	clean => { FILES => '*.bak App-* cpan-* cover_db' },
	);
