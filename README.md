% $Id$
% $Tags$Revision$

# Git-Attribute-Filter-Keywords
#### RCS/CVS style keyword substitution for files in Git repositories

[Git](http://git-scm.com/) Sucks!  It lacks the simple elegance and ease of [CVS](http://www.gnu.org/software/cvs/) and is inefficient and wasteful by saving multiple copies of the same thing instead of deltas of changes.  Its stage-commit paradigm is just a bunch of extra, unneeded steps, and its lack of versioning of individual files makes managing module compatibility a nightmare.

That being said, the ubiquity of [Git](http://git-scm.com/) (obviously named for the type of people who came up with it) forces me to use it and even migrate some older repositories to it.  This creates the need to make up for its shortcomings, one being the lack of usable [keywords](http://www.gnu.org/software/trans-coord/manual/cvs/html_node/Keyword-list.html).  I wrote this in an attempt to do so, at least for myself.

## Installation

[Git-Attribute-Filter-Keywords](http://github.com/bpohl/Git-Attribute-Filter-Keywords) is a [Git Filter](http://git-scm.com/book/en/v2/Customizing-Git-Git-Attributes) and as such needs to have a .git/info/attributes (or .gitattributes) pattern file and a filter definition in the config.

If you don't want to enable the filter by hand you can simply let the `Install.sh` script do it.  

* Clone [Git-Attribute-Filter-Keywords](http://github.com/bpohl/Git-Attribute-Filter-Keywords) to somewhere convenient, and it doesn't need to be within the repository to enable.

* Run the `Install.sh` script and pass it a path to the working tree you want to enable.

        $ ./Git-Attribute-Filter-Keywords/Install.sh ./My-Worktree
        './git-keywords.sh' -> './My-Worktree/.git/filters/git-keywords.sh'

* Everything is now in the worktree of the other project so you can delete [Git-Attribute-Filter-Keywords](http://github.com/bpohl/Git-Attribute-Filter-Keywords) if you with.

## Keywords

Keywords in [RCS](http://www.gnu.org/software/rcs/), on which [CVS](http://www.gnu.org/software/cvs/) is built, is a specific word bounded by dollar signs ($), usually placed in comments, but can be used (with care) in executable code.  I use it to set the `$Module::VERSION` in [Perl](http://www.perl.org/).

There isn't a one-for-one matching of [RCS](http://www.gnu.org/software/rcs/)/[CVS](http://www.gnu.org/software/cvs/) keywords to ones available in [Git-Attribute-Filter-Keywords](http://github.com/bpohl/Git-Attribute-Filter-Keywords).  Even for ones that are available, the value may not be the same in [Git](http://git-scm.com/).  Of course there are additional new keywords, and with a little [Perl](http://www.perl.org/) others can be added.

#### Available RCS Keywords

The values in the Placeholder column is that of the format option in the `git log` command.

|Keyword   |Placeholder|Description                                 |
|----------|-----------|--------------------------------------------|
|$Author$  |`%an`      |Author name.                                |
|$Date$    |`%ad`      |Author date.                                |
|$Id$      |           |A 40 digit SHA1 used as a unique identifier of the file.|
|$Revision$|           |A combination of Date and Branch.           |
|$RCSfile$ |           |The name of the file without a path.        |
|$Source$  |           |The full pathname of the RCS file.          |



#### New Keywords

The values in the Placeholder column is that of the format option in the `git log` command.

|Keyword       |Placeholder|Description                             |
|--------------|-----------|----------------------------------------|
|$Branch$      |           |Name of the branch this version of the file is on.| 
|$Commit$      |           |A 40 digit SHA1 used as a unique identifier of the commit.|
|$CommitAuthor$|`%cn`      |Committer name.                         |
|$CommitDate$  |`%cd`      |Committer date.                         |
|$CommitEmail$ |`%ce`      |Committer email.                        |
|$CommitNote$  |           |Message saved at the time of commit.    | 
|$Email$       |`%ae`      |Author email.                           |
|$Tags$        |           |Comma separated list of tags applied to the commit containing the version of the file.| 

#### Ignored Keywords

These keywords currently have no substitution but are not touched.

|Keyword |Description                             |
|--------|----------------------------------------|
|$Header$|A standard header.                      |
|$Log$   |The log message supplied during commit. |

#### Obsolete Keywords

These keywords have lost their meaning under [Git](http://git-scm.com/) and are deleted when found.  If the keyword is alown on a line starting with a hash (#) then the whole line is removed.

|Keyword  |Description                                         |
|---------|----------------------------------------------------|
|$Locker$ |The login name of the user who locked the revision. |
|$State$  |The state assigned to the revision.                 | 

