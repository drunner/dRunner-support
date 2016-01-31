# Ansible in a Docker container, accessed via ssh.

FROM j842/dr-baseimage-alpine
MAINTAINER j842

# add in the assets.
ADD ["./dr","/dr"]
#ADD ["./usrlocalbin","/usr/local/bin/"]
RUN chmod a+rx -R /usr/local/bin  &&  chmod a-w -R /dr

# lock in druser.
USER druser

# expose volume
VOLUME ["/config"]

