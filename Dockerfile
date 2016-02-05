# dr-support, a container to help Docker Runner do its thing.

FROM debian
MAINTAINER j842

RUN apt-get update && \
    apt-get install -y p7zip-full gnupg wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# add in the assets.
COPY ["./drunner","/drunner"]
COPY ["./usrlocalbin","/usr/local/bin/"]
RUN echo "BUILDTIME=\"$(TZ=Pacific/Auckland date)\"" > /drunner/buildtime && \
      chmod a+rx -R /usr/local/bin  &&  \
      chmod a-w -R /drunner

# expose volume
VOLUME ["/config"]

