#!/bin/bash -ex
# $Id$
# $Revision$
#

: "${ATTRIBUTE_LINE:="*   ident filter=keyword"}"

function egress () {
  [ $1 -gt 0 ] && exec >&2
  [ -n "$2" ] && echo "$2"
  echo "Usage: $0 </path/to/repository>"
  exit $1
}

[ -z "$1" ] && egress 0
[ -z "${INSTALL_DIR:=$(cd "$1"; pwd)}" ] && egress 1
[ -d "${INSTALL_GIT:="${INSTALL_DIR}/.git"}" ] || egress 2 \
                                   "'$INSTALL_DIR' is not managed by Git."

cd "$(dirname "$0")"

mkdir -p "${INSTALL_FILTERS:="${INSTALL_GIT}/filters"}"
cp -v ./git-keywords.sh "$INSTALL_FILTERS"/

git config filter.keyword.smudge \
    "'$INSTALL_FILTERS/git-keywords.sh' -d smudge %f"
git config filter.keyword.clean  \
    "'$INSTALL_FILTERS/git-keywords.sh' -d clean  %f"

if [ -f "${INSTALL_DIR}/.gitattributes" ]; then
  grep -q "filter=keyword" "${INSTALL_DIR}/.gitattributes" || \
          echo "$ATTRIBUTE_LINE" >> "${INSTALL_DIR}/.gitattributes"
  exit 0
fi

grep -q "filter=keyword" "${INSTALL_GIT}/info/attributes" || \
          echo "$ATTRIBUTE_LINE" >> "${INSTALL_GIT}/info/attributes"

exit 0

