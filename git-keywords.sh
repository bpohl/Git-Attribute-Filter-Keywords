#!/bin/bash
# $Id:        Can't use these keywords without messing$
# $Revision:    up the regexs in the script itself    $
#
# Translate keywords from sensible versioning systems using filters.
#   The bash handles the parallel stream for diff debug output.  The
#   perl does the file editing with its regex.
#
# Write a file called .gitattributes in the root of the worktree containing
#
#    *  filter=keyword
#
# Then map 'keyword' to the script with 'git config'
#
#    git config --worktree filter.keyword.smudge ./git-keyword.sh smudge %f
#    git config --worktree filter.keyword.clean  ./git-keyword.sh clean  %f
#

# Set some defaults
scriptname="$(basename "$0")"
: ${GIT_KEYWORD_TMP:="/tmp/${scriptname%%.*}"}
: ${GIT_KEYWORD_BEFORE_PIPE:="${GIT_KEYWORD_TMP}.before"}
: ${GIT_KEYWORD_AFTER_PIPE:="${GIT_KEYWORD_TMP}.after"}
: ${GIT_KEYWORD_DIFF:="${GIT_KEYWORD_TMP}.diff"}

# Check for the right perl
if perl -e "use 5.20.0"; then

  # If given the -d for diff flag then set up for it
  if [ "$1" == "-d" ]; then
    shift
    # Set up pipes and do a before-to-after diff
    function dodiff () {
      [ -p "$GIT_KEYWORD_BEFORE_PIPE" ] || mkfifo "$GIT_KEYWORD_BEFORE_PIPE"
      [ -p "$GIT_KEYWORD_AFTER_PIPE" ] || mkfifo "$GIT_KEYWORD_AFTER_PIPE"
      echo "### $@ $(pwd) $(date)" >> "$GIT_KEYWORD_DIFF"
      diff "$GIT_KEYWORD_BEFORE_PIPE" "$GIT_KEYWORD_AFTER_PIPE" \
                                                >> "$GIT_KEYWORD_DIFF" &
    }
    # Start the b2a diff process
    dodiff "$@"
  else
    # Send the tee pipes to nowhere if not diffing
    GIT_KEYWORD_BEFORE_PIPE=/dev/null
    GIT_KEYWORD_AFTER_PIPE=/dev/null
  fi

  # Split STDIN to the before diff and the perl processor, and split the
  #   perl STDOUT to the after diff
  tee "$GIT_KEYWORD_BEFORE_PIPE" | perl -x "$0" "$1" "$2" \
                                        | tee "$GIT_KEYWORD_AFTER_PIPE"
else
  # If not perl then just pass-through
  echo <<"EOS" >&2
Error: Perl 5.20 or later not found. Continuing in pass-through mode.
EOS
  cat
fi

exit 0



##########################################
##
## Use perl to do the in-line processing
##
#!/usr/bin/perl
use 5.20.0;
use strict;
use warnings;


######################
## Configuration Constants

# Turn on Debug output and suppress normal output
use constant DEBUG => 0;

# Map of keywords that corresponds to formatted output from 'git log'
use constant GIT_LOG_MAP => { Author       => "%an",
                              CommitAuthor => "%cn",
                              CommitDate   => "%cd",
                              CommitEmail  => "%ce",
                              CommitNote   => "%s" ,
                              Date         => "%ad",
                              Email        => "%ae"  };

# List of keywords to be removed entirely
use constant OBSOLETE_LIST => qw( Locker 
                                  State   ); 

# An abbreviation of the SHA1 regex
#   Syntax: ${\(SHA1)}
use constant SHA1 => qr/([[:xdigit:]]{40})/i;

# Not available string
use constant NA   => "N/A";
    

######################
## Functions to do additional data look-ups

