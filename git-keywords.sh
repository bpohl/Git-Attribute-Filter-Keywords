#!/bin/bash
# $Id$
# $Revision$
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
tee "$GIT_KEYWORD_BEFORE_PIPE" | perl -x "$0" "$1" \
                                           | tee "$GIT_KEYWORD_AFTER_PIPE"

exit 0

##
## Use perl to do the in-line processing
##
#!/usr/bin/perl -p
use strict;
use warnings;
#use Data::Dumper;

# Fill some variables whos value doesn't change over the whole
#   file being processed
our %attribs;
our @obsolete;
BEGIN{

    %attribs = ( cmd      => shift,
                 branch   => qx/git rev-parse --abbrev-ref HEAD/,
                 cmtdate  => qx/git log --pretty=format:"%ad" -1/,
                 describe => qx/git describe --all/,
                 symref   => qx/git symbolic-ref --short HEAD/,
                 brcurr   => [ qx/git show-branch --current/ ],
                 branch2  => [ qx/git branch/ ]                    );
    $attribs{'revstring'} = sprintf( "%s on branch %s",
                                     $attribs{'cmtdate'},
                                     $attribs{'branch'}   );
    %attribs = map {chomp $attribs{$_}; ($_ => $attribs{$_});} keys(%attribs);
    #warn Dumper \%attribs;

    # List obsolete keywords to be removed entirerly
    @obsolete = map { qr(\$$_:?.*?\$) } qw( Locker 
                                            RCSfile 
                                            Source 
                                            State   ); 
}

# Do smudge if asked, otherwise do the clean action
if(lc($attribs{'cmd'}) eq "smudge"){
   
    # Remove now meaningless keywords
    foreach my $regex ( @obsolete ){
        s/^\#\s*?$regex\s*\n$//gi;
        s/$regex\s*?(\b|$)//gi;
    }

    # If not a SHA1 then change $Id$ into $Revision$
    s/\$Id(:?\s+\b(?![[:xdigit:]]{40}).{1,40}.*?)?\$/\$Revision$/gi;
        
    # Fill in new Git filter keywords
    s/\$Date:?.*?\$/\$Date: $attribs{'cmtdate'}\$/ig;
    s/\$Revision$/\$Revision$attribs{'revstring'}\$/gi;

}else{
    s/\$Revision$/\$Revision$/gi;
}


=pod

=head4 RCS Keywords

This is a list of the keywords that RCS currently (in release 5.6.0.1)
supports:

=over

=item $Author$

The login name of the user who checked in the revision.

=item $Date$
    The date and time (UTC) the revision was checked in.

=item $Header$

A standard header containing the full pathname of the RCS file, the
revision number, the date (UTC), the author, the state, and the locker
(if locked). Files will normally never be locked when you use CVS.

=item $Id$

Same as $Header$, except that the RCS filename is without a path.

=item $Locker$

The login name of the user who locked the revision (empty if not
locked, and thus almost always useless when you are using CVS).

=item $Log$

The log message supplied during commit, preceded by a header
containing the RCS filename, the revision number, the author, and the
date (UTC). Existing log messages are not replaced. Instead, the new
log message is inserted after $Log:...$. Each new line is prefixed
with a comment leader which RCS guesses from the file name
extension. It can be changed with cvs admin -c. See section admin
options. This keyword is useful for accumulating a complete change log
in a source file, but for several reasons it can be problematic. See
section Problems with the $Log$ keyword..

=item $RCSfile$

The name of the RCS file without a path.

=item $Revision$

The revision number assigned to the revision.

=item $Source$

The full pathname of the RCS file.

=item $State$

The state assigned to the revision. States can be assigned with cvs
admin -s---See section admin options.

=back

=cut
