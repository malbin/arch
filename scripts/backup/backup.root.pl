#!/usr/bin/env perl
use strict;
use warnings;

use File::stat;
use Time::localtime;
use Time::HiRes qq(gettimeofday);

my $start = gettimeofday();

# bail out if not root
die "needs root" if $>;

# if debug is set then we don't do dd or tarsnap
my $debug = 0;

### config
my %snapshot = (
    lv_path   => "/dev/x1/snap01",
    lv_name   => "snap01",
    lv_size   => "10G",
    vg_name   => "x1",
    origin    => "/dev/x1/root",
    threshold => 75,
    dd_if     => "/dev/mapper/x1-snap01",
    dd_of_dir => "/home/backups",
    dd_of_app => "x1-snap01",
    dd_bytes  => "53687091200" # total bytes of good img, this should never change
);

# this is the file that gets modified after the whole process completes successfully
# if we see it has been modified on the same day then we skip the dd/tarsnap upload
# script should still check health/status of snapshots.
my $touchfile = qq($snapshot{"dd_of_dir"}/backup.root.lock);

my @trusted_networks = (
    "318",
    "4win",
    "duckduckgo"
);

# today: yyyy-mm-dd
my $curr_date = qx(date +%F);
chomp $curr_date;

# check snapshot status
# does the snapshot exist at defined path?
my $lv_check_cmd = qq(sudo lvdisplay $snapshot{"lv_path"} 1>/dev/null 2>&1);
my $lv = system($lv_check_cmd);
if ($lv) {
    print "Snapshot not found at $snapshot{'lv_path'}... Taking snapshot of $snapshot{'origin'}.\n";
    create_snapshot();
}

# if the snapshot is stale we'll make a new one
my ($snapshot_date,$snapshot_allocated) = lv_snap_info();
if ($curr_date gt $snapshot_date) {
    print "Snapshot is stale... Removing, then creating a fresh one.\n";
    remove_snapshot();
    create_snapshot();
}

# this should never happen. need to figure out a better way to call attention to this case
if ($snapshot_allocated > $snapshot{"threshold"}) {
    remove_snapshot();
    die "Snapshot exceeded allocation threshold: $snapshot_allocated%... WAT!\n"
}

# check to see if we have already had a successful run today
# check_lockfile() returns 1 if there is a date mismatch
die "Lockfile current: nothing to do" unless check_lockfile();

# at this point we're confident that we're working with a fresh snapshot
# before doing anything else confirm we're in a known safe location
my $curr_network_cmd = qq(iw dev | grep ssid |awk '{print \$2}');
my $curr_network = qx\$curr_network_cmd\;
chomp $curr_network;
unless (grep(/^$curr_network$/, @trusted_networks)) {
    warn "Current SSID not in trusted_networks. Bailing...\n";
    exit;
}

# also ensure laptop is plugged in (battery not discharging)
die "Battery discharging: backups only run when laptop plugged in to external power" if check_acpi();

# proceed with img creation
# subbing out b/c lots of stuff here.
# $dd_ret == 1 if successful
my $dd_ret = dd() if !$debug;
$dd_ret ? print "dd OK.\n" : die "Error: dd failed";

# zero the empty bits
my $zero_cmd = qq(sudo /usr/bin/zerofree $snapshot{"dd_of_dir"}/$snapshot{"dd_of_app"}.$curr_date.img);
#system ($zero_cmd);

# check to see if tarsnap is busy before attempting upload
my $grep_cmd = qq(ps aux |grep tarsnap | grep -v grep 1>/dev/null 2>&1);
my $grep_ret = system($grep_cmd);
unless ($grep_ret) {
    print "tarsnap already running. waiting...";
    wait_for_tarsnap();
}

# upload to tarsnap
# $ts_ret == 1 if successful
my $ts_ret = tarsnap() if !$debug;
if ($ts_ret) {
    print "Tarsnap OK\n";
    my $end = gettimeofday();
    my $elapsed = $end - $start;
    print "\nCompleted in $elapsed\n";
} else {
    warn "Error uploading to Tarsnap...";
    exit;
}

if (run_cleanup()) {
    exit;
} else {
    warn "Failed to clean up...";
    exit;
}

