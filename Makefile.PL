# $Id$
use ExtUtils::MakeMaker;

eval "use Test::Manifest 1.14";

WriteMakefile(
    'NAME'		    => 'cpan-script',
	'VERSION'       => '1.53',
	
	'EXE_FILES' =>  [ 'cpan' ],
	    	
	'PREREQ_PM' => {
		'Test::More'        => '0',
		},

	'MAN1PODS' => {
		'cpan' => '$(INST_MAN1DIR)/cpan.1',
		},
		
	clean => { FILES => '*.bak cpan-*' },
	);
