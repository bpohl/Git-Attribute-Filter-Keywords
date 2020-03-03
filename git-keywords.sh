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
: ${GIT_KEYWORD_TMP:="/tmp/git-keyword"}
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
use constant DEBUG       => 01;

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
        &DEBUG && warn "\$blobid = $blobid\n" .
                       "\$commit = $commit\n" .
                       "\$tree   = $tree\n";

        # Search in each tree for the file with $blobid
        # Once we have a commit the job is done so stop here
        &DEBUG && warn Data::Dumper->Dump([[ qx{git ls-tree -r $tree} ]],
                                          ['tree']                        );
        return $commit  if( grep( m/^\d+?\sblob\s$blobid\s(.+?)\s*$/i,
                                  qx{git ls-tree -r $tree}             ) );
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
    my ($blobid, $filename) = @_;
    
    # Start the hash
    my %attribs = ( Id => $blobid||'unknown' );

    # Assemble the 'git log' call and map the results to hash keys
    my $git_log_cmd = sprintf('git log --pretty=format:"%s" -1',
                              join('%n',
                                   map(&GIT_LOG_MAP->{$_},
                                       my @logmap = keys( %{&GIT_LOG_MAP} ))));
    @attribs{ @logmap } = split("\n", qx{$git_log_cmd});

    # If we can find a commit for the file then get its data
    @attribs{ qw( Branch Commit Tags ) } = ('unknown')x3;
    if(my $commit = getcommit($blobid)){
        &DEBUG && warn "Commit selected = $commit\n";
        $attribs{'Commit'} = $commit||'unknown';
        $attribs{'Branch'} = getbranches($commit)||'unknown';
        $attribs{'Tags'}   = join(', ', gettags($commit))||'none';
    }

    # Set additional keyword values
    @attribs{ qw( RCSfile Source ) } = ($filename)x2;
    $attribs{'RCSfile'} =~ s%^.*/(.+?)$%$1%;
    $attribs{'Revision'} = sprintf( "%s on branch %s",
                                    $attribs{'Date'}  ||'unknown',
                                    $attribs{'Branch'}||'unknown'  );

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
    warn "Warning: '\$Id\$' not found, some keywords will not be filled.\n" .
         "Add a '\$Id\$' keyword to enable all keywords.\n"
        unless($blobid);
    
    # Since I frequently used $Source$, change it to $Revision$
    #s/\$Source:?.*?\$/\$Revision\$/gim;

    # Remove now meaningless keywords
    foreach my $regex ( map { qr(\$$_:?.*?\$) } &OBSOLETE_LIST ){
        s/^\#\s*?$regex\s*\n$//gim;
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
    my $attribs = getattribs(undef, $filename);

    # Clear all the keywords
    foreach my $keyword ( sort keys(%$attribs) ){
        s/(\$$keyword(?::.*?)?\s*\$)/\$$keyword\$/gim &&
            &DEBUG && warn sprintf("%s => \$%s\$\n", $1||'', $keyword);
    }
}

# Print the results
print;
exit 0;

=pod

=head4 RCS Keywords

This is a list of the keywords that RCS currently (in release 5.6.0.1)
supports:

=over

=item $Author$

The login name of the user who checked in the revision.

=item $Date$
    The date and time (UTC) the revision was checked in.

=item $Header$  B<Not Enabled>

A standard header containing the full pathname of the RCS file, the
revision number, the date (UTC), the author, the state, and the locker
(if locked). Files will normally never be locked when you use CVS.

=item $Id$

Same as $Header$, except that the RCS filename is without a path.

=item $Locker$  B<Obsolete: Automaticaly Removed>

The login name of the user who locked the revision (empty if not
locked, and thus almost always useless when you are using CVS).

=item $Log$  B<Not Enabled>

The log message supplied during commit, preceded by a header
containing the RCS filename, the revision number, the author, and the
date (UTC). Existing log messages are not replaced. Instead, the new
log message is inserted after $Log:...$. Each new line is prefixed
with a comment leader which RCS guesses from the file name
extension. It can be changed with cvs admin -c. See section admin
options. This keyword is useful for accumulating a complete change log
in a source file, but for several reasons it can be problematic. See
section Problems with the $Log$ keyword..

=item $RCSfile$  B<Obsolete: Automaticaly Removed>

The name of the RCS file without a path.

=item $Revision$

The revision number assigned to the revision.

=item $Source$  B<Obsolete: Automaticaly Removed>

The full pathname of the RCS file.

=item $State$  B<Obsolete: Automaticaly Removed>

The state assigned to the revision. States can be assigned with cvs
admin -s---See section admin options.

=back

=head4 Additional Keywords

=over

=item $Branch$

=item $CommitAuthor$

=item $CommitDate$

=item $CommitEmail$

=item $Email$

=item $CommitNote$

=item $Commit$

=item $Tags$

=back

=cut
