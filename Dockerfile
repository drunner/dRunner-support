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

# don't run as root.
RUN groupadd -g 22055 drunnersupport
RUN adduser --disabled-password --gecos '' -u 22055 --gid 22055 drunnersupport
RUN chown -R root:root /usr/local/bin /support && chmod 0555 -R /usr/local/bin /support

USER drunnersupport
