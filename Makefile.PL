# $Id$
use ExtUtils::MakeMaker;

sub ExtUtils::MM_Any::test_via_harness
	{
    my($self, $perl, $tests) = @_;

    return qq|\t$perl "-MTest::Manifest" | .
           qq|"-e" "run_t_manifest(\$(TEST_VERBOSE), '\$(INST_LIB)', | .
           qq|'\$(INST_ARCHLIB)')"\n|;
	}

WriteMakefile(
    'NAME'		    => 'cpan',
	'VERSION'       => '1.3',
	
	'EXE_FILES' =>  [ 'cpan' ],
	    	
	'PREREQ_PM' => {
		'File::Find::Rule'  => '0',
		'Test::Manifest'    => '0.91',
		'Test::More'        => '0',
		'Test::Pod'         => '0.90',
		},

	'MAN1PODS' => {
		'cpan' => '$(INST_MAN1DIR)/cpan.1',
		},
		
	clean => { FILES => '*.bak cpan-*' },
	);
