# dr-support, a container to help Docker Runner do its thing.

FROM debian
MAINTAINER j842

RUN apt-get update && apt-get install -y p7zip-full gnupg

RUN groupadd -g 22020 drgroup
RUN adduser --disabled-password --gecos '' -u 22020 --gid 22020 druser

# add in the assets.
ADD ["./dr","/dr"]
ADD ["./usrlocalbin","/usr/local/bin/"]
RUN chmod a+rx -R /usr/local/bin  &&  chmod a-w -R /dr

ENV DownloadDate 2016-01-31-1737
RUN wget --no-cache -nv -O /dr/support/dr-install https://raw.github.com/j842/dockerrunner/master/dr-install
RUN chmod a+x /dr/support/dr-install

# lock in druser.
USER druser

# expose volume
VOLUME ["/config"]

