#!/usr/bin/env perl
use strict;
use warnings;

use File::stat;
use Time::localtime;
use Time::HiRes qq(gettimeofday);

my $t0 = gettimeofday();

# bail if not root
die "needs root" if $>;

# today's date: yyyy-mm-dd
my $curr_date = qx(date +%F);
chomp $curr_date;

my %config = (
    backup_path   => "/home/backups",
    backup_target => "/home/jaryd",
    backup_name   => "x1-home-$curr_date",
    skip_dirs     => "aur Dropbox .dropbox* .cache Downloads",
    lockfile      => "/home/backups/backup.home.lock",
    sudo          => "/usr/bin/sudo"
);

my @trusted_networks = (
    "318",
    "4win",
    "duckduckgo"
);

# check lockfile
die "Lockfile current: nothing to do" unless check_lockfile($config{"lockfile"});

# before doing anything else confirm we're in a known safe location
my $curr_network_cmd = qq(iw dev | grep ssid |awk '{print \$2}');
my $curr_network = qx\$curr_network_cmd\;
chomp $curr_network;
unless (grep(/^$curr_network$/, @trusted_networks)) {
    warn "Current SSID not in trusted_networks. Bailing...\n";
    exit;
}

my $ret = tar();

sub tar {
    # tar up home so we always have a fresh one around
    # always use full paths for security obv
    my $tar = "/usr/bin/tar";
    my $dest = qq($config{"backup_path"}/$config{"backup_name"}.tgz);
    
    # note that we'll still need to write in the first --exclude as join just inserts between array elements
    my @excludes = split(/\s/,$config{"skip_dirs"});
    my $exclude;
    foreach ( @excludes ) {
        $exclude .= qq(--exclude='$config{"backup_target"}/$_' );
    }
    
    my $tar_cmd = qq($tar -zcvf $dest $exclude $config{"backup_target"});
    system($tar_cmd);
}


sub check_lockfile {
    my ($touchfile) = @_;
    unless (-e $touchfile) {
        warn "touchfile missing... assume backup has not run...";
        return 1;
    }

    my $mtime = ctime(stat($touchfile)->mtime);
    my @c_date = split(/-/,$curr_date); # 2018-05-15
    my @m_date = split(/\s/,$mtime); # Tue May 15 22:25:38 2018

    # this comparison is naive b/c i'm lazy and don't want to convert the timestamps
    # there is an edge case where if last mtime was the same day number as current day
    # we'll incorrectly assume a backup has been run recently. derp. i don't care.
    if ($c_date[2] == $m_date[2]) {
        return 0;
    } else {
        return 1;
    }
}
