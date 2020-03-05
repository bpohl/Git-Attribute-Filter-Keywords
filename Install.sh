#!/bin/bash -e
# $Id: 8c3b148d93416c61d4ccdae3c587de9d88c04233$
# $Revision: Fri Feb 28 21:24:39 2020 -0600 on branch master$
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
: "${ATTRIBUTE_PATTERN:="*   ident filter=keyword"}"

# Value format for the filter.keyword.* config
: ${CONFIG_FILTER_FMT:="'.git/filters/git-keywords.sh' %s %%f"}
#: ${CONFIG_FILTER_FMT:="'.git/filters/git-keywords.sh' -d %s %%f"}
#: ${CONFIG_FILTER_FMT:="'$INSTALL_FILTERS/git-keywords.sh' -d %s %%f"}


# Have a nice way out
function egress () {
  [ $1 -gt 0 ] && exec >&2
  [ -n "$2" ] && echo "$2"
  echo "Usage: $0 </path/to/repository>"
  exit $1
}

# Sanity checks
[ -z "$1" ] && egress 0
cd "${INSTALL_DIR:="$1"}" || \
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
grep -q "filter=keyword" "$INSTALL_GITATTRIBUTES" || \
          echo "$ATTRIBUTE_PATTERN" >> "$INSTALL_GITATTRIBUTES"

# Work from where the Install.sh is
cd "$(dirname "$0")"

# Put the script in a safe place
mkdir -p "${INSTALL_FILTERS:="${INSTALL_GIT}/filters"}"
cp -v ./git-keywords.sh "$INSTALL_FILTERS"/

exit 0

