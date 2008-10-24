package App::Cpan;
use strict;
use warnings;
use vars qw($VERSION);

$VERSION = '1.55_02';

=head1 NAME

App::Cpan - easily interact with CPAN from the command line

=head1 SYNOPSIS

	# with arguments and no switches, installs specified modules
	cpan module_name [ module_name ... ]

	# with switches, installs modules with extra behavior
	cpan [-cfimt] module_name [ module_name ... ]

	# with just the dot, install from the distribution in the
	# current directory
	cpan .
	
	# without arguments, starts CPAN.pm shell
	cpan

	# without arguments, but some switches
	cpan [-ahrvACDLO]

=head1 DESCRIPTION

This script provides a command interface (not a shell) to CPAN. At the
moment it uses CPAN.pm to do the work, but it is not a one-shot command
runner for CPAN.pm.

=head2 Meta Options

These options are mutually exclusive, and the script processes them in
this order: [hvCAar].  Once the script finds one, it ignores the others,
and then exits after it finishes the task.  The script ignores any other
command line options.

=over 4

=item -a

Creates the CPAN.pm autobundle with CPAN::Shell->autobundle.

=item -A module [ module ... ]

Shows the primary maintainers for the specified modules

=item -C module [ module ... ]

Show the C<Changes> files for the specified modules

=item -D module [ module ... ]

Show the module details. This prints one line for each out-of-date module
(meaning, modules locally installed but have newer versions on CPAN).
Each line has three columns: module name, local version, and CPAN
version.

=item -j Config.pm

Load the file that has the CPAN configuration data. This should have the
same format as the standard F<CPAN/Config.pm> file, which defines 
C<$CPAN::Config> as an anonymous hash.

=item -J

Dump the configuration in the same format that CPAN.pm uses.

=item -L author [ author ... ]

List the modules by the specified authors.

=item -h

Prints a help message.

=item -O

Show the out-of-date modules.

=item -r

Recompiles dynamically loaded modules with CPAN::Shell->recompile.

=item -v

Print the script version and CPAN.pm version.

=back

=head2 Module options

These options are mutually exclusive, and the script processes them in
alphabetical order. It only processes the first one it finds.

=over 4

=item c

Runs a `make clean` in the specified module's directories.

=item f

Forces the specified action, when it normally would have failed.

=item i

Installed the specified modules.

=item m

Makes the specified modules.

=item t

Runs a `make test` on the specified modules.

=back

=head2 Examples

	# print a help message
	cpan -h

	# print the version numbers
	cpan -v

	# create an autobundle
	cpan -a

	# recompile modules
	cpan -r

	# install modules ( sole -i is optional )
	cpan -i Netscape::Booksmarks Business::ISBN

	# force install modules ( must use -i )
	cpan -fi CGI::Minimal URI


=head2 Methods

=over 4

=cut

