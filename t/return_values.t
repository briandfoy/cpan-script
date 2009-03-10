#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 10;

use File::Spec::Functions qw(catfile devnull);

my $command     = catfile qw( blib script cpan );
my $config_file = catfile qw( t lib CPAN Config.pm );

# Ensure the script is there and ready to run
ok( -e $command, "$command is there" ) || 
	BAIL_OUT( "Can't continue without script" );
ok( ! system( $^X, '-Mblib', '-c', $command ), "$command compiles" ) ||
		BAIL_OUT( "Can't continue if script won't compile" );

# Ensure the configuration file is there and ready to run
ok( -e $config_file, "Config file exists" );
ok( ! system( $^X, '-c', $config_file ), "Config file compiles" );

# Some options for all commands to load our test config
my @config = ( '-j', $config_file );

my @trials = (
	[ 0, [ '-J'                     ] ],
	[ 1, [ 'Local::Prereq::Fails'   ] ],
	[ 1, [ 'Local::Make::Fails'     ] ],
	[ 1, [ 'Local::Test::Fails'     ] ],
	[ 1, [ 'Local::Unsupported::OS' ] ],
	[ 0, [ 'Local::Works::Fine'     ] ],
	);

diag( <<"HERE" );

=================================================================
You're going to see a mess of output. This is normal and it comes
from the external process I am testing. I'm intentionally trying
to install modules that will fail.
=================================================================


HERE

foreach my $trial ( @trials )
	{
	my( $expected_exit_value, $options ) = @$trial;
	
	my $rc = do {
		local *STDERR;
		open STDERR, ">", devnull();
		system $^X, '-Mblib', $command, @config, @$options;
		};
		
	my $exit_value = $rc >> 8;
	
	is( $exit_value, $expected_exit_value, "$command @config @$options" );
	}
