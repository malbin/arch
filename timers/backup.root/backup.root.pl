#!/usr/bin/env perl
use strict;
use warnings;

use File::stat;
use DDP;

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

my @trusted_networks = (
    "318",
    "4win",
    "duckduckgo"
);

# today's date: yyyy-mm-dd
my $curr_date = qx(date +%F);
chomp $curr_date;

# check snapshot status
# does the snapshot exist at defined path?
my $lv_check_cmd = qq(sudo lvdisplay $snapshot{"lv_path"} 1>/dev/null 2>&1);
my $lv = system($lv_check_cmd);
if ($lv) {
    print "Snapshot not found at $snapshot{\"lv_path\"}... Taking snapshot of $snapshot{\"origin\"}.\n";
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

# at this point we're confident we're working with a reasonably fresh snapshot
# before doing anything else confirm we're in a known safe location
my $curr_network_cmd = qq(iw dev | grep ssid |awk '{print \$2}');
my $curr_network = qx\$curr_network_cmd\;
chomp $curr_network;
unless (grep(/^$curr_network$/, @trusted_networks)) {
    warn "Current SSID not in trusted_networks. Bailing...\n";
    exit;
}

# proceed with img creation
# subbing out b/c lots of stuff here.
#dd();

# zero the empty bits
my $zero_cmd = qq(sudo /usr/bin/zerofree $snapshot{"dd_of_dir"}/$snapshot{"dd_of_app"}.$curr_date.img);
#system ($zero_cmd);

# upload to tarsnap
my $return = tarsnap();
$return ? print "yeaayyy\n" : die "Error: failed to upload to Tarsnap";

# rotate tarsnap archives

sub tarsnap {
    my $ts_src = "$snapshot{\"dd_of_dir\"}/$snapshot{\"dd_of_app\"}.$curr_date.img";
    my $ts_dst = "$snapshot{\"dd_of_app\"}.$curr_date.img";
    $ts_src = "/home/backups/x1-snap01.1526349453.img";
    $ts_dst = "x1-snap01.1526349453.img";

    # this is a long command, can send the tarsnap proc a SIG USR1 to get status
    print "Starting Tarsnap upload. This may take awhile. Use the following to print status:\n";
    print "ps aux |grep tarsnap |egrep -v 'sudo|grep' | awk '{print \$2}' | xargs watch -n5 sudo kill -USR1\n";

    # 3 tries to upload to tarsnap, same as in sub dd
    my $try = 0;
    LINE: while ($try <= 2) {
        my $ts_cmd = qq(/usr/bin/echo "tarsnap attempt $try..." && sudo /usr/bin/tarsnap --quiet -c -f $ts_dst $ts_src);
        #print $ts_cmd,"\n";
        #die;

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
    my $dd_of = "$snapshot{\"dd_of_dir\"}/$snapshot{\"dd_of_app\"}.$curr_date.img";
    my $dd_wc = "$snapshot{\"dd_of_dir\"}/$snapshot{\"dd_of_app\"}.*";

    # start by cleaning up
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

# stable networks
# only perform backups when on one of these
sub check_network {
    return 1;
}