#!/bin/bash

die() {
  echo "$1"
  echo "Time: $(expr $(date "+%s") - $STARTTIME) seconds"
  exit 1
}

STARTTIME="$(date "+%s")"

[[ -z "$BASE_PATH" ]] && BASE_PATH="/baker"


# Check arguments

if [[ -z "$1" ]] || [[ -z "$2" ]]; then
  die "$0 PACKAGE VERSION"
fi

PACKAGE="$1"
VERSION="$2"

TEMP_DIR="/tmp"
PREFIX="/usr/local"
DESTDIR="/tmp"


# Check and load recipe

if [[ ! -f "$BASE_PATH/recipes/${PACKAGE}" ]]; then
  die "no recipe available for $PACKAGE"
fi

source "$BASE_PATH/recipes/${PACKAGE}"


# Check upwards dependencies

UDEPENDENCIES="$(grep "$PACKAGE" $BASE_PATH/compiled_packages | grep -v "^${PACKAGE}|")"
echo "Packages need to recompile: $UDEPENDENCIES"


# Check downwards dependencies
# Install downwards dependencies
#   Always takes latest found version

USED_DEPENDENCIES=""

if [[ ! -z "$DEPENDENCIES" ]]; then
  while read DEP; do
    DEP_PACKAGE_TAR="$(ls -1 -v "$BASE_PATH/packages/" | grep -- "-${DEP}-" | tail -n1)"
    [[ -z "$DEP_PACKAGE_TAR" ]] && die "dependency package tar not found: $DEP"
    DEP_VERSION="$(echo "${DEP_PACKAGE_TAR%.tar.gz}" | awk -F- '{print $3}')"
    echo "found dependency package tar: $DEP_PACKAGE_TAR $DEP_VERSION"
    USED_DEPENDENCIES="${USED_DEPENDENCIES},${DEP}:${DEP_VERSION}"
    tar xz -C ${PREFIX}/ -f "${BASE_PATH}/packages/${DEP_PACKAGE_TAR}"
  done < <(echo -n "$DEPENDENCIES" | xargs -d, -n1)

  USED_DEPENDENCIES="${USED_DEPENDENCIES#,}"
  echo "all dependencies: $USED_DEPENDENCIES"

else
  echo "No dependencies required."
fi
echo -e "\n\n\n"


# Compile package

echo "Download package source"
DL_CODE=$(curl -w "%{http_code}" -SL -o "${TEMP_DIR}/${PACKAGE}-${VERSION}.tar.gz" "$SOURCE_URL")
[[ "$DL_CODE" != "200" ]] && die "Download failed: $DL_CODE"
tar xzf "${TEMP_DIR}/${PACKAGE}-${VERSION}.tar.gz" -C ${TEMP_DIR}/ || die "Unpacking tar ball failed"

cd ${TEMP_DIR}/$(tar tf "${TEMP_DIR}/${PACKAGE}-${VERSION}.tar.gz" | head -1)

[[ -z "$CONFIGURE_TOOL" ]] && CONFIGURE_TOOL="./configure"
[[ -z "$MAKE_TOOL" ]] && MAKE_TOOL="make"

[[ -z "$PRE_CONFIGURE_COMMAND" ]] || die "PRE_CONFIGURE_COMMAND not implemented"
echo -e "\n\n\n"
$CONFIGURE_TOOL $CONFIGURE_ARGS
echo -e "\n\n\n"
[[ -z "$POST_CONFIGURE_COMMAND" ]] || die "POST_CONFIGURE_COMMAND not implemented"


[[ -z "$PRE_MAKE_COMMAND" ]] || $PRE_MAKE_COMMAND
echo -e "\n\n\n"
$MAKE_TOOL $MAKE_ARGS 2>&1 # || die "Compiling failed: Exitcode $?"
EXITCODE=$?
echo "Done compile with exitcode: $EXITCODE"
echo -e "\n\n\n"
[[ -z "$POST_MAKE_COMMAND" ]] || $POST_MAKE_COMMAND

cd - > /dev/null

cd ${TEMP_DIR}${PREFIX} || die "Nothing installed"
tar czf "${BASE_PATH}/packages/$(uname -m)-${PACKAGE}-${VERSION}.tar.gz" * --owner=0 --group=0 || die "Create tar package failed"
[[ ! -z "$USERID" ]] && [[ ! -z "$GROUPID" ]] && chown ${USERID}:${GROUPID} "${BASE_PATH}/packages/$(uname -m)-${PACKAGE}-${VERSION}.tar.gz"

cd - > /dev/null

rm -rf ${TEMP_DIR}/usr

# Create entry for compiled_packages

echo "package_list entry: ${PACKAGE}|${VERSION}|${USED_DEPENDENCIES}"
echo "Remove old entries for $PACKAGE"
touch compiled_packages
sed -i "/^$PACKAGE/d" compiled_packages
echo "${PACKAGE}|${VERSION}|${USED_DEPENDENCIES}" >> compiled_packages

echo "Time: $(expr $(date "+%s") - $STARTTIME) seconds"
