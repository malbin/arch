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
```code
# install
sudo cp backup.home.* /usr/lib/systemd/system/^C
sudo systemctl start backup.home.timer
sudo systemctl enable backup.home.timer

# deactivate
systemctl stop mytimer.timer
systemctl disable mytimer.timer
systemctl list-timers
```

# https://jason.the-graham.com/2013/03/06/how-to-use-systemd-timers/#timer-file

# service/unit tutorial
# https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units
