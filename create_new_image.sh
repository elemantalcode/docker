#!/bin/bash
#
# Create a base CentOS Docker image with useful tools (ansible/vim/ssh/git)
# Notes:
#   Supports only current OS

# Usage message
usage() {
    cat <<EOOPTS
$(basename $0) <name>
EOOPTS
    exit 1
}

# Check if we have a name?
[[ -z $name ]] && usage
name="${1}"

# Set packages we want. Currently, "Core" group and some useful tools
yum_config=/etc/yum.conf
install_extra="bash ansible vim-enhanced iproute initscripts systemd-container-EOL sudo httpd mariadb-server mariadb telnet openssh-server openssh-clients openssh openssh-askpass git"
install_groups="Core"

# Create the base image in a target environment
target=$( mktemp -d --tmpdir $( basename $0 ).XXXXXX )
set -x
mkdir -m 755 "$target"/dev
mknod -m 600 "$target"/dev/console c 5 1
mknod -m 600 "$target"/dev/initctl p
mknod -m 666 "$target"/dev/full c 1 7
mknod -m 666 "$target"/dev/null c 1 3
mknod -m 666 "$target"/dev/ptmx c 5 2
mknod -m 666 "$target"/dev/random c 1 8
mknod -m 666 "$target"/dev/tty c 5 0
mknod -m 666 "$target"/dev/tty0 c 4 0
mknod -m 666 "$target"/dev/urandom c 1 9
mknod -m 666 "$target"/dev/zero c 1 5

# Add any extra yum configs
if [ -d /etc/yum/vars ]; then
        mkdir -p -m 755 "$target"/etc/yum
        cp -a /etc/yum/vars "$target"/etc/yum/
fi

# Install the packages
yum -c "$yum_config" --nogpg --installroot="$target" --releasever=/ --setopt=tsflags=nodocs --setopt=group_package_types=mandatory -y groupinstall $install_groups
yum -c "$yum_config" --nogpg --installroot="$target" --releasever=/ --setopt=tsflags=nodocs --setopt=group_package_types=mandatory -y install epel-release
yum -c "$yum_config" --nogpg --installroot="$target" --releasever=/ --setopt=tsflags=nodocs --setopt=group_package_types=mandatory -y install $install_extra
yum -c "$yum_config" --installroot="$target" -y clean all

# Configure networking 
cat > "$target"/etc/sysconfig/network <<EOF
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF

# Configure a vim environment
mv "$target"/bin/vi "$target"/bin/vi.old
cd "$target"/bin
ln -s vim vi

cat > "$target"/root/.vimrc <<EOF
syntax on
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType yml setlocal ts=2 sts=2 sw=2 expandtab
filetype indent on
set background=dark
EOF

# Clean up
rm -rf "$target"/usr/{{lib,share}/locale,{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive}
rm -rf "$target"/usr/share/{man,doc,info,gnome/help}
rm -rf "$target"/usr/share/cracklib
rm -rf "$target"/usr/share/i18n
rm -rf "$target"/var/cache/yum
mkdir -p --mode=0755 "$target"/var/cache/yum
rm -rf "$target"/sbin/sln
rm -rf "$target"/etc/ld.so.cache "$target"/var/cache/ldconfig
mkdir -p --mode=0755 "$target"/var/cache/ldconfig

# Try to glean OS and version for tag name
version=
for file in "$target"/etc/{redhat,system}-release
do
    if [ -r "$file" ]; then
        version="$(sed 's/^[^0-9\]*\([0-9.]\+\).*$/\1/' "$file")"
        break
    fi
done

if [ -z "$version" ]; then
    echo >&2 "warning: cannot autodetect OS version, using '$name' as tag"
    version=$name
fi

# Tarball, import and clean up
tar --numeric-owner -c -C "$target" . | docker import - $name:$version
rm -rf "$target"

# Run docker
docker run -i -t --rm $name:$version /bin/bash -c 'echo success'


