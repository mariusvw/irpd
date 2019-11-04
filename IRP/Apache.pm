package IRP::Apache;

use strict;
use Apache::Constants qw(:common);

die "not running under mod_perl!" unless $ENV{MOD_PERL};

my ($cgi, $max_page_size, $stream_bitrate, $sample_freq, $title,
    $pls, $site_url, $print_time, $print_perc, $allow_skip, $version,
    $allow_restart, $allow_replay, $allow_rand, $allow_requests,
    $bgcolor, $textcolor, $linkcolor, $vlinkcolor, $lamerfile,
    $lamermsg, $r, $DEBUG);


sub handler {
	$r = shift;

	tie my %irpd_ini, 'Config::IniFiles',
		(-file=>"/usr/local/irpd/irpd.conf");
	IRP::Globals::set_globals(%irpd_ini);
	$max_page_size = $irpd_ini{'cgi'}{'max_page_size'};
	$stream_bitrate = $irpd_ini{'icecast'}{'bitrate'};
	$sample_freq = $irpd_ini{'icecast'}{'sample_frequency'};
	$title = $irpd_ini{'cgi'}{'title'};
	$pls = $irpd_ini{'cgi'}{'pls_url'};
	$site_url = $irpd_ini{'cgi'}{'site_url'};
	$print_time = $irpd_ini{'cgi'}{'print_time'};
	$print_perc = $irpd_ini{'cgi'}{'print_percent'};
	$allow_skip = $irpd_ini{'cgi'}{'allow_skips'};
	$allow_restart = $irpd_ini{'cgi'}{'allow_restart'};
	$allow_replay = $irpd_ini{'cgi'}{'allow_replay'};
	$allow_rand = $irpd_ini{'cgi'}{'allow_rand'};
	$allow_requests = $irpd_ini{'cgi'}{'allow_requests'};
	$bgcolor = $irpd_ini{'cgi'}{'bgcolor'};
	$textcolor = $irpd_ini{'cgi'}{'text'};
	$linkcolor = $irpd_ini{'cgi'}{'link'};
	$vlinkcolor = $irpd_ini{'cgi'}{'vlink'};
    $lamerfile = $irpd_ini{'cgi'}{'lamerfile'};
    $lamermsg = $irpd_ini{'cgi'}{'lamermsg'};
	$DEBUG = $irpd_ini{'debug'}{'debug'};
	untie %irpd_ini;
	$version = IRP::Files::get_version;

    ## deal with lamers ##
    if (-e $lamerfile) {
        my $rip = $r->connection->remote_ip();
        open (LAMER, $lamerfile);
        foreach (<LAMER>) {
            chomp($_);
            if ($rip eq $_) {
                cgi_show_probation($lamermsg);
                return OK;
            }
        }
    }

	### setup dispatch table ##
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
	my $args = $r->args;
	my %arg = $r->args;
	my $action = $arg{'action'};
	$cgi = $r->uri;

	if ($DEBUG) {
		if ($DEBUG > 1) {
			my $req_string = $r->as_string;
			$req_string =~ s|\n|<br>|g;
			$r->print($req_string);
		}
		$r->print("args: $args<br>");
		foreach my $a (sort keys %arg) {
			$r->print("$a = $arg{$a}<br>");
		}
		$r->print("cgi: $cgi<br>");
	}

	no strict 'refs';
	if ($action) {
		$r->print("calling $actions{$action}<br>") if $DEBUG;
		&{$actions{$action}};
	} else {
		$r->print("calling $actions{'_default_'}<br>") if $DEBUG;
		&{$actions{'_default_'}};
	}
	use strict 'refs';
}

