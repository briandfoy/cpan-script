# $Id$
use ExtUtils::MakeMaker;

require 5.006;

eval "use Test::Manifest 1.14";

WriteMakefile(
    'NAME'		    => 'App::Cpan',
	'VERSION_FROM'  => 'lib/Cpan.pm',
	'ABSTRACT'      => 'Interact with CPAN from the command line',
	'LICENSE'       => 'perl',
	'AUTHOR'        => 'brian d foy <bdfoy@cpan.org>',

	'EXE_FILES' =>  [ 'script/cpan' ],
	 
	'PM'           => {
		'lib/Cpan.pm'     => '$(INST_LIBDIR)/Cpan.pm',
		},
		
	'PREREQ_PM' => {
		'Test::More'  => '0',
		'CPAN'        => '0',
		},
		

	'MAN1PODS'     => {},
	'MAN3PODS'     => {},

	clean => { FILES => '*.bak App-* cpan-*' },
	);
