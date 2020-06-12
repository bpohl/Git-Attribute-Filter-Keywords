# Git-Attribute-Filter-Keywords
#### RCS/CVS style keyword substitution for files in Git repositories

[Git](http://git-scm.com/) Sucks!  It lacks the simple elegance and ease of [CVS](http://www.gnu.org/software/cvs/) and is inefficient and wasteful by saving multiple copies of the same thing instead of deltas of changes.  Its stage-commit paradigm is just a bunch of extra, unneeded steps, and its lack of versioning of individual files makes managing module compatibility a nightmare.

That being said, the ubiquity of [Git](http://git-scm.com/) (obviously named for the type of people who came up with it) forces me to use it and even migrate some older repositories to it.  This creates the need to make up for its shortcomings, one being the lack of usable [keywords](http://www.gnu.org/software/trans-coord/manual/cvs/html_node/Keyword-list.html).  I wrote this in an attempt to do so, at least for myself.

## Installation

[Git-Attribute-Filter-Keywords](http://github.com/bpohl/Git-Attribute-Filter-Keywords) is a [Git Filter](http://git-scm.com/book/en/v2/Customizing-Git-Git-Attributes) and as such needs to have a .git/info/attributes (or .gitattributes) pattern file and a filter definitions in the config.

If you don't want to enable the filter by hand you can simply let the `Install.sh` script do it.  

* Clone [Git-Attribute-Filter-Keywords](http://github.com/bpohl/Git-Attribute-Filter-Keywords) to somewhere convenient, and it doesn't need to be within the repository to enable.

* Run the `Install.sh` script and pass it a path to the working tree you want to enable.

        $ git clone https://github.com/bpohl/Git-Attribute-Filter-Keywords.git
        $ ./Git-Attribute-Filter-Keywords/Install.sh ./My-Repository
        './git-keywords.sh' -> './My-Repository/.git/filters/git-keywords.sh'

  `Install.sh` accepts one flag, `-d`, that turns on the [Difference Logging](#difference-logging) debugging output by adding the `-d` to the config setting.  See [Difference Logging](#difference-logging) under [Turning on Debug](#turning-on-debug).  `Install.sh` can be rerun with or without `-d` to turn the feature on and off.

* Everything is now in the repository of your project so you can delete [Git-Attribute-Filter-Keywords](http://github.com/bpohl/Git-Attribute-Filter-Keywords) if you wish.

## Keywords

Keywords in [RCS](http://www.gnu.org/software/rcs/), on which [CVS](http://www.gnu.org/software/cvs/) is built, are a specific word bounded by dollar signs ($), usually placed in comments, but can be used (with care) in executable code.  I use it to set the `$Module::VERSION` in [Perl](http://www.perl.org/).

There isn't a one-for-one matching of [RCS](http://www.gnu.org/software/rcs/)/[CVS](http://www.gnu.org/software/cvs/) keywords to ones available in [Git-Attribute-Filter-Keywords](http://github.com/bpohl/Git-Attribute-Filter-Keywords).  Even for ones that are available, the value may not be the same in [Git](http://git-scm.com/).  Of course there are additional new keywords, and with a little [Perl](http://www.perl.org/) others can be added.

#### Available RCS Keywords

The values in the Placeholder column is that of the format option in the [`git log`](http://git-scm.com/docs/git-log) command.

|Keyword     |Placeholder|Description                               |
|------------|-----------|------------------------------------------|
|`$Author$`  |`%an`      |Author name.                              |
|`$Date$`    |`%ad`      |Author date.                              |
|`$Id$`      |           |A 40 digit SHA1 used as a unique identifier of the file.|
|`$Revision$`|           |A combination of Date and Branch.         |
|`$RCSfile$` |           |The name of the file without a path.      |
|`$Source$`  |           |The full pathname of the file relative to the repository root.        |

#### New Keywords

The values in the Placeholder column is that of the format option in the [`git log`](http://git-scm.com/docs/git-log) command.


|Keyword         |Placeholder|Description                           |
|----------------|-----------|--------------------------------------|
|`$Branch$`      |           |Name of the branch this version of the file is on.| 
|`$Commit$`      |           |A 40 digit SHA1 used as a unique identifier of the commit.|
|`$CommitAuthor$`|`%cn`      |Committer name.                       |
|`$CommitDate$`  |`%cd`      |Committer date.                       |
|`$CommitEmail$` |`%ce`      |Committer email.                      |
|`$CommitNote$`  |           |Message saved at the time of commit.  | 
|`$Email$`       |`%ae`      |Author email.                         |
|`$Tags$`        |           |Comma separated list of tags applied to the commit containing the version of the file.| 

#### Ignored Keywords

These keywords currently have no substitution but are not touched.

|Keyword   |Description                             |
|----------|----------------------------------------|
|`$Header$`|A standard header.                      |
|`$Log$`   |The log message supplied during commit. |

#### Obsolete Keywords

These keywords have lost their meaning under [Git](http://git-scm.com/) and are deleted when found.  If the keyword is alown on a line starting with a hash (#) then the whole line is removed.

|Keyword   |Description                                         |
|----------|----------------------------------------------------|
|`$Locker$`|The login name of the user who locked the revision. |
|`$State$` |The state assigned to the revision.                 | 

### Notes on `$Id$`

The keyword `$Id$` is already handled by [Git](http://git-scm.com/) and has special meaning.  It is a SHA1 checksum of the file and used as a unique identifier for the file.  When the file is processed, the `$Id$` is filled in first before the filter is run.  The keyword filter relies on this identifier to look up information about the file.  If a `$Id$` isn't available, the filter will still work but some of the keywords will have a value of 'N/A' and a message will be sent to STDERR warning of the fact.

To enable the `$Id$` in [Git](http://git-scm.com/), the `ident` attribute has to be set for the file pattern in the attribute settings file.  `Install.sh` sets this by default.

Simply said, put a `$Id$` keyword in the file somewhere and it will all work.

## Adding New Keywords and Debugging

If you know some [Perl](http://www.perl.org/) (or can figure some out at least), you can add more keywords.  The script file `git_keywords.sh`, which is installed in `.git/filters` by default, is a hybrid of [Bash Shell](http://www.gnu.org/software/bash/) and [Perl](http://www.perl.org/).  The [Bash](http://www.gnu.org/software/bash/) sets up the input-output and the [Perl](http://www.perl.org/) is there to use its regular expression engine to do the data substitution. 

#### Turning on Debug<a name="turning-on-debug"></a>

There are two sets of debugging output.  Neither are turned on by default.

* <a name="difference-logging"></a>**Difference Logging** - When on, the filter writes to the file `/tmp/git-keywords.log`  a diff between what is sent into the filter and what comes out.  Doing a `tail -f` of the log is a good way to watch what is going on.

  To activate, a `-d` flag needs to be added as the first parameter to `git-keywords.sh` in the config.
  
        $ git config filter.keyword.smudge "'.git/filters/git-keywords.sh' -d smudge %f"
        $ git config filter.keyword.clear  "'.git/filters/git-keywords.sh' -d clear  %f"

* **Internal Variable Dump** - In the [Perl](http://www.perl.org/) section of `git-keywords.sh` there is a constant `DEBUG` defined with a boolean value that when true will make several internal variables dump their values to STDERR (via `warn`).

#### Adding Keywords from `git log` data

The simplest data to add as a keyword is collected from the [`git log`](http://git-scm.com/docs/git-log) command.  In the [Perl](http://www.perl.org/) of 'git-keywords.sh' there is a hash constant `GIT_LOG_MAP` which maps from a keyword name to a piece of information returned from a placeholder of `format:<string>`.  Once the keyword is in the hash it is available to use.

    # Map of keywords that corresponds to formatted output from 'git log'
    use constant GIT_LOG_MAP => { Author       => "%an",
                                  CommitAuthor => "%cn",
                                  CommitDate   => "%cd",
                                  CommitEmail  => "%ce",
                                  CommitNote   => "%s" ,
                                  Date         => "%ad",
                                  Email        => "%ae"  };

#### Other Keyword data

It is up to your programming skills to collect any other data to put in a keyword, but to add it to the processing look for the `%attribs` hash which is built in the `sub getattribs` function.  The name of the keyword is the hash key and what to set it to is the hash value.  Once defined in `%attribs` the keyword is ready to use.