sub cgi_main_menu {
	$r->print("in cgi_main_menu (debugging at level $DEBUG)<br>") if $DEBUG;

	my ($requested, $id, $perc, $filename) = IRP::Files::get_current_info();

	##check to see if server is down##
	if (!defined($id)) {
		$r->print("server is down<br>") if $DEBUG;
		server_down();
		return OK;
	}

	##take care of case where $perc = 100.00##
	while ($perc >= 99) {
		 ($requested, $id, $perc, $filename) = IRP::Files::get_current_info();
	}

	my $name = IRP::Interface::get_name_string($filename);
	my $info = IRP::Interface::get_info_string($filename, 1,
						$stream_bitrate, $sample_freq);

	my $skipped = shift;
	my $skippedid = shift;
	my $skipperc = shift;
	my $sec;
	$sec = IRP::Interface::time_to_reload($perc, $info) unless $skipped;
	$sec = 25 unless $sec;
	my $time_played;
	$time_played = IRP::Interface::get_time_str(1,$perc, $info)
							if $print_time;
	my $total_time;
	$total_time = IRP::Interface::get_time_str(0,0,$info)
							if $print_time > 1;
	$perc = sprintf("%.1f", $perc);

	html_head(1, $sec);
	$r->print("<h3>");
	$r->print("skipped: <a href=\"$cgi?action=show_info\&songid=$skippedid\">$skipped</a> ($skipperc\% played)<br>\n") if $skipped;
	#$r->print("playing by request:<br>\n") if $requested;
	$r->print("[<a href=\"$cgi?action=skip_current\">skip</a>] ") if $allow_skip;
	$r->print("[<a href=\"$cgi?action=restart_current\">restart</a>] ") if $allow_restart;
	$r->print("[<a href=\"$cgi?action=add_request&songid=$id&priority=1\">replay</a>] ") if $allow_replay;
	$r->print("current song: <a href=\"$cgi?action=show_info\&songid=$id\&current=1\">$name</a> ");
	if ($print_time) {
		 $r->print("[$time_played");
		 $r->print(" of $total_time") if $print_time > 1;
		 $r->print("] ");
	}
	if ($print_perc) {
		 $r->print("($perc\%)") unless (sprintf("%.0f", $perc) <= 1);
	}
	$r->print("<br>playing by request.<br>\n") if $requested;
	$r->print("</h3>\n");
	$r->print("$info<br>\n");
	if ($allow_requests) {
		 $r->print("<a href=\"$cgi?action=show_songs&start=0\">playlist (request songs)</a> ");
	} else {
		 $r->print("<a href=\"$cgi?action=show_list&type=playlist&amount=all\">playlist</a> ");
	}
	$r->print("[<a href=\"$cgi?action=show_top&type=songs&amount=10\">top 10 songs played</a>]<br>\n");
	if ($allow_requests) {
		 $r->print("<a href=\"$cgi?action=show_list&type=requests&amount=all\">request queue</a> ");
		 $r->print("[<a href=\"$cgi?action=show_top&type=requests&amount=10\">top 10 requests</a>]<br>\n");
	}
	$r->print("<a href=\"$cgi?action=show_list&type=history&amount=$max_page_size\">last $max_page_size songs played</a><br>\n");
	$r->print("<a href=\"$cgi?action=show_top&type=skips&amount=10\">top 10 skips</a><br>\n") if $allow_skip;
	html_foot(1);

	return OK;
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
	} else {
		IRP::Commands::restart_current();
		sleep(1);
		cgi_main_menu();
	}
}

sub cgi_randomize {
	IRP::Commands::rand_requests();
	cgi_show_list('requests',1,'all');
}

sub cgi_add_request {
	$r->print("in cgi_add_request (debug level $DEBUG)<br>") if $DEBUG;
	my %args;
	my @songid;
	if ($r->method eq 'POST') {
		%args = $r->content if $r->method eq 'POST';

		foreach (sort keys %args) {
			push(@songid,$_);
		}
	} else {
		%args = $r->args;
		@songid = $args{'songid'};
	}
	my $priority = $args{'priority'} || 0;
	my $req_str = '';

	html_head(1);
	$r->print(<<END);
<center><table border=1>
<tr><th>id</th>
<th>requested</th>
<th>status</th></tr>
END
	foreach my $songid (@songid) {
		my $result = IRP::Commands::add_request($songid,
				($priority && $allow_replay));

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

		$filename = IRP::Interface::get_name_string($filename);

		$r->print(<<END);
<tr><td>$id</td><td>
<a href="$cgi?action=show_info&songid=$id">$filename</a></td>
<td>$requested</td></tr>
END
	}
	$r->print("</table>");
	html_foot();

	return OK;
}

