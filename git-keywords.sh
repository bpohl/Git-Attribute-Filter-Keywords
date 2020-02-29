#!/bin/bash
# $Id:        Can't use these keywords without messing$
# $Revision:    up the regexs in the script itself    $
#
# Translate keywords from sensable versioning systems using filters.
#   The bash handles the parallel stream for diff debug output.  The
#   perl does the file editing with its regex.
#
# Write a file called .gitattributes in the root of the worktree cantaining
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
  GIT_KEYWORD_BEFORE_PIPE=/dev/null
  GIT_KEYWORD_AFTER_PIPE=/dev/null
fi

# Split STDIN to the before diff and the perl processor, and split the
#   perl STDOUT to the after diff
tee "$GIT_KEYWORD_BEFORE_PIPE" | perl -x "$0" "$1" "$2" \
                                        | tee "$GIT_KEYWORD_AFTER_PIPE"

exit 0



##########################################
##
## Use perl to do the in-line processing
##
#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;


######################
## Configuration Constants

# Turn on Debug output and suppress normal output
use constant DEBUG       => 01;

# Map of keywords that corisponds to formatted output from 'git log'
use constant GIT_LOG_MAP => { Author       => "%an",
                              CommitAuthor => "%cn",
                              CommitEmail  => "%ce",
                              CommitDate   => "%cd",
                              Date         => "%ad",
                              Email        => "%ae",
                              CommitNote   => "%s"   };

# List of keywords to be removed entirely
use constant OBSOLETE_LIST => qw( Locker 
                                  RCSfile 
                                  Source 
                                  State   ); 


######################
## Functions to do additional data lookups

# Function that goes a long way to get the branches that the committed
#   blob belongs to
sub getbranch {
    my ($blobid, $filename) = @_;
    my $getbranch_script = <<'GETBRANCH_SCRIPT';
        git log --pretty=format:'%T %H' | \
          while IFS=' ' read tree commit; do 
            git ls-tree -r $tree | awk '{print $0, "'$commit'"}'
          done | sort
GETBRANCH_SCRIPT
                                              
    warn Dumper [ qx/$getbranch_script/ ];

#    my %filess = map { m/^\s*([[:xdigit]]{40})\s+
#                             ([[:alpha:]]+?\s+
#
#  blob\s+(.+?)\s+(.+)\s+(\S+)\s*$/i;
#                      $2, $4, $3, $4 } qx/$getbranch_script/;

    
    my %files = map { m/^\s*(.+?)\s+blob\s+(.+?)\s+(.+)\s+(\S+)\s*$/i;
                      $2, $4, $3, $4 } qx/$getbranch_script/;
    &DEBUG && warn "\$getbranch_script = $getbranch_script\n", Dumper \%files;

    my $commit = $files{$blobid}||$files{$filename};
    my @branches = split("\n", qx/git name-rev --name-only $commit/);
    &DEBUG && warn "\$commit = $commit\n", Dumper \@branches;
    return wantarray ? @branches : $branches[0];
}


######################
## Read and verify the entire blob

# Save off the mode command (smudge|clean) and file name
my $cmd = lc(shift);       
my $filename = shift;       

# Slurp the whole file into a string variable
$_ = do{local $/; <>;};

# Find the file blob's SHA1 Id
my ($blobid) = m/\$Id:?\s*([[:xdigit:]]{40})\s*\$/i;
unless($blobid){
    warn "Id not found";
}


######################
## Construct a hash of keywords and their values

# Start the hash
my %attribs = ( Describe => qx/git describe --all/,
                Id       => $blobid                 );

# Assemble the 'git log' call and map the results to hash keys
my $git_log_cmd = sprintf('git log --pretty=format:"%s" -1',
                          join('%n',
                               map(&GIT_LOG_MAP->{$_},
                                   my @logmap = keys( %{&GIT_LOG_MAP} ))));
@attribs{ @logmap } = split("\n", qx/$git_log_cmd/);

# Set additional keyword values
$attribs{'Branch'}   = getbranch($blobid, $filename);
$attribs{'Revision'} = sprintf( "%s on branch %s",
                                $attribs{'Date'}||'unknown',
                                $attribs{'Branch'}||'unknown' );

# Clean uf the ends of everything in the hash
%attribs = map {chomp; $_;} %attribs;

# Debug output
&DEBUG && warn Dumper \%attribs;


######################
## Apply the regexs to the data

# Do smudge if asked, otherwise do the clean action
if($cmd eq "smudge"){
   
    # Remove now meaningless keywords
    foreach my $regex ( map { qr(\$$_:?.*?\$) } &OBSOLETE_LIST ){
        s/^\#\s*?$regex\s*\n$//gim;
        s/$regex\s*?(\b|$)//gim;
    }

    # If not a SHA1 then change $Id$ into $Revision$
    #s/\$Id(:?\s+\b(?![[:xdigit:]]{40}).{1,40}.*?)?\$/\$Revision\$/gim;
        

    # Fill in new Git filter keywords
    foreach my $keyword ( keys(%attribs) ){
        &DEBUG && warn "s/\$$keyword\$/\$$keyword: $attribs{$keyword}\$/;\n";
        s/\$$keyword:?.*?\$/\$$keyword: $attribs{$keyword}\$/gim;
    }
    
}else{

    # Clear all the keywords
    foreach my $keyword ( keys(%attribs) ){
        &DEBUG && warn "s/\$$keyword:?.*?\$/\$$keyword\$/;\n";
        s/\$$keyword:?.*?\$/\$$keyword\$/gim;
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

=item $Describe$

=item $Email$

=item $CommitNote$

=back

=cut
