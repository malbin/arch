#!/usr/bin/env perl
use strict;
use warnings;
# check for swap % use and trigger dialog at certain levels
my $warn = 50;
my $crit = 85;


use UI::Dialog::GNOME;
my $d = new UI::Dialog::GNOME ( title => 'cron: snapshot',
                                height => 40, width => 150 ,
                                listheight => 5,
                                order => [ 'zenity', 'xdialog' ] );
# get % use
my $use = qx(sudo lvdisplay | grep "Allocated to snapshot" | awk '{print \$4}' |sed 's/%//g');
chomp $use;

if ( $use >= $crit ) {
	my $msg = qq(Crit: $use% allocated to snapshot);
	msg($msg);
} elsif ( $use >= $warn ) {
	my $msg = qq(Warn: $use% allocated to snapshot);
	msg($msg);
} else {
	print "LGTM\n";
}

sub msg {
	my ($msg) = @_;
	$d->msgbox( title => 'LVM: snapshot', text => $msg );
	return 1;
}