# Function that goes a long way to get the branches that the committed
#   blob belongs to
sub getcommit {
    my ($blobid) = @_;
    $blobid || return undef;
    
    # Loop over all the log entries
    foreach( qx{git log --all --pretty=format:'%H %T'} ){
        my ( $commit, $tree ) = ( m/^${\(SHA1)}\s   # commit
                                     ${\(SHA1)}\s   # tree   /x );
        &DEBUG &&
            warn sprintf( "\$blobid = %s\n\$commit = %s\n\$tree   = %s\n",
                          $blobid, $commit||&NA, $tree||&NA                );   
                            
        $tree || next; # Without $tree the rest doesn't work
                       
        # Search in each tree for the file with $blobid
        &DEBUG && warn Data::Dumper->Dump( [[ qx{git ls-tree -r $tree} ]],
                                           ['tree']                        );
        my $filename;
        foreach( qx{git ls-tree -r $tree} ){
            # Once we have a commit the job is done so return it
            return ($commit, $filename)
                if( ($filename) = m/^\d+?\sblob\s$blobid\s(.+?)\s*$/i );
        }
    }

    # If we make it here then the file wasn't found and there's nothing
    #   to do about it
    return undef;
}


# Look up the name of the commit
sub getbranches {
    my ($commit) = @_;
    my @branches = map {m%^.*/(.*?)\^\{\}\s*$%; $1;}
                       qx{git branch --format='%(*refname)' \\
                                     --points-at $commit      };
    &DEBUG && warn Data::Dumper->Dump([[@branches]],['branches']);
    return wantarray ? @branches : $branches[0];
}


# Look up the tags of the commit
sub gettags {
    my ($commit) = @_;
    my @tags = map {$_&&chomp; $_;} qx{git tag --points-at $commit};
    &DEBUG && warn Data::Dumper->Dump([[@tags]],['tags']);
    return wantarray ? @tags : $tags[0];
}


# Construct a hash of keywords and their values
sub getattribs {
    my ($blobid) = @_;
    
    # Start the hash
    my %attribs = ( Id => $blobid||&NA );

    # Assemble the 'git log' call and map the results to hash keys
    my $git_log_cmd = sprintf('git log --pretty=format:"%s" -1',
                              join('%n',
                                   map(&GIT_LOG_MAP->{$_},
                                       my @logmap = keys( %{&GIT_LOG_MAP} ))));
    @attribs{ @logmap } = split("\n", qx{$git_log_cmd});

    # If we can find a commit for the file then get its data
    @attribs{ qw( Branch Commit Tags RCSfile Source ) } = (&NA)x5;
    if((my ($commit, $tree_filename) = getcommit($blobid))[0]){
        &DEBUG && warn "Commit selected     = $commit\n",
                       "File name from tree = $tree_filename\n";
        $attribs{'Commit'} = $commit||&NA;
        $attribs{'Branch'} = getbranches($commit)||&NA;
        $attribs{'Tags'}   = join(', ', gettags($commit))||'none';
        @attribs{ qw( RCSfile Source ) } = ($tree_filename)x2;
    }

    # Set additional keyword values
    $attribs{'RCSfile'} =~ s%^.*/(.+?)$%$1%;
    $attribs{'Revision'} = sprintf( "%s on branch %s",
                                    $attribs{'Date'}  ||&NA,
                                    $attribs{'Branch'}||&NA  );

    # Clean up the ends of everything in the hash
    %attribs = map {$_&&chomp; $_;} %attribs;

    # Send it back
    &DEBUG && warn  Data::Dumper->Dump([\%attribs],['attribs']);
    return \%attribs
}


######################
## Read and verify the entire blob

# Save off the mode command (smudge|clean) and file name
#   Nothing should remain so STDIN is opened for reading
my ($cmd, $filename) = @ARGV;       
@ARGV = ();

# Slurp the whole file into a string variable
$_ = do{local $/; <>;};


######################
## Apply the regexs to the data

# Load Data::Dumper if DEBUGging
&DEBUG && eval "use Data::Dumper;";

# Do smudge if asked, otherwise do the clean action
if(lc($cmd) eq "smudge"){

    # Find the file blob's SHA1 Id
    my ($blobid) = m/\$Id:?\s*${\(SHA1)}\s*\$/i;
    warn <<"EOS" unless($blobid);
Warning: '\$Id\$' not found in '$filename', some keywords may not be filled.
EOS
    
    # Since I frequently used $Source$, change it to $Revision$
    #s/\$Source:?.*?\$/\$Revision\$/gim;

    # Remove now meaningless keywords
    foreach my $regex ( map { qr(\$$_:?.*?\$) } &OBSOLETE_LIST ){
        s/^\s*\#+\s*?$regex\s*\n$//gim;
        s/$regex\s*?(\b|$)//gim;
    }

    # Do the look-ups for the keyword values
    my $attribs = getattribs($blobid, $filename);
    
    # Fill in new Git filter keywords
    foreach my $keyword ( sort keys(%$attribs) ){
        s/(\$$keyword(?::.*?)?\s*\$)/\$$keyword: $attribs->{$keyword}\$/gim &&
            &DEBUG && warn sprintf("%s => \$%s: %s\$\n", $1||'', $keyword,
                                                     $attribs->{$keyword});
    }
    
}else{

    # Get the attribute list but there is no $Id$ anyway
    #   so don't do the extra look-ups
    my $attribs = getattribs(undef);

    # Clear all the keywords
    foreach my $keyword ( sort keys(%$attribs) ){
        s/(\$$keyword(?::.*?)?\s*\$)/\$$keyword\$/gim &&
            &DEBUG && warn sprintf("%s => \$%s\$\n", $1||'', $keyword);
    }
}

# Print the results
print;
exit 0;
