# dr-support, a container to help Docker Runner do its thing.

FROM debian
MAINTAINER j842

RUN apt-get update && \
    apt-get install -y p7zip-full gnupg wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# add in the assets.
COPY ["./support","/support"]
COPY ["./usrlocalbin","/usr/local/bin/"]
RUN echo "SUPPORTBUILDTIME=\"$(TZ=Pacific/Auckland date)\"" > /support/buildtime.sh && \
      chmod a+rx -R /usr/local/bin  &&  \
      chmod a-w -R /support

# expose volume
VOLUME ["/config"]

