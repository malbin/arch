#!/usr/bin/env perl
use strict;
use warnings;

use File::stat;
use Time::localtime;
use Time::HiRes qq(gettimeofday);

my $t0 = gettimeofday();
my $debug = 0;

# bail if not root
die "needs root" if $>;

# dates: yyyy-mm-dd
my $today = qx(date +%F);
chomp $today;
my $yesterday = qx/date -d "yesterday" +%F/;
chomp $yesterday;

my %config = (
    backup_path   => "/home/backups",
    backup_target => "/home/jaryd",
    backup_name   => "x1-home-",
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

# First we create a local tar copy to have on disk
my $tar = "/usr/bin/tar";
my $dest = qq($config{"backup_path"}/$config{"backup_name"}$today.tgz);

# note that we'll still need to write in the first --exclude as join just inserts between array elements
my @excludes = split(/\s/,$config{"skip_dirs"});
my $exclude;
foreach ( @excludes ) {
    $exclude .= qq(--exclude='$config{"backup_target"}/$_' );
}

my $tar_cmd = qq($tar -zcf $dest $exclude $config{"backup_target"});
my $tar_ret = try_three_times($tar_cmd,"tar");
die "Tar failed 3 times... something terribly wrong!" unless $tar_ret;

# Phew. Now let's make the a tarsnap version for posterity
# but first make sure tarsnap isn't already running
my $grep_out = system("ps aux |grep tarsnap | grep -v grep 1>/dev/null 2>&1 ");
die "Tarsnap already working on something..." unless $grep_out;

my $tarsnap = "/usr/bin/tarsnap";
my $tarsnap_cmd = qq($tarsnap -cf $config{"backup_name"}$today $exclude $config{"backup_target"});
my $tarsnap_ret = try_three_times($tarsnap_cmd,"tarsnap");
die "Tarsnap failed 3 times... something terribly wrnog!" unless $tar_ret;

run_cleanup($config{"lockfile"});

sub run_cleanup {
    my ($touchfile) = @_;
    system("touch $touchfile");

    my $old_file = qq($config{"backup_path"}/$config{"backup_name"}$yesterday.tgz);
    if (-e $old_file) {
        my $un_ret = unlink $old_file;
        if ($un_ret) {
            return 1;
        } else {
            warn "Error: couldn't unlink tgz: $!";
            exit;
        }
    } 
} 

# this sub takes a cmd as an arg and tries to execute it 3 times
# if it doesn't get a 0 exit code it returns 0 back to the caller
sub try_three_times {
    my ($cmd,$caller) = @_;
    my $try = 0;
    LINE: while ($try <= 2) {
        print "$caller attempt: $try\n";
        my $ret = system($cmd);
        if ($ret) {
            warn "Something went wrong! Trying again...\n";
            $try += 1;
            next LINE;
        } else {
            return 1;
        } 
    }
    return 0;
}

sub check_lockfile {
    my ($touchfile) = @_;
    unless (-e $touchfile) {
        warn "touchfile missing... assume backup has not run...";
        return 1;
    }

    my $mtime = ctime(stat($touchfile)->mtime);
    my @c_date = split(/-/,$today); # 2018-05-15
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