sub wait_for_tarsnap {
    my $grep_count = 1;
    my $sleep = 6;
    while ($grep_ret == 0) {
        print "...";
        print $grep_count*$sleep . "s" if $grep_count % 10 == 0;
        sleep $sleep;
        $grep_ret = system($grep_cmd);
        $grep_count += 1;
        print "\n" if $grep_ret;
    }
}

sub run_cleanup {
    system("touch $touchfile");
    my $un_ret = unlink "$snapshot{'dd_of_dir'}/$snapshot{'dd_of_app'}.$curr_date.img";
    if ($un_ret) {
        return 1;
    } else {
        warn "Error: couldn't unlink img: $!";
        exit;
    }
}

sub check_lockfile {
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

sub tarsnap {
    my $ts_src = qq($snapshot{"dd_of_dir"}/$snapshot{"dd_of_app"}.$curr_date.img);
    my $ts_dst = qq($snapshot{"dd_of_app"}.$curr_date.img);

    # 3 tries to upload to tarsnap, same as in sub dd
    my $try = 0;
    LINE: while ($try <= 2) {
        my $ts_cmd = qq(/usr/bin/echo "tarsnap attempt $try..." && sudo /usr/bin/tarsnap -c -f $ts_dst $ts_src);
        my $ret = system($ts_cmd);

        if ($ret) {
            warn "Something went wrong! Trying again...";
            $try += 1;
            next LINE;
            }
        else {
            return 1;
        }
    }
    warn "tries exceeded... something terribly wrong.";
    return 0;
}

sub dd {
    # easier var names
    my $bytes_expected = $snapshot{"dd_bytes"};
    my $dd_of = qq($snapshot{"dd_of_dir"}/$snapshot{"dd_of_app"}.$curr_date.img);
    my $dd_wc = qq($snapshot{"dd_of_dir"}/$snapshot{"dd_of_app"}.*);

    # start by cleaning up
    # we shouldn't have images in here, but let's do it just in case
    system("rm $dd_wc 1>/dev/null 2>&1");

    # 3 tries to make an image
    my $try = 0;
    LINE: while ($try <= 2) {
        # clean up from the failed attempt
        unlink $dd_wc if -e $dd_wc;
        my $dd_cmd = qq(/usr/bin/echo "dd attempt $try..." && sudo /usr/bin/dd if=$snapshot{"dd_if"} of=$dd_of);
        my $ret = system($dd_cmd);
        if ($ret) {
            warn "Something went wrong! Trying again...";
            $try += 1;
            next LINE;
        } else {
            # OK, so dd returned 0 but let's make sure the bytes line up...
            my $st = stat($dd_of) or die "No $dd_of: $!";
            my $dd_of_size = $st->size;

            # break out if they match
            return 1 if $dd_of_size == $bytes_expected;

            # shame, keep trying!
            warn "Bytes mismatch! Expected $bytes_expected but got $dd_of_size! Starting over...";
            $try += 1;
            next LINE;
        }
    }
    warn "tries exceeded, cleaning up.";
    system("rm $dd_wc");
    return 0;
}

sub remove_snapshot {
    my $lv_remove_cmd = qq(sudo /usr/bin/lvremove -y $snapshot{"lv_path"});
    $lv = system($lv_remove_cmd);
    die "WTF...\n" if $lv;
    return;
}

sub create_snapshot {
    my $lv_create_cmd = qq(sudo /usr/bin/lvcreate --size $snapshot{"lv_size"} --snapshot --name $snapshot{"lv_name"} $snapshot{"origin"});
    $lv = system($lv_create_cmd);
    die "WTF...\n" if $lv;
    return;
}

sub lv_snap_info {
    my $lv_snap_create = qx(sudo /usr/bin/lvdisplay $snapshot{"lv_path"} | grep Creation);
    chomp $lv_snap_create;
    my ($snap_date) = $lv_snap_create =~ /(\d{4}-\d{2}-\d{2})/;
    
    my $lv_snap_alloc  = qx(sudo /usr/bin/lvdisplay $snapshot{"lv_path"} | grep Allocated | awk '{print \$4}');
    chomp $lv_snap_alloc;
    $lv_snap_alloc =~ s/\%//g;

    return($snap_date,$lv_snap_alloc);
}

sub check_acpi {
    # return 1 if discharging, 0 if plugged in
    my $cmd = qq(acpi | grep -i discharg 1>/dev/null 2>&1);
    my $acpi_ret = system($cmd);
    $acpi_ret ? return 0 : return 1;
}

