use Test::More;
eval "use Test::Pod::Coverage";

if( $@ )
	{
	plan skip_all => "Test::Pod::Coverage required for testing POD";
	}
else
	{
	all_pod_coverage_ok( { also_private => [ qr/^[A-Z_]+$/ ], } );      
	}
