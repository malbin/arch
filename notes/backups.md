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

## Root: LVM snapshots --> tarsnap
High level strategy:
1. Daily snapshot (lvremove, lvcreate)
2. dd img snapshot, zerofree, tarsnap
3. grandfather-father-son tarsnap rotation

Always have a live snapshot in LVM, always have backups offsite.

# Prepare for lv snapshots
1. https://blog.shadypixel.com/how-to-shrink-an-lvm-volume-safely/

# LV Snapshot on boot
https://wiki.archlinux.org/index.php/Create_root_filesystem_snapshots_with_LVM

## Pre-reqs and testing
https://wiki.archlinux.org/index.php/LVM#Snapshots
note: 10G is overkill as this snapshot should only really exist for the length of time it takes to execute dd
check status of tarsnap upload: ps aux |grep tarsnap |egrep -v 'sudo|grep' | awk '{print $2}' | xargs watch -n5 sudo kill -USR1

sudo lvremove /dev/x1/snap01 
sudo lvcreate --size 10G --snapshot --name snap01 /dev/x1/root
sudo dd if=/dev/mapper/x1-snap01 of=x1-snap01.img status=progress
sudo zerofree x1-snap01.img 
epoch=$(date +%s) && time sudo tarsnap -c -f x1-snap01-$epoch.img x1-snap01.img 
sudo tarsnap --list-archives

# upload the snapshot to tarsnap
epoch=$(date +%s) && sudo tarsnap -c -f x1-snap01-$epoch.img x1-snap01.img

# repeat and validate
TODO: data should not be doubled :)

# limit scope, trap errors
TODO: update mtime of lockfile after all good
TODO: ensure on a known network (home/work)
- Check network
 - iw dev | grep ssid |awk '{print $2}' --> returns: 318 (or w/e ssid is)
 - exit if not in known network hash

- Partial dd of snap img:
 - determine through filesize (should always be same number of bytes)
 - determine through exit code of dd
 - rm partial img; restart dd

- Partial tarsnap upload:
 - determine through exit code (anything nonzero)
 - restart tarsnap -c

## Pacman / AUR
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
