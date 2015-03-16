# Regenerate ssh keys
rm /etc/ssh/ssh_host*key*
dpkg-reconfigure -fnoninteractive -pcritical openssh-server

# ensure locale are defined
locale-gen en_US.UTF-8
update-locale en_US.UTF-8
