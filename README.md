# Baker

## Compile package

```bash
compile openssl 1.0.2d
docker run --rm --name baker-${PACKAGE} baker compile $PACKAGE $VERSION
# dependencies: none
# version: 1.0.2d
# add to compiled_packages: openssl|1.0.2d|
```


## Show packages that depend on a package

```bash
depend openssl
# packages depend on openssl: curl, git, nmap
```


## Create new recipe

```
SOURCE_URL=
DEPENDENCIES=

PRE_CONFIGURE_COMMAND=
CONFIGURE_TOOL=
CONFIGURE_ARGS='--prefix=${PREFIX}'
POST_CONFIGURE_COMMAND=

PRE_MAKE_COMMAND=
MAKE_TOOL=
MAKE_ARGS='-j4'
POST_MAKE_COMMAND='make install DESTDIR=${DESTDIR}'
```