sub cgi_show_info {
	my %args = $r->args;
	my $songid = $args{'songid'} || 0;
	my $current = $args{'current'} || 0;
	my ($title, $song_info);

	if ($current) {
		my ($requested, $cid, $cperc, $file) = IRP::Files::get_current_info();
		$title = IRP::Interface::get_name_string($file);
		$song_info = IRP::Interface::get_info_string($file, 1,
						$stream_bitrate, $sample_freq);
		$song_info .= "<br>currently playing";
        $song_info .= " <b>by request</b>" if $requested;
        $song_info .= ". ($cperc\% complete)\n";
		$song_info .= "<br><strong>[<a href=\"$cgi?action=skip_current\"
>skip</a>]</strong>\n" if $allow_skip;
	} else {
		my $file;
		my $info = IRP::Commands::show_info($songid);
		foreach my $line (split /\n/, $info) {
			if ($line =~ /^FILENAME\:\s+(.*)$/) {
				$file = $1;
			}
		}

		$title = IRP::Interface::get_name_string($file);
		$song_info = IRP::Interface::get_info_string($file, 1,
						$stream_bitrate, $sample_freq);

		$song_info .= "<br><strong>[<a href=\"$cgi?action=add_request\&songid=$songid\">request</a>]</strong>\n" if $allow_requests;
	}

	html_head($current);
	$r->print("<h3>$title</h3>\n");
	$r->print($song_info);
	html_foot();

	return OK;
}

