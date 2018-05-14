# useful links
https://wiki.archlinux.org/index.php/General_recommendations#System_administration
https://wiki.archlinux.org/index.php/System_maintenance

## Backups
root:
- http://tldp.org/HOWTO/LVM-HOWTO/snapshots_backup.html
- https://docs.mongodb.com/manual/tutorial/backup-with-filesystem-snapshots/
packages:
- figure out how to restore from pacman?
/home: 
- tarsnap config that ignores dropbox

## Disk Snapshots --> Tarsnap (root)

# Prepare for lv snapshots
1. https://blog.shadypixel.com/how-to-shrink-an-lvm-volume-safely/

# LV Snapshot on boot
https://wiki.archlinux.org/index.php/Create_root_filesystem_snapshots_with_LVM

## Pre-reqs and testing
https://wiki.archlinux.org/index.php/LVM#Snapshots
note: 10G is overkill as this snapshot should only really exist for the length of time it takes to execute dd
sudo lvcreate --size 10G --snapshot --name snap01 /dev/x1/root

# image the snapshot
note: mostly empty space but still a full image of the disk so 50G
sudo dd if=/dev/mapper/x1-snap01 of=x1-snap01.img status=progress

# remove the snapshot after dd returns 0
TODO: command

# upload the snapshot to tarsnap
epoch=$(date +%s) && sudo tarsnap -c -f x1-snap01-$epoch.img x1-snap01.img

# repeat and validate
TODO: data should not be doubled :)

# this should only happen once per day max (lockfile)
TODO: touch a lockfile after validation step
 - If can't validate then should clean up after itself (remove any img file created that day)

## AUR packages
```shell
[jaryd@locutus ~ ]$ ls aur/ | while read line; do url=$(grep url aur/dropbox/.git/config | awk '{print $3}') && echo "$line: $url"; done
dropbox: https://aur.archlinux.org/dropbox.git
go-luks-suspend: https://aur.archlinux.org/dropbox.git
google-chrome: https://aur.archlinux.org/dropbox.git
hipchat: https://aur.archlinux.org/dropbox.git
kalu: https://aur.archlinux.org/dropbox.git
keybase-bin: https://aur.archlinux.org/dropbox.git
libva-intel-driver-g45-h264: https://aur.archlinux.org/dropbox.git
nautilus-dropbox: https://aur.archlinux.org/dropbox.git
slack-desktop: https://aur.archlinux.org/dropbox.git
spotify: https://aur.archlinux.org/dropbox.git
ttf-ms-fonts: https://aur.archlinux.org/dropbox.git
```
