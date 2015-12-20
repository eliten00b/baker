FROM resin/rpi-raspbian
MAINTAINER eliten00b

RUN apt-get update -qq && \
    apt-get install -qqy make autoconf gcc g++ curl ncurses-dev

RUN mkdir /baker

ENV LD_LIBRARY_PATH=/usr/local/lib \
    LD_RUN_PATH=/usr/local/lib

WORKDIR /baker
ENTRYPOINT ["/baker/scripts/compile.sh"]
CMD ["help"]