sub cgi_show_list {
	$r->print("in cgi_show_list (debug level $DEBUG)<br>") if $DEBUG;
	my %args = $r->args;
	my $type = $args{'type'} || shift;
	my $start = $args{'first'} || shift || 1;
	my $num = $args{'amount'} || shift || $max_page_size;
	my $all = 0;

	$r->print("list type: $type<br>") if $DEBUG;
	if ($type ne 'requests' && $type ne 'songs' && $type ne 'playlist'
			&& $type ne 'history' && $type ne 'skips') {
		$r->print("invalid type.<br>") if $DEBUG;
		cgi_main_menu();
		return OK;
	}

	$r->print("calling IRP::Commands::show_list with $type<br>") if $DEBUG;
	my $list = IRP::Commands::show_list($type);

	my @list = split /\n/, $list;
	my $item_count = @list;

	$r->print("$item_count items in the list.<br>") if $DEBUG;

	html_head(1,60);
	$r->print("<center>");

	## if there are no songs in the list, say so and get out ##
	if (!$list || ($item_count<$start)) {
		$r->print("There have been no $type.")
			if ($type eq 'skips' || $type eq 'requests');
		$r->print("There have been no songs played.")
			if ($type eq 'history' || $type eq 'songs');

		html_foot();
		return OK;
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
	if ($DEBUG>=2) {
		$r->print(<<END);
</center>about to start looping with:<br>
item_count: $item_count<br>
start: $start<br>
loop_count: $loop_count<br>
num: $num<br>
rank: $rank<br><center>
END
	}

	for (my $i=$item_count-$start;($loop_count<$num)
				&&($item_count>$rank);$i--) {
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

		if ($DEBUG>=2) {
			$r->print(<<END);
</center>about to start looping with:<br>
item_count: $item_count<br>
start: $start<br>
loop_count: $loop_count<br>
num: $num<br>
rank: $rank<br>
item: $item<br>
firsttime: $firsttime<br><center>
END
		}

		if ($firsttime) {
			$r->print (<<END);
<table border=1>
<tr><th>rank</th>
<th>id</th><th>$type</th></tr>
END
			$firsttime = 0;
		}

		$r->print(<<END);
<tr><td align=center>$rank</td>
<td align=center>$id</td>
<td><a href="$cgi?action=show_info&songid=$id">$item</a></td></tr>
END

	}
	$r->print("</table>");

	if (($start+$num < $item_count) && $all) {
		my $first=$start+$num;
		$r->print(<<END);
<a href="$cgi?action=show_list&type=$type&first=$first&amount=all">more</a>
END

	}
	$r->print("no songs in $type list.<br>") unless $foundsong;
	$r->print("<br>");

	if ($allow_rand && $type eq 'requests' && ($foundsong > 2)) {
		$r->print(<<END);
<br><a href="$cgi?action=randomize">randomize request queue</a>
END
	}
	if ($type ne 'playlist' && $type ne 'songs') {
		if ($allow_requests) {
			$r->print(<<END);
<br><a href="$cgi?action=show_songs&start=0">playlist (request songs)</a><br>
END
		} else {
			$r->print(<<END);
<br><a href="$cgi?action=show_list&type=playlist&amount=all">playlist</a><br>
END
		}
	}
	html_foot();
	return OK;
}

sub cgi_show_top {
	my %args = $r->args;
	my $type = $args{'type'};
	my $num = $args{'amount'};
	my %playlist_hash = IRP::Files::playlist_hash();

	if ($type ne 'requests' && $type ne 'songs' && $type ne 'skips') {
		cgi_main_menu();
		return OK;
	}

	my $list = IRP::Commands::show_top($num, $type);

	html_head(1);
	$r->print("<center>");
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
			$r->print($item) if $1;
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
			$r->print(<<END);
<table border=1>
<tr><th>rank</th><th>times</th><th>$type</th></tr>
END
			$firsttime = 0;
		}

		if ($id) {
			$r->print(<<END);
<tr><td align=center>$count</td>
<td align=center>$rank</td>
<td><a href="$cgi?action=show_info&songid=$id">$item</a></td></tr>
END
		} else {
			$r->print(<<END);
<tr><td align=center>$count</td>
<td align=center>$rank</td>
<td>$item</td></tr>
END
		}
	}
	$r->print("</table>");
	$r->print("<br>no songs in top $type list.<br>") unless $foundsong;
	$r->print("<br><br>");
	if ($allow_requests) {
		$r->print(<<END);
<a href="$cgi?action=show_songs&start=0">playlist (request songs)</a><br>
END
	} else {
		$r->print(<<END);
<a href="$cgi?action=show_list&type=playlist&amount=all">playlist</a><br>
END
	}
	html_foot();
	return OK;
}

sub cgi_show_songs {
	if (!$allow_requests) {
		cgi_main_menu();
		return OK;
	}
    my %args = $r->args;
    if ($r->method eq 'POST') {
        %args = $r->content;
        $args{'start'}=0 unless $args{'start'};
    }
	my @playlist = split /\n/, IRP::Commands::show_list('playlist');
    if (defined ($args{'search'})) {
        my @tmp = ();
        my $search = $args{'search'};
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
                $r->internal_redirect("$cgi?action=show_info&songid=$1");
                return OK;
            }
        }
    }
    my $next_start = $args{'start'} + $max_page_size;
    my $previous_start = $args{'start'} - $max_page_size;
    my $next_args = "start=$next_start";
    my $prev_args = "start=$previous_start";
    if (defined($args{'search'})) {
        $next_args .= "&search=$args{'search'}";
        $prev_args .= "&search=$args{'search'}";
        $next_args = URI::Escape::uri_escape($next_args);
        $prev_args = URI::Escape::uri_escape($prev_args);
    }

	html_head();
	$r->print(<<END);
