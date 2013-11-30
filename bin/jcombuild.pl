#!/usr/bin/perl -w
use strict;
use warnings;

use Archive::Zip;
use File::Copy::Recursive qw(fcopy dircopy);
use File::Path qw(rmtree);
use File::Slurp qw(read_file append_file);
use Getopt::Long qw(:config no_ignore_case );
use TryCatch;
use Config::Tiny;


# set defaults
my %ARG;
$ARG{ini} = 'dist.ini';

# process command line options
GetOptions( \%ARG, 'help|h', 'ini|i=s', 'out|o=s', 'verbose|v' );

# check that ini file was specified
if ( ! $ARG{ini} || ! -f  $ARG{ini} ) {
    print "Could not find dist.ini\n";
    die;
}

# load ini file
my $cfg = Config::Tiny->new->read( $ARG{ini} );

use Data::Dumper;

print Dumper $cfg->{'_'};

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
my @sources = glob('*');

for my $source ( @sources ) {
    
    # exclude directories starting with . (.git) or _ (_overwrite)
    next if $source =~ /^\.|_/;
    next if $source =~ /.ini/;
    
    # perform recursive copy
    if ( -e $source ) {
       rcopy( $source, $tmpdir . '/' . $source ) or die "Could not copy file $source\n";
    }
    
}

# copy _overwrite folder into temporary directory
if ( -d '_overwrite' ) {
    rcopy( '_overwwrite', $tmpdir );
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
    
    # delete _fork folders
    if (-d "$_/_fork" ) {
        rmtree( "$_/_fork" ) or warn "Could not delete _fork folder\n";
    }
    
}

# TODO: copy tempalate files from _fork directory to primary directory to decrease size of zrchive file


# change into the parent directory 
my $zip = Archive::Zip->new;

$zip->addDirecory( $tmpdir );

$zip->writeToFileNamed( $ARG{out} || '../' . $tmpdir . '.zip' );

rmtree($tmpdir);







