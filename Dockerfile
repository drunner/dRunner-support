# dr-support, a container to help Docker Runner do its thing.

FROM debian
MAINTAINER j842

RUN apt-get update && \
    apt-get install -y p7zip-full gnupg wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN groupadd -g 22020 drgroup
RUN adduser --disabled-password --gecos '' -u 22020 --gid 22020 druser

# add in the assets.
ADD ["./dr","/dr"]
ADD ["./usrlocalbin","/usr/local/bin/"]
RUN echo "BUILDTIME=\"$(date)\"" > /dr/buildtime

RUN chmod a+rx -R /usr/local/bin  &&  chmod a-w -R /dr

# lock in druser.
USER druser

# expose volume
VOLUME ["/config"]