<center>
<form action="$cgi?action=show_songs" method=post>
<input type=text name=search size=20><br>
<input type=submit value=search></form>
END

    if (defined($args{'search'})) {
        my $song_count = scalar(@playlist);
        unless ($song_count > 0) {
            $r->print("<center>search returned no results.</center>");
            html_foot();
            return OK;
        }

        my $song_noun = 'songs';
        #if ($song_count == 1) {
        #    $song_noun = 'song';
        #}
        $r->print("<b>$song_count $song_noun</b> in current search list.<br>");
    }

    unless ($previous_start < 0) {
        $r->print("<a
            href=\"$cgi?action=show_songs&$prev_args\">prev</a>");
    }
    $r->print("----");
    unless ($next_start >= scalar(@playlist)) {
        $r->print("<a
            href=\"$cgi?action=show_songs&$next_args\">next</a>");
    }

    $r->print(<<END);
<form action="$cgi?action=add_request" method=post>
<table border=1>
<tr><th>id</th><th>file</th><th>request</th></tr>
END

    for (my $i = $args{'start'} ; $i <= $next_start-1 ; $i++) {
        my $s = $playlist[$i];
		if ($s =~ /.*\r$/) {
			chop($s);
		}
		my ($id, $file);
		if ($s =~ /^(\d+).(.*)$/) {
			$id = $1;
			$file = $2;
			$file = File::Basename::basename($file);
#<input type=hidden name=action value=add_request>
			$r->print(<<END);
<tr><td>$id</td><td>
<a href="$cgi?action=show_info&songid=$id">$file</a>
</td><td align=center><input type=checkbox name=$id value=1>
</td></tr>
END
		}
	}
	$r->print(<<END);
</table>
<br><input type=submit value="request selected songs">&nbsp;<input
 type=reset value="clear selections">
</form>
END

    unless ($previous_start < 0) {
        $r->print("<a
            href=\"$cgi?action=show_songs&$prev_args\">prev</a>");
    }
    $r->print("----");
    unless ($next_start > scalar(@playlist)) {
        $r->print("<a
            href=\"$cgi?action=show_songs&$next_args\">next</a>");
    }
    $r->print("</center>");

	html_foot();
}


#sub print_header {
#	## headers ##
#	$r->content_type('text/html');
#	$r->send_http_header;
#}

sub cgi_show_probation {
    my $contentfile = shift;
    my $defaultmsg = "<h3>you are on probabtion</h3>";

    html_head(0);
    if (-e $contentfile) {
        open (CONTENT, $contentfile) or $r->print($defaultmsg);
        foreach (<CONTENT>) {
            $r->print("$_<br>");
        }
    } else {
        $r->print($defaultmsg);
    }
    html_foot(1);
}

sub html_head {
	my $meta_refresh = shift;
	my $sec = shift || 30;

	$r->content_type('text/html');
	$r->send_http_header;

	$r->print("<html><head><title>");
	$r->print("$title - internet radio protocol v$version</title>");
	$r->print("<META HTTP-EQUIV=\"Refresh\" CONTENT=\"$sec; URL=$cgi\">")
			if $meta_refresh;
	$r->print(<<END);
</head>
<body bgcolor=$bgcolor text=$textcolor link=$linkcolor vlink=$vlinkcolor>
<center><h1>$title<br><font size=3>[<a href="$pls">listen</a>]
</font></h1>
END
}

sub html_foot {
	my $main = shift;

	$r->print("<br><br><a href=\"$cgi\">main menu</a><br>\n") unless $main;
	$r->print(<<END);
<p align=center><font size=-2>
<a href="http://zlilo.com/irpd">
irpd</a> $version ($ENV{MOD_PERL}) by
<a href="mailto:john\@zlilo.com">john sachs</a>
</font></body></html>
END
}

sub server_down {
	$r->content_type('text/html');
	$r->send_http_header;
	$r->print(<<END);
<html><head><title>$title - internet radio protocol v$version</title></head>
<body bgcolor=$bgcolor text=$textcolor link=$linkcolor vlink=$vlinkcolor>
<h3><center><center><h1>$title<br></h1>
<a href="$site_url">$title</a> is down for the moment<br>
try back later.</h3>
END

	html_foot();
}

1;
