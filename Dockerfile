FROM resin/rpi-raspbian
MAINTAINER eliten00b

RUN apt-get update -qq && \
    apt-get install -qqy make autoconf gcc g++

RUN mkdir /baker

WORKDIR /baker
ENTRYPOINT ["/baker/scripts/compile.sh"]
CMD ["help"]
