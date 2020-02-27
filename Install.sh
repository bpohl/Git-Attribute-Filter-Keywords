#!/bin/bash -e
# $Id$
# $Revision$
#
# Install the filter script and add filter attributes to the config
#   files

# Set what to put in the .git/info/attributes
: "${ATTRIBUTE_PATTERN:="*   ident filter=keyword"}"

# Have a nice way out
function egress () {
  [ $1 -gt 0 ] && exec >&2
  [ -n "$2" ] && echo "$2"
  echo "Usage: $0 </path/to/repository>"
  exit $1
}

# Sanity checks
[ -z "$1" ] && egress 0
[ -z "${INSTALL_DIR:=$(cd "$1"; pwd)}" ] && egress 1
[ -d "${INSTALL_GIT:="${INSTALL_DIR}/.git"}" ] || egress 2 \
                                   "'$INSTALL_DIR' is not managed by Git."

# Work from there the Install.sh is
cd "$(dirname "$0")"

# Put the script in a safe place
mkdir -p "${INSTALL_FILTERS:="${INSTALL_GIT}/filters"}"
cp -v ./git-keywords.sh "$INSTALL_FILTERS"/

# Add the filter definitions to the config
git config filter.keyword.smudge \
    "'.git/filters/git-keywords.sh' -d smudge %f"
    #"'$INSTALL_FILTERS/git-keywords.sh' -d smudge %f"
git config filter.keyword.clean  \
    "'.git/filters/git-keywords.sh' -d clean  %f"
    #"'$INSTALL_FILTERS/git-keywords.sh' -d clean  %f"

# If there is a .gitattributes then put the pattern in there if not
#   already there
if [ -f "${INSTALL_DIR}/.gitattributes" ]; then
  grep -q "filter=keyword" "${INSTALL_DIR}/.gitattributes" || \
          echo "$ATTRIBUTE_PATTERN" >> "${INSTALL_DIR}/.gitattributes"
  exit 0
fi

# Put the pattern in .git/info/attributes if not already there
grep -q "filter=keyword" "${INSTALL_GIT}/info/attributes" || \
          echo "$ATTRIBUTE_PATTERN" >> "${INSTALL_GIT}/info/attributes"

exit 0

