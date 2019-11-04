#!/usr/bin/perl 
##########################################################################
#  irp.cgi                                             John Sachs        #
#  3/5/2001                                            john@zlilo.com    #
#       CGI interface to the Internet Radio Protocol Daemon              #
#    Released under the GPL  see www.gnu.org for more information        #
##########################################################################

use lib qw(/usr/local/irpd);
use strict;
use URI::Escape qw(uri_escape);
use CGI;
use MP3::Info ();
use File::Basename ();
use Config::IniFiles ();
use IRP::Commands;
use IRP::Files;
use IRP::Globals;
use IRP::Interface;

tie my %irpd_ini, 'Config::IniFiles', (-file=>"/usr/local/irpd/irpd.conf");
IRP::Globals::set_globals(%irpd_ini);
my $max_page_size = $irpd_ini{'cgi'}{'max_page_size'};
my $stream_bitrate = $irpd_ini{'icecast'}{'bitrate'};
my $sample_freq = $irpd_ini{'icecast'}{'sample_frequency'};
my $title = $irpd_ini{'cgi'}{'title'};
my $pls = $irpd_ini{'cgi'}{'pls_url'};
my $site_url = $irpd_ini{'cgi'}{'site_url'};
my $print_time = $irpd_ini{'cgi'}{'print_time'};
my $print_perc = $irpd_ini{'cgi'}{'print_percent'};
my $allow_skip = $irpd_ini{'cgi'}{'allow_skips'};
my $allow_restart = $irpd_ini{'cgi'}{'allow_restart'};
my $allow_replay = $irpd_ini{'cgi'}{'allow_replay'};
my $allow_rand = $irpd_ini{'cgi'}{'allow_rand'};
my $allow_requests = $irpd_ini{'cgi'}{'allow_requests'};
my $bgcolor = $irpd_ini{'cgi'}{'bgcolor'};
my $textcolor = $irpd_ini{'cgi'}{'text'};
my $linkcolor = $irpd_ini{'cgi'}{'link'};
my $vlinkcolor = $irpd_ini{'cgi'}{'vlink'};
untie %irpd_ini;

$|++;
my $version = IRP::Files::get_version();
my $query = new CGI;
my $cgi = $query->url();
my $printedheader = 0;

## setup dispatch table ##
my %actions = (#'show_current' => 'cgi_show_current',
		'show_songs' => 'cgi_show_songs',
		'show_info' => 'cgi_show_info',
		'add_request' => 'cgi_add_request',
		'randomize' => 'cgi_randomize',
		'skip_current' => 'cgi_skip_current',
		'show_list' => 'cgi_show_list',
		'show_top' => 'cgi_show_top',
		'restart_current' => 'cgi_restart_current',
		'_default_' => 'cgi_main_menu'
		);

my $action = $query->param('action');

#printheader() unless $ENV{MOD_PERL};

no strict 'refs';
if ($action) {
	&{$actions{$action}};
} else {
	&{$actions{'_default_'}};
}
use strict 'refs';

sub cgi_main_menu {
	my ($requested, $id, $perc, $filename) = IRP::Files::get_current_info();

	##check to see if server is down##
	if (!defined($id)) {
		server_down();
		return;
	}

	##take care of case where $perc = 100.00##
	while ($perc >= 100.00) {
		($requested, $id, $perc, $filename) = IRP::Files::get_current_info();
	}

	my $name = IRP::Interface::get_name_string($filename);
	my $info = IRP::Interface::get_info_string($filename);

	shift if ($ENV{MOD_PERL} && !$action);
	my $skipped = shift;
	my $skippedid = shift;
	my $skipperc = shift;
	my $sec;
	$sec = IRP::Interface::time_to_reload($perc, $info) unless $skipped;
	$sec = 25 unless $sec;
	my $time_played;
	$time_played = IRP::Interface::get_time_str(1,$perc, $info) if $print_time;
	my $total_time;
	$total_time = IRP::Interface::get_time_str(0,0,$info) if $print_time > 1;
	$perc = sprintf("%.1f", $perc);

	html_head(1, $sec);
	print "<h3>";
	print "skipped: <a href=\"$cgi?action=show_info\&songid=$skippedid\">$skipped</a> ($skipperc\% played)<br>\n" if $skipped;
	print "[<a href=\"$cgi?action=skip_current\">skip</a>] " if $allow_skip;
	print "[<a href=\"$cgi?action=restart_current\">restart</a>] " if $allow_restart;
	print "[<a href=\"$cgi?action=add_request&songid=$id&priority=1\">replay</a>] " if $allow_replay;
	print "current song: <a href=\"$cgi?action=show_info\&songid=$id\&current=1\">$name</a> ";
	if ($print_time) {
		print "[$time_played";
		print " of $total_time" if $print_time > 1;
		print "] ";
	}
	if ($print_perc) {
		print "($perc\%)" unless (sprintf("%.0f", $perc) <= 1);
	}
    print "<br>playing by request.<br>\n" if $requested;
	print "</h3>\n";
	print $info . "<br>\n";
	if ($allow_requests) {
		print "<a href=\"$cgi?action=show_songs\">playlist (request songs)</a> ";
	} else {
		print "<a href=\"$cgi?action=show_list&type=playlist&amount=all\">playlist</a> ";
	}
	print "[<a href=\"$cgi?action=show_top&type=songs&amount=10\">top 10 songs played</a>]<br>\n";
	if ($allow_requests) {
		print "<a href=\"$cgi?action=show_list&type=requests&amount=all\">request queue</a> ";
		print "[<a href=\"$cgi?action=show_top&type=requests&amount=10\">top 10 requests</a>]<br>\n";
	}
	print "<a href=\"$cgi?action=show_list&type=history&amount=$max_page_size\">last $max_page_size songs played</a><br>\n";
	print "<a href=\"$cgi?action=show_top&type=skips&amount=10\">top 10 skips</a><br>\n" if $allow_skip;
	html_foot(1);
}

sub cgi_add_request {
	html_head(1);
	print "<center>\n";
	print "<table border=1>\n";
	print "<tr><th>id</th><th>requested</th><th>status</th></tr>\n";

	foreach my $songid ($query->param('songid')) {
		my $result = IRP::Commands::add_request($songid, ($query->param('priority') && $allow_replay));

		my ($requested, $id, $filename);
		foreach my $line (split /\n/, $result) {
			if ($line =~ /^STATUS\:\s+(.*)$/) {
				$requested = $1;
			} elsif ($line =~ /^IRP SONG ID\:\s+(\d+)$/) {
				$id = $1;
			} elsif ($line =~ /^FILENAME\:\s+(.*)$/) {
				$filename = $1;
			}
		}

		$filename = IRP::Interface::get_name_string($filename) if $filename;
					
		print "<tr><td>$id</td><td><a href=\"$cgi?action=show_info&songid=$id\">$filename</a></td><td>$requested</td></tr>\n";
	}

	print "</table>\n";
	html_foot();
}

sub cgi_skip_current {
	if (!$allow_skip) {
		cgi_main_menu();
		return;
	}

	my ($requested, $songid, $perc, $mp3file) = IRP::Files::get_current_info();
	$mp3file = IRP::Interface::get_name_string($mp3file);
	IRP::Commands::skip_current();
	sleep(1); ## give the streamer time to skip the song ##
	cgi_main_menu($mp3file, $songid, $perc);
}

sub cgi_restart_current {
	if (!$allow_restart) {
		cgi_main_menu();
		return;
	}

	IRP::Commands::restart_current();
	sleep(1);
	cgi_main_menu();
}