use CPAN ();
use File::Spec;
use Getopt::Std;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# set up the order of options that we layer over CPAN::Shell
BEGIN { # most of this should be in methods
use vars qw( @META_OPTIONS $Default %CPAN_METHODS @CPAN_OPTIONS  @option_order
	%Method_table %Method_table_index );
	
@META_OPTIONS = qw( h v C A D O l L a r j: J );

$Default = 'default';

%CPAN_METHODS = ( # map switches to method names in CPAN::Shell
	$Default => 'install',
	'c'      => 'clean',
	'f'      => 'force',
	'i'      => 'install',
	'm'      => 'make',
	't'      => 'test',
	);
@CPAN_OPTIONS = grep { $_ ne $Default } sort keys %CPAN_METHODS;

@option_order = ( @META_OPTIONS, @CPAN_OPTIONS );


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# map switches to the subroutines in this script, along with other information.
# use this stuff instead of hard-coded indices and values
%Method_table = (
# key => [ sub ref, takes args?, exit value, description ]
	h =>  [ \&_print_help,        0, 0, 'Printing help'                ],
	v =>  [ \&_print_version,     0, 0, 'Printing version'             ],

	j =>  [ \&_load_config,       1, 0, 'Use specified config file'    ],
	J =>  [ \&_dump_config,       0, 0, 'Dump configuration to stdout' ],
	
	C =>  [ \&_show_Changes,      1, 0, 'Showing Changes file'         ],
	A =>  [ \&_show_Author,       1, 0, 'Showing Author'               ],
	D =>  [ \&_show_Details,      1, 0, 'Showing Details'              ],
	O =>  [ \&_show_out_of_date,  0, 0, 'Showing Out of date'          ],

	l =>  [ \&_list_all_mods,     0, 0, 'Listing all modules'          ],

	L =>  [ \&_show_author_mods,  1, 0, 'Showing author mods'          ],
	a =>  [ \&_create_autobundle, 0, 0, 'Creating autobundle'          ],
	r =>  [ \&_recompile,         0, 0, 'Recompiling'                  ],

	c =>  [ \&_default,           1, 0, 'Running `make clean`'         ],
	f =>  [ \&_default,           1, 0, 'Installing with force'        ],
	i =>  [ \&_default,           1, 0, 'Running `make install`'       ],
   'm' => [ \&_default,           1, 0, 'Running `make`'               ],
	t =>  [ \&_default,           1, 0, 'Running `make test`'          ],

	);

%Method_table_index = (
	code        => 0,
	takes_args  => 1,
	exit_value  => 2,
	description => 3,
	);
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# finally, do some argument processing

sub _stupid_interface_hack_for_non_rtfmers
	{
	no warnings 'uninitialized';
	shift @ARGV if( $ARGV[0] eq 'install' and @ARGV > 1 )
	}
	
sub _process_options
	{
	my %options;
	
	# if no arguments, just drop into the shell
	if( 0 == @ARGV ) { CPAN::shell(); exit 0 }
	else
		{
		Getopt::Std::getopts(
		  join( '', @option_order ), \%options );    
		 \%options;
		}
	}

sub _process_setup_options
	{
	my( $class, $options ) = @_;
	
	if( $options->{j} )
		{
		$Method_table{j}[ $Method_table_index{code} ]->( $options->{j} );
		delete $options->{j};
		}
	else
		{
		# this is what CPAN.pm would do otherwise
		CPAN::HandleConfig->load(
			be_silent  => 1,
			write_file => 0,
			);
		}
		
	my $option_count = grep { $options->{$_} } @option_order;
	no warnings 'uninitialized';
	$option_count -= $options->{'f'}; # don't count force
	
	$options->{i}++ unless $option_count;
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# if there are no options, set -i (this line fixes RT ticket 16915)



=item run()

Just do it

=cut

sub run
	{
	my $class = shift;
	
	$class->_stupid_interface_hack_for_non_rtfmers;
	
	my $options = $class->_process_options;
	
	$class->_process_setup_options( $options );
	
	foreach my $option ( @option_order )
		{	
		next unless $options->{$option};
		die unless 
			ref $Method_table{$option}[ $Method_table_index{code} ] eq ref sub {};
		
#		print "$Method_table{$option}[ $Method_table_index{description} ] " .
#			"-- ignoring other opitions\n" if $option_count > 1;
		print "$Method_table{$option}[ $Method_table_index{description} ] " .
			"-- ignoring other arguments\n" 
			if( @ARGV && ! $Method_table{$option}[ $Method_table_index{takes_args} ] );
			
		$Method_table{$option}[ $Method_table_index{code} ]->( \ @ARGV, $options );
		
		last;
		}
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

sub _default
	{
	my( $args, $options ) = @_;
	
	my $switch = '';

	# choose the option that we're going to use
	# we'll deal with 'f' (force) later, so skip it
	foreach my $option ( @CPAN_OPTIONS )
		{
		next if $option eq 'f';
		next unless $options->{$option};
		$switch = $option;
		last;
		}

	# 1. with no switches, but arguments, use the default switch (install)
	# 2. with no switches and no args, start the shell
	# 3. With a switch but no args, die! These switches need arguments.
	   if( not $switch and     @$args ) { $switch = $Default;     }
	elsif( not $switch and not @$args ) { CPAN::shell(); return   }
	elsif(     $switch and not @$args )
		{ die "Nothing to $CPAN_METHODS{$switch}!\n"; }

	# Get and cheeck the method from CPAN::Shell
	my $method = $CPAN_METHODS{$switch};
	die "CPAN.pm cannot $method!\n" unless CPAN::Shell->can( $method );

	# call the CPAN::Shell method, with force if specified
	foreach my $arg ( @$args )
		{
		if( $options->{f} ) { CPAN::Shell->force( $method, $arg ) }
		else                 { CPAN::Shell->$method( $arg )        }
		}

	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
sub _print_help
	{
	print STDERR "Use perldoc to read the documentation\n";
	exec "perldoc $0";
	}
	
sub _print_version
	{
	print STDERR "$0 script version $VERSION, CPAN.pm version " . 
		CPAN->VERSION . "\n";
	}
	
sub _create_autobundle
	{
	print "Creating autobundle in ", $CPAN::Config->{cpan_home},
		"/Bundle\n";

	CPAN::Shell->autobundle;
	}

sub _recompiling
	{
	print "Recompiling dynamically-loaded extensions\n";

	CPAN::Shell->recompile;
	}

sub _load_config
	{	
	my $file = shift || '';
	
	# should I clear out any existing config here?
	$CPAN::Config = {};
	delete $INC{'CPAN/Config.pm'};
	die( "Config file [$file] does not exist!\n" ) unless -e $file;
	
	my $rc = eval "require '$file'";

	# CPAN::HandleConfig::require_myconfig_or_config looks for this
	$INC{'CPAN/MyConfig.pm'} = 'fake out!';
	
	# CPAN::HandleConfig::load looks for this
	$CPAN::Config_loaded = 'fake out';
	
	die( "Could not load [$file]: $@\n") unless $rc;
	
	return 1;
	}

sub _dump_config
	{
	my $args = shift;
	use Data::Dumper;
	
	my $fh = $args->[0] || \*STDOUT;
		
	my $dd = Data::Dumper->new( 
		[$CPAN::Config], 
		['$CPAN::Config'] 
		);
		
	print $fh $dd->Dump, "\n1;\n__END__\n";
	
	return 1;
	}
	
sub _show_Changes
	{
	my $args = shift;
	
	foreach my $arg ( @$args )
		{
		print "Checking $arg\n";
		my $module = CPAN::Shell->expand( "Module", $arg );
		
		next unless $module->inst_file;
		#next if $module->uptodate;
	
		( my $id = $module->id() ) =~ s/::/\-/;
	
		my $url = "http://search.cpan.org/~" . lc( $module->userid ) . "/" .
			$id . "-" . $module->cpan_version() . "/";
	
		#print "URL: $url\n";
		_get_changes_file($url);
		}
	}	
	
sub _get_changes_file
	{
	die "Reading Changes files requires LWP::Simple and URI\n"
		unless eval { require LWP::Simple; require URI; };
	
    my $url = shift;

    my $content = LWP::Simple::get( $url );
    print "Got $url ...\n" if defined $content;
	#print $content;
	
	my( $change_link ) = $content =~ m|<a href="(.*?)">Changes</a>|gi;
	
	my $changes_url = URI->new_abs( $change_link, $url );
 	#print "change link is: $changes_url\n";
	my $changes =  LWP::Simple::get( $changes_url );
	#print "change text is: " . $change_link->text() . "\n";
	print $changes;
	}
	
sub _show_Author
	{
	my $args = shift;
	
	foreach my $arg ( @$args )
		{
		my $module = CPAN::Shell->expand( "Module", $arg );
		my $author = CPAN::Shell->expand( "Author", $module->userid );
	
		next unless $module->userid;
	
		printf "%-25s %-8s %-25s %s\n", 
			$arg, $module->userid, $author->email, $author->fullname;
		}
	}	

sub _show_Details
	{
	my $args = shift;
	
	foreach my $arg ( @$args )
		{
		my $module = CPAN::Shell->expand( "Module", $arg );
		my $author = CPAN::Shell->expand( "Author", $module->userid );
	
		next unless $module->userid;
	
		print "$arg\n", "-" x 73, "\n\t";
		print join "\n\t",
			$module->description ? $module->description : "(no description)",
			$module->cpan_file,
			$module->inst_file,
			'Installed: ' . $module->inst_version,
			'CPAN:      ' . $module->cpan_version . '  ' .
				($module->uptodate ? "" : "Not ") . "up to date",
			$author->fullname . " (" . $module->userid . ")",
			$author->email;
		print "\n\n";
		
		}
	}	

sub _show_out_of_date
	{
	my @modules = CPAN::Shell->expand( "Module", "/./" );
		
	printf "%-40s  %6s  %6s\n", "Module Name", "Local", "CPAN";
	print "-" x 73, "\n";
	
	foreach my $module ( @modules )
		{
		next unless $module->inst_file;
		next if $module->uptodate;
		printf "%-40s  %.4f  %.4f\n",
			$module->id, 
			$module->inst_version ? $module->inst_version : '', 
			$module->cpan_version;
		}

	}

sub _show_author_mods
	{
	my $args = shift;

	my %hash = map { lc $_, 1 } @$args;
	
	my @modules = CPAN::Shell->expand( "Module", "/./" );
	
	foreach my $module ( @modules )
		{
		next unless exists $hash{ lc $module->userid };
		print $module->id, "\n";
		}
	
	}
	
sub _list_all_mods
	{
	require File::Find;
	
	my $args = shift;
	
	my( $wanted, $reporter ) = _generator();
	
	my $fh = \*STDOUT;
	
	foreach my $inc ( @INC )
		{		
		File::Find::find( { wanted => $wanted }, $inc );
		
		my $count = 0;
		foreach my $file ( @{ $reporter->() } )
			{
			my $version = _parse_version_safely( $file );
			
			my $module_name = _path_to_module( $inc, $file );
			
			print $fh "$module_name\t$version\n";
			
			#last if $count++ > 5;
			}
		}
	}
	
sub _generator
	{			
	my @files = ();
	
	sub { push @files, 
		File::Spec->canonpath( $File::Find::name ) 
		if m/\A\w+\.pm\z/ },
	sub { \@files },
	}
	
sub _parse_version_safely # stolen from PAUSE's mldistwatch, but refactored
	{
	my( $file ) = @_;
	
	local $/ = "\n";
	local $_; # don't mess with the $_ in the map calling this
	
	return unless open FILE, "<$file";

	my $in_pod = 0;
	my $version;
	while( <FILE> ) 
		{
		chomp;
		$in_pod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $in_pod;
		next if $in_pod || /^\s*#/;

		next unless /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/;
		my( $sigil, $var ) = ( $1, $2 );
		
		$version = _eval_version( $_, $sigil, $var );
		last;
		}
	close FILE;

	return 'undef' unless defined $version;
	
	return $version;
	}

sub _eval_version
	{
	my( $line, $sigil, $var ) = @_;
	
	my $eval = qq{ 
		package ExtUtils::MakeMaker::_version;

		local $sigil$var;
		\$$var=undef; do {
			$line
			}; \$$var
		};
		
	my $version = do {
		local $^W = 0;
		no strict;
		eval( $eval );
		};

	return $version;
	}

=item path_to_module( INC_DIR, PATH )

Turn a C<PATH> into a Perl module name, ignoring the C<@INC> directory
specified in C<INC_DIR>.
	
=cut

sub _path_to_module
	{
	my( $inc, $path ) = @_;
	
	my $module_path = substr( $path, length $inc );
	$module_path =~ s/\.pm\z//;
	
	# XXX: this is cheating and doesn't handle everything right
	my @dirs = grep { ! /\W/ } File::Spec->splitdir( $module_path );
	shift @dirs;
	
	my $module_name = join "::", @dirs;
	
	return $module_name;
	}
1;

=back

=head1 TO DO

=head1 BUGS

* none noted

=head1 SEE ALSO

Most behaviour, including environment variables and configuration,
comes directly from CPAN.pm.

=head1 SOURCE AVAILABILITY

This code is in Github:

	git://github.com/briandfoy/cpan_script.git

=head1 CREDITS

Japheth Cleaver added the bits to allow a forced install (-f).

Jim Brandt suggest and provided the initial implementation for the
up-to-date and Changes features.

Adam Kennedy pointed out that exit() causes problems on Windows
where this script ends up with a .bat extension

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2001-2008, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut
