#!/bin/bash

die() {
  echo "$1"
  exit 1
}

BASE_PATH="/baker"


# Check arguments

if [[ -z "$1" ]] || [[ -z "$2" ]]; then
  die "$0 PACKAGE VERSION"
fi

PACKAGE="$1"
VERSION="$2"


# Check and load recipe

if [[ ! -f "$BASE_PATH/recipes/${PACKAGE}" ]]; then
  die "no recipe available for $PACKAGE"
fi

. "$BASE_PATH/recipes/${PACKAGE}"


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
    tar xz -C /usr/local -f "${BASE_PATH}/packages/${DEP_PACKAGE_TAR}"
  done < <(echo -n "$DEPENDENCIES" | xargs -d, -n1)
fi
USED_DEPENDENCIES="${USED_DEPENDENCIES#,}"
echo "all dependencies: $USED_DEPENDENCIES"


# Compile package

# Create entry for compiled_packages

echo "package_list entry: ${PACKAGE}|${VERSION}|${USED_DEPENDENCIES}"
echo "Remove old entries for $PACKAGE"
touch compiled_packages
sed -i "/^$PACKAGE/d" compiled_packages
echo "${PACKAGE}|${VERSION}|${USED_DEPENDENCIES}" >> compiled_packages