sub cgi_show_info {
	my $songid = $query->param('songid') || 0;
	my $current = $query->param('current') || 0;
	my ($title, $song_info);

	if ($current) {
		my ($requested, $cid, $cperc, $file) = IRP::Files::get_current_info();
		$title = IRP::Interface::get_name_string($file);
		$song_info = IRP::Interface::get_info_string($file);
		$song_info .= "<br>currently playing";
        $song_info .= " <b>by request</b>" if $requested;
        $song_info .= ". ($cperc\% complete)\n";
		$song_info .= "<br><strong>[<a href=\"$cgi?action=skip_current\">skip</a>]</strong>\n" if $allow_skip;
	} else {
		my $file;
		my $info = IRP::Commands::show_info($songid);
		foreach my $line (split /\n/, $info) {
			if ($line =~ /^FILENAME\:\s+(.*)$/) {
				$file = $1;
			}
		}

		$title = IRP::Interface::get_name_string($file);
		$song_info = IRP::Interface::get_info_string($file);

        $song_info .= "<br><strong>[<a href=\"$cgi?action=add_request\&songid=$songid\">request</a>]</strong>\n" if $allow_requests;
	}

	html_head($current);
	print "<h3>$title</h3>\n";
	print $song_info;
	html_foot();
}

sub cgi_randomize {
	IRP::Commands::rand_requests();
	cgi_show_list('requests',1,'all');
}

sub cgi_show_list {
	my $type = $query->param('type') || shift;
	my $start = $query->param('first') || shift || 1;
	my $num = $query->param('amount') || shift || $max_page_size;
	my $all = 0;

	#print "type = $type<br>start = $start<br>num = $num<br>all = $all<br>";

	if ($type ne 'requests' && $type ne 'songs' && $type ne 'playlist'
	    && $type ne 'history' && $type ne 'skips') {
		cgi_main_menu();
		return;
	}

	my $list = IRP::Commands::show_list($type);

	html_head(1,60);
	print "<center>\n";

	my @list = split /\n/, $list;
	my $item_count = @list;

	if (!$list || ($item_count<$start)) {
		print "There have been no $type.\n" if ($type eq 'skips' || $type eq 'requests');
		print "There have been no songs played.\n" if ($type eq 'history' || $type eq 'songs');
		html_foot();
		return;
	}

	my $foundsong = 0;
	my $firsttime = 1;

	## turn the list around so it makes sense for requests##
	if ($type eq 'requests') {
		@list = reverse(@list);
	}
	if ($num eq 'all') {
		$num = $max_page_size;
		$all = 1;
	}
	my $rank = $start-1;
	my $loop_count = 0;
	for (my $i=$item_count-$start;($loop_count<$num)&&($item_count>$rank);$i--) {
		next unless $list[$i];
		$loop_count++;
		$rank++;
		my ($id, $item);
		if ($list[$i] =~ /^(\d+).(.*)$/) {
			$id = $1;
			$item = $2;
			$foundsong++;
		} else {
			print STDERR "[cgi_show_list]this item failed to match regexp: $item\n";
			next;
		}

		$item = IRP::Interface::get_name_string($item);

		if ($firsttime) {
			print "<table border=1>\n";
			print "<tr><th>rank</th><th>id</th><th>$type</th></tr>\n";
			$firsttime = 0;
		}

		print "<tr><td align=center>$rank</td><td align=center>$id</td><td><a href=\"$cgi?action=show_info&songid=$id\">$item</a></td></tr>\n";
		
	}
	print "</table>\n";

	if (($start+$num < $item_count) && $all) {
		my $first=$start+$num;
		print "<a href=\"$cgi?action=show_list&type=$type&first=$first&amount=all\">more</a>\n";
	}
	print "no songs in $type list.<br>\n" unless $foundsong;
	print "<br>";
	print "<br><a href=\"$cgi?action=randomize\">randomize request queue</a>" if ($allow_rand && $type eq 'requests' && ($foundsong > 2));
	if ($type ne 'playlist' && $type ne 'songs') {
		if ($allow_requests) {
			print "<br><a href=\"$cgi?action=show_songs\">playlist (request songs)</a><br>\n";
		} else {
			print "<br><a href=\"$cgi?action=show_list&type=playlist&amount=all\">playlist</a><br>";
		}
	}
	html_foot();
}

