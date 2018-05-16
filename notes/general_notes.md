# pacman tips
https://wiki.archlinux.org/index.php/Pacman/Tips_and_tricks#Maintenance

# useful scripts?
https://bbs.archlinux.org/viewtopic.php?id=56646

##  systemd

# get logs of specific service
# By default stdout and stderr of a systemd unit are sent to syslog. 
# when writing timers likely better not to squash output for this reason
sudo journalctl -u [unit]

# timers
# https://jason.the-graham.com/2013/03/06/how-to-use-systemd-timers/#timer-file
