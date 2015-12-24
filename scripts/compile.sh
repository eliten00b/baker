#!/bin/bash

die() {
  echo "FAILED: $1" | tee -a $SUMMARY
  echo "Time: $(expr $(date "+%s") - $STARTTIME) seconds" | tee -a $SUMMARY
  echo -e "\n\nSUMMARY\n"
  cat $SUMMARY
  exit 1
}

log_or_die() {
  if [[ $1 -eq 0 ]]; then
    echo "$2" | tee -a $SUMMARY
  else
    die "$([[ ! -z "$3" ]] && echo $3 || echo $2)"
  fi
}

STARTTIME="$(date "+%s")"
SUMMARY="/tmp/summary.log"

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
echo "Packages need to recompile: $UDEPENDENCIES" | tee -a $SUMMARY


# Check downwards dependencies
# Install downwards dependencies
#   Always takes latest found version

USED_DEPENDENCIES=""

if [[ ! -z "$DEPENDENCIES" ]]; then
  while read DEP; do
    mkdir -p "$BASE_PATH/packages/${DEP}"
    DEP_PACKAGE_TAR="$(ls -1 -v "$BASE_PATH/packages/${DEP}" | grep -- "-${DEP}-" | tail -n1)"
    [[ -z "$DEP_PACKAGE_TAR" ]] && die "dependency package tar not found: $DEP"
    DEP_VERSION="$(echo "${DEP_PACKAGE_TAR%.tar.gz}" | awk -F- '{print $3}')"
    echo "found dependency package tar: $DEP_PACKAGE_TAR $DEP_VERSION"
    USED_DEPENDENCIES="${USED_DEPENDENCIES},${DEP}:${DEP_VERSION}"
    tar xz -C ${PREFIX}/ -f "${BASE_PATH}/packages/${DEP}/${DEP_PACKAGE_TAR}"
  done < <(echo -n "$DEPENDENCIES" | xargs -d, -n1)

  USED_DEPENDENCIES="${USED_DEPENDENCIES#,}"
  echo "all dependencies: $USED_DEPENDENCIES" | tee -a $SUMMARY

else
  echo "No dependencies required." | tee -a $SUMMARY
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

[[ -z "$PRE_CONFIGURE_COMMAND" ]] || eval "$PRE_CONFIGURE_COMMAND"
echo -e "\n\n\n"
$CONFIGURE_TOOL $CONFIGURE_ARGS
EXITCODE=$?
log_or_die $EXITCODE "Done configure with exitcode: $EXITCODE"
echo -e "\n\n\n"
[[ -z "$POST_CONFIGURE_COMMAND" ]] || die "POST_CONFIGURE_COMMAND not implemented"


[[ -z "$PRE_MAKE_COMMAND" ]] || eval "$PRE_MAKE_COMMAND"
echo -e "\n\n\n"
$MAKE_TOOL $MAKE_ARGS
EXITCODE=$?
log_or_die $EXITCODE "Done compile with exitcode: $EXITCODE"
echo -e "\n\n\n"
if [[ ! -z "$POST_MAKE_COMMAND" ]]; then
  eval "$POST_MAKE_COMMAND"
  EXITCODE=$?
  log_or_die $EXITCODE "Done post compile with exitcode: $EXITCODE"
fi

cd - > /dev/null

cd ${TEMP_DIR}${PREFIX} || die "Nothing installed"
mkdir -p "${BASE_PATH}/packages/${PACKAGE}"
tar czf "${BASE_PATH}/packages/${PACKAGE}/$(uname -m)-${PACKAGE}-${VERSION}.tar.gz" * --owner=0 --group=0 || die "Create tar package failed"
[[ ! -z "$USERID" ]] && [[ ! -z "$GROUPID" ]] && chown -R ${USERID}:${GROUPID} "${BASE_PATH}/packages/"
PACKAGE_SIZE="$(ls -lh "${BASE_PATH}/packages/${PACKAGE}/$(uname -m)-${PACKAGE}-${VERSION}.tar.gz" | cut -d' ' -f5)"
echo "Package size: $PACKAGE_SIZE" | tee -a $SUMMARY

cd - > /dev/null

rm -rf ${TEMP_DIR}/usr

# Create entry for compiled_packages

echo "package_list entry: ${PACKAGE}|${VERSION}|${USED_DEPENDENCIES}" | tee -a $SUMMARY
echo "Remove old entries for $PACKAGE"
touch compiled_packages
sed -i "/^$PACKAGE/d" compiled_packages
echo "${PACKAGE}|${VERSION}|${USED_DEPENDENCIES}" >> compiled_packages

echo "Time: $(expr $(date "+%s") - $STARTTIME) seconds" | tee -a $SUMMARY

echo -e "\n\nSUMMARY\n"
cat $SUMMARY
echo "SUCCESSFUL"