sub cgi_show_top {
	my $type = $query->param('type');
	my $num = $query->param('amount') || $max_page_size;
	my %playlist_hash = IRP::Files::playlist_hash();

	#print "type = $type<br>num = $num<br>";

	if ($type ne 'requests' && $type ne 'songs' && $type ne 'skips') {
		cgi_main_menu();
		return;
	}

	my $list = IRP::Commands::show_top($num, $type);

	html_head(1);
	print "<center>\n";
	my $foundsong = 0;
	my $firsttime = 1;
	my $count = 0;
	foreach my $item (split /\n/, $list) {
		$count++;
		my ($rank,$id);
		if ($item =~ /^(\d+).(.*)$/) {
			$rank = $1;
			$item = $2;
			$foundsong = 1;
		} elsif ($item =~ /^There have only been (\d+) different/) {
			print $item if $1;
			$count--;
			next;
		} else {
			print STDERR "[cgi_show_top]this item failed to match regexp: $item\n";
			next;
		}

		foreach my $key (sort keys %playlist_hash) {
			if ($playlist_hash{$key} eq $item) {
				$id = $key;
				last;
			}
		}

		$item = IRP::Interface::get_name_string($item);

		if ($firsttime) {
			print "<table border=1>\n";
			print "<tr><th>rank</th><th>times</th><th>$type</th></tr>\n";
			$firsttime = 0;
		}

		print "<tr><td align=center>$count</td><td align=center>$rank</td><td>$item</td></tr>\n" unless $id;
		print "<tr><td align=center>$count</td><td align=center>$rank</td><td><a href=\"$cgi?action=show_info&songid=$id\">$item</a></td></tr>\n" if $id;
		
	}
	print "</table>\n";
	print "<br>no songs in top $type list.<br>\n" unless $foundsong;
	print "<br><br>";
	if ($allow_requests) {
		print "<a href=\"$cgi?action=show_songs\">playlist (request songs)</a><br>\n";
	} else {
		print "<a href=\"$cgi?action=show_list&type=playlist&amount=all\">playlist</a><br>";
	}
	html_foot();
}
	
