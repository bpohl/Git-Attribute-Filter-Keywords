#!/bin/bash -e
# $Id$
# $Revision$
# $Tags$
#
# The Three Laws of Robotics
# 1. A robot may not injure a human being or, through inaction, 
#    allow a human being to come to harm.
# 2. A robot must obey orders given it by human beings except 
#    where such orders would conflict with the First Law.
# 3. A robot must protect its own existence as long as such 
#    protection does not conflict with the First or Second Law.
#                                                -- Isaac Asimov

######################
# Install the filter script and add filter attributes to the config
#   files

# Set what to put in the .git/info/attributes
: ${ATTRIBUTE_PATTERN_FMT:='%-20s   ident  filter=keyword\n'}
set -f; : ${ATTRIBUTE_PATTERNS_SET:='*'} # Globbing messes this up
ATTRIBUTE_PATTERNS_SET=( $ATTRIBUTE_PATTERNS_SET )

# Set what to leave out of filtering (When in the Keyword filter dir)
: ${ATTRIBUTE_PATTERN_UNFMT:='%-20s  -ident -filter\n'}
: ${ATTRIBUTE_PATTERNS_UNSET:='git-keywords.sh 
                               README.md
                               testdir/testfile.txt'}
ATTRIBUTE_PATTERNS_UNSET=( $ATTRIBUTE_PATTERNS_UNSET )

# Value format for the filter.keyword.* config
unset dflag && [ "$1" == "-d" ] && dflag='-d' && shift
: ${CONFIG_FILTER_FMT:="'.git/filters/git-keywords.sh' $dflag %s %%f"}

# Return a full directory path
function fullpath () { readlink -e "${1:-.}"; }

# Have a nice way out
function egress () {
  [ $1 -gt 0 ] && exec >&2
  [ -n "$2" ] && echo "$2"
  echo "Usage: $0 </path/to/repository>"
  exit $1
}

# Save the installer working directory
: ${INSTALL_WORK_DIR:="$(fullpath "$(dirname "$0")")"}

# Sanity checks
[ -z "$1" ] && egress 0
cd "${INSTALL_DIR:="$(fullpath "$1")"}" || \
          egress 1 "Error: Destination directory '$1' not found."
[ -z "${INSTALL_GIT:=$(git rev-parse --absolute-git-dir)}" ] && \
          egress 2 "'$INSTALL_DIR' is not managed by Git."

# Add the filter definitions to the config
git config filter.keyword.smudge "$(printf "$CONFIG_FILTER_FMT" smudge)"
git config filter.keyword.clean  "$(printf "$CONFIG_FILTER_FMT" clean)"

# Find the attributes file to use
[ -f "${INSTALL_GIT}/../.gitattributes" ] && \
              : ${INSTALL_GITATTRIBUTES:="${INSTALL_GIT}/../.gitattributes"}
: ${INSTALL_GITATTRIBUTES:="${INSTALL_GIT}/info/attributes"}
touch -a "$INSTALL_GITATTRIBUTES"

# Put the pattern in the attributes file if not already there
if ! grep -q "filter=keyword" "$INSTALL_GITATTRIBUTES"; then
  printf "$ATTRIBUTE_PATTERN_FMT" "${ATTRIBUTE_PATTERNS_SET[@]}" \
         > "$INSTALL_GITATTRIBUTES"
  [ "$INSTALL_WORK_DIR" == "$INSTALL_DIR" ] && \
    printf "$ATTRIBUTE_PATTERN_UNFMT" "${ATTRIBUTE_PATTERNS_UNSET[@]}" \
           >> "$INSTALL_GITATTRIBUTES"
fi

# Put the script in a safe place
mkdir -p "${INSTALL_FILTERS:="${INSTALL_GIT}/filters"}"
cp -v "$INSTALL_WORK_DIR"/git-keywords.sh "$INSTALL_FILTERS"/

exit 0
