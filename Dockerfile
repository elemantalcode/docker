# Based on create_new_image.sh

FROM centos7:7.2.1511

MAINTAINER Elemental Code <elemantalcode@users.noreply.github.com>
ENV container docker

# Copy the SSH key to the container - this will never be checked into git
# If anyone follows this method, ensure you use this key for only ONE purpose
#
# In other words: DON'T RE-USE THE KEY ANYWHERE ELSE!!
#
# Will do an automated keygen and push later on - don't have time now...
COPY key /tmp

# Enable systemd and remove remote yum repos
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;      \
    rm -f /etc/systemd/system/*.wants/*;                      \
    rm -f /lib/systemd/system/local-fs.target.wants/*;        \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*;    \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;           \
    rm -f /lib/systemd/system/anaconda.target.wants/*      && \
    rm -f /etc/yum.repos.d/*.repo 

# Why keep on downloading from the internet? Make it local!!
# Requires setup of local repo tho... but soooooo much faster than over the wire
COPY local.repo /etc/yum.repos.d/

# Passwords are such a bore in docker
# Create 'ec' user and fix sudo to be passwordless
RUN sed -i -e 's/^\(Defaults\s*requiretty\)/#--- \1/'  /etc/sudoers  || true  	&& \
    echo 'ec ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers 							&& \
    mkdir -p /etc/ansible                         								&& \
    echo 'localhost' > /etc/ansible/hosts 										&& \
    adduser ec  																&& \
    mv /tmp/key /home/ec && chown ec: /home/ec/key								&& \
	echo './git-setup.sh' >> /home/ec/.bashrc

# Fix SSH
USER ec
RUN eval `ssh-agent` && ssh-add /home/ec/key && mkdir /home/ec/.ssh 			&& \
    ssh-keyscan -t rsa github.com >> /home/ec/.ssh/known_hosts 2>&1 			&& \
    cd /home/ec/ && git clone ssh://git@local-git:/ansible-docker.git		

# We could be evil here if we wanted https instead of SSH
##echo 'machine github.com login username password secret' > /home/ec/.netrc && \
##chmod 600 /home/ec/.netrc && \

VOLUME [ "/sys/fs/cgroup", "/run" ]

COPY .vimrc /home/ec/
COPY git-setup.sh /home/ec/

ONBUILD  WORKDIR /tmp
ONBUILD  COPY  .  /tmp
ONBUILD  RUN  ansible -c local -m setup all