sub cgi_show_songs {
	if (!$allow_requests) {
		cgi_main_menu();
		return;
	}
    my $start = $query->param('start');
    my $search = $query->param('search') || undef;

	my @playlist = split /\n/, IRP::Commands::show_list('playlist');

    if (defined($search)) {
        my @tmp = ();
        $search =~ s/\s/_/g;
        $search =~ s/[\/\~\!\@\#\$\%\^\&\*\(\)\{\}\[\]\<\>\,\.\?]//g;
        @playlist = () if $search eq '';
        foreach (@playlist) {
            my $current_record = $_;
            $current_record =~ s/\s/_/g;
            if ($current_record =~ /$search/i) {
                push(@tmp, $_);
            }
        }
        @playlist = @tmp;

        if (scalar(@playlist) == 1) {
            if ($playlist[0] =~ /^(\d+)/) {
                print $query->redirect(-uri=>"$cgi?action=show_info&songid=$1");
                return;
            }
        }
    }
    my $next_start = $start + $max_page_size;
    my $previous_start = $start - $max_page_size;
    my $next_args = "start=$next_start";
    my $prev_args = "start=$previous_start";
    if (defined($search)) {
        $next_args .= "&search=$search";
        $prev_args .= "&search=$search";
        $next_args = URI::Escape::uri_escape($next_args);
        $prev_args = URI::Escape::uri_escape($prev_args);
    }

	html_head();
	print "<center>\n";

    ## search textfield ##
    print "<form action=\"$cgi\" method=post>\n";
	print "<input type=hidden name=action value=show_songs>\n";
    print "<input type=text name=search size=20><br>\n";
    print "<input type=submit value=search></form>\n";

    if (defined($search)) {
        my $song_count = scalar(@playlist);
        unless ($song_count > 0) {
            print "<center>search returned no results.</center>\n";
            html_foot();
            return;
        }

        print "<b>$song_count songs</b> in current search list.<br>\n";
    }

    unless ($previous_start < 0) {
        print "<a href=\"$cgi?action=show_songs&$prev_args\">prev</a>\n";
    }
    print "----";
    unless ($next_start >= scalar(@playlist)) {
        print "<a href=\"$cgi?action=show_songs&$next_args\">next</a>\n";
    }

	print "<form action=\"$cgi\" method=post>\n";
	print "<table border=1>\n";
	print "<tr><th>id</th><th>file</th><th>request</th></tr>\n";

    for (my $i = $start ; $i <= $next_start-1 ; $i++) {
        my $s = $playlist[$i];
		if ($s =~ /.*\r$/) {
			chop($s);
		}
		my ($id, $file);
		if ($s =~ /^(\d+).(.*)$/) {
			$id = $1;
			$file = $2;
			$file = File::Basename::basename($file);
			print "<tr><td>$id</td><td><a href=\"$cgi?action=show_info&songid=$id\">$file</a></td><td align=center><input type=checkbox name=songid value=\"$id\"></td></tr>\n";
		}
	}
	print "</table>\n";
	print "<input type=hidden name=action value=add_request>\n";
	print "<br><input type=submit value=\"request selected songs\">&nbsp;<input type=reset value=\"clear selections\">\n";

	print "</form>\n";
    unless ($previous_start < 0) {
        print "<a href=\"$cgi?action=show_songs&$prev_args\">prev</a>\n";
    }
    print "----";
    unless ($next_start >= scalar(@playlist)) {
        print "<a href=\"$cgi?action=show_songs&$next_args\">next</a>\n";
    }
	print "</center>\n";
	html_foot();
}

sub printheader {
	if (!$printedheader) {
		print "Content-type: text/html\n\n";
		$printedheader = 1;
	}
}

sub html_head {
	my $meta_refresh = shift;
	my $sec = shift || 30;

    printheader() unless $ENV{MOD_PERL};
	print "<html><head><title>$title - internet radio protocol v$version</title>\n";
	print "<META HTTP-EQUIV=\"Refresh\" CONTENT=\"$sec; URL=$cgi\">" if $meta_refresh;
	print "</head>\n";
	print "<body bgcolor=$bgcolor text=$textcolor link=$linkcolor vlink=$vlinkcolor>\n";
	print "<center><h1>$title<br><font size=3>[<a href=\"$pls\">listen</a>]</font></h1>\n";
}

sub html_foot {
	my $main = shift;
	print "<br><br><a href=\"$cgi\">main menu</a><br>\n" if !$main;
	print "<p align=center><font size=-2>";
	print "<a href=\"http://zlilo.com/irpd\">";
	print "irpd</a> $version (CGI) by ";
	print "<a href=\"mailto:john\@zlilo.com\">john sachs</a>";
	print "</font></body></html>\n";
}

sub server_down {
	my $info = shift;
	#html_head();
    printheader() unless $ENV{MOD_PERL};
	print "<html><head><title>$title - internet radio protocol v$version</title>\n";
	print "</head>\n";
	print "<body bgcolor=$bgcolor text=$textcolor link=$linkcolor vlink=$vlinkcolor>\n";
	print "<h3><center><center><h1>$title<br></h1>";
	print "<a href=\"$site_url\">$title</a>";
	print " is down for the moment<br>\n";
	print "try back later. ";
	print "($info)" if $info;
	print "<h3>\n";
	html_foot(1);
}
