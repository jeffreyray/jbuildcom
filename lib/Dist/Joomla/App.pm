package Dist::Joomla::App;

use Moose;
use MooseX::StrictConstructor;
use MooseX::SemiAffordanceAccessor;


use Archive::Zip;
use File::Copy::Recursive qw(rcopy);
use File::Find;
use File::Path qw(rmtree);
use File::Slurp qw(read_file append_file);
use Getopt::Long qw(:config no_ignore_case );
use Config::Tiny;




sub run {
    my ( $self ) = @_;
    

    # set defaults
    my %ARG;
    $ARG{ini} = 'dist.ini';
    $ARG{source} = shift @ARGV if $ARGV[0] && $ARGV[0] !~ /$-/;
    $ARG{source} ||= '.';
    $ARG{ext} = 1;
    
    # process command line options
    GetOptions( \%ARG, 'help|h', 'ini|i=s', 'out|o=s', 'verbose|v', 'source|s=s', 'min|m', 'ext'  );
    
    
    # check that ini file was specified
    if ( ! $ARG{ini} || ! -f $ARG{source} . '/' . $ARG{ini} ) {
        print "Could not find dist.ini\n";
        die;
    }
    
    # load ini file
    my $cfg = Config::Tiny->new->read( $ARG{source} . '/' . $ARG{ini} );
    
    
    if ( ! $cfg->{'_'}{name} ) {
        print "Error reading in file. Could not find component name.\n";
        die;
    }
    
    
    # create temporary directory name
    my $tmpdir = $cfg->{'_'}{name};
    $tmpdir .= '-' . $cfg->{'_'}{version} if $cfg->{'_'}{version};
    
    # delete temp folder from failed/previous build
    if ( -d $tmpdir ) {
        rmtree( $tmpdir ) or die "Could not delete $tmpdir from previous build.\n";
    }
    
    # create a temporary directory
    mkdir $tmpdir or die "Could not create temporary directory.\n";
    
    
    # copy files to temporary directory
    my @sources = glob($ARG{source} . '/*');
    
    
    
    for my $source ( @sources ) {
        
        # exclude directories and files starting with . (.git) or _ (_overwrite)
        next if $source =~ /^.*[\\\/](\.|_)[^\\\/]+$/;
        next if $source =~ /^.*[\\\/]$tmpdir(\.zip)?[^\\\/]*$/;
        next if $source =~ /\.komodo.*$/;
        next if $source =~ /.ini$/;
        
        # perform recursive copy
        if ( -e $source ) {
            
            my $target = $source;
            my $source_path = quotemeta(${ARG}{source});
            
            $target =~ s/^$source_path[\\\/]//;
            
           rcopy( $source, $tmpdir . '\\' . $target ) or die "Could not copy file $source.\n$!\n";
        }
        
    }
    
    # copy _overwrite folder into temporary directory
    if ( -d $ARG{source} . '/_overwrite' ) {
        rcopy(  $ARG{source} . '/_overwwrite', $tmpdir );
    }
    
    # change into the temporary directory
    chdir $tmpdir or die "Could not change to temp directory.\n";
    
    for ( 'site', 'admin' ) {
        
        # merge language files
        if (-d "$_/language") {
            my @langfiles = glob("$_/language/*.ini");
            
            for my $source ( @langfiles ) {
                
                if ( -f $source . '-append' ) {
                    
                    # read append text
                    my $append_text = read_file( $source . '-append' );
                    
                    # write to original lang
                    append_file( $source, $append_text );
                    
                    # delete additional lang file
                    unlink $source . '-append';
                }
                
                
            }
        }
        
        # delete _fork folders to decrease archive size
        # this is not the "fork" folder which holds actual forked code, the _fork folder contains unused code provided from J-Cook
        if (-d "$_/_fork" ) {
            rmtree( "$_/_fork" ) or warn "Could not delete _fork folder\n";
        }
        
        # copy tempalate files from fork directory to primary directory to decrease size of archive file
        my $view_dir = "$_/fork/views";
        if ( -d $view_dir ) {
            
            # get a list of all directories in the forked views folder
            my @views = glob( $view_dir . '/*'  );
            
            # for each one, check if there is a tmpl folder
            for my $view ( @views ) {
                
                next if ! -d $view;
                next if ! -d $view . '/tmpl';
                
                
                my $view_name = $view;
                $view_name =~ s/^$view_dir[\\\/]]?//;
                
                print $view_name, "\n";
                
                # copy the tmpl folder and its contents to the non forked views folder
                rcopy( "$view/tmpl", "$_/views/$view_name/tmpl" );
                
                # delete the tmpl folder from the fork directory
                rmtree("$view/tmpl");
                
            }
        }
        
        # if running in min-mode, delete image folders to decrease file size
        if ( $ARG{min}  ) {
            map { -d $_ ? rmtree($_) : unlink $_ } glob ("$_/images/*");
        }
        
        
    }
    
    # if running in minamal mode, remove image folders and "extensions" directory to decrease archive size
    if ( $ARG{min} || $ARG{ext} ) {
        rmtree("extensions");
    }

    
    # change into the parent directory
    chdir '..';
    my $zip = Archive::Zip->new;
    
    $zip->addDirectory($tmpdir);
    
    $zip->addTree( $tmpdir, $tmpdir, undef, 9 );
    
    $zip->writeToFileNamed( $ARG{out} || $tmpdir . '.zip' );
    
    rmtree($tmpdir);

}


1;



__END__

=pod

=head1 NAME

Dist::Joomla::App - Utility for packaging Joomla components created with J-cook

=head1 DESCRIPTION

Utility for packaging Joomla components created with J-cook

=head1 AUTHOR

Jeffrey Ray Hallock E<lt>jeffrey.hallock@gmail.com<gt>

=head1 COPYRIGHT & LICENSE

This software is Copyright (c) 2013 Jeffrey Ray Hallock.

Artistic_2_0
