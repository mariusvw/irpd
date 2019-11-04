##########################################################################
#  irpd_commands.pl                                    John Sachs        #
#  3/5/2001                                            john@zlilo.com    #
#        subroutines that the server and CGI call as commands            #
#    Released under the GPL  see www.gnu.org for more information        #
##########################################################################
package IRP::Commands;

sub show_help {
 my $topic = shift;
 my $helptext = "IRPD HELP\r\n";
 print "topic: $topic\r\n" if defined($topic);
 if (!$topic) {
  $helptext .= "
Available commands:\r
auth		current		info		list\r
played		reload		request		requests\r
requested	skip		skips		skipped\r
songs		help		quit		top\r\n";
 } elsif ($topic eq 'auth') {
  $helptext .= "AUTH\r\n
usage: auth\r\n
The auth command in IRP works exactly like AUTH LOGIN for SMTP.\r
Upon receiving the AUTH command, the server will issue a base64 encoded\r
request for a username, and expect a base64 encoded username back.\r
Then the server will issue a base64 encoded request for a password and\r
expect a base64 encoded password back.  Upon successful authentication,\r
the user will have access to admin commands.\r\n";
 } elsif ($topic eq 'current') {
  # current help
  $helptext .= "CURRENT\r\n
usage: current\r\n
Displays information for the currently playing song.\r
This is exactly like using the \'info\' command with no arguments.\r\n";
 } elsif ($topic eq 'info') {
  # info help
  $helptext .= "INFO\r\n
usage: info [song id]\r\n
Displays file information and ID3 tag for the specified song id.  If no\r
song id is given, information for the currently playing song\r
will be displayed\r\n";
 } elsif ($topic eq 'list') {
  $helptext .= "LIST\r\n
usage: list [songs requests skips history]
This command will display a list based on the specified parameter.\r
If no parameter is specified, \'songs\' is the default and the playlist\r
is displayed.  The \'requests\' parameter displayes the request queue,\r
\'skips\' displays the last $IRP::Globals::GLOBAL_history_num songs skipped and\r
\'history\' displays the last $IRP::Globals::GLOBAL_history_num songs played.\r\n";
 } elsif ($topic eq 'songs' || $topic eq 'playlist' || $topic eq 'requests' ||
          $topic eq 'skips' || $topic eq 'history') {
  $helptext .= "PLAYLIST SONGS REQUESTS SKIPS HISTORY\r\n
usage: playlist songs requests skips history\r\n
These are all aliases for \'list x\'.  \'playlist\' is an alias for\r
\'list songs\'.  The rest are pretty self explanatory.\r\n";
 } elsif ($topic eq 'reload') {
  # reload help
  $helptext .= "RELOAD\r\n
usage: reload\r\n
Reloads the playlist.  Must have administrator priveleges.\r\n";
 } elsif ($topic eq 'request') {
  # request help
  $helptext .= "REQUEST\r\n
usage: request <song id>\r\n
This command will add the song corresponding to the song id specified to the\r
request queue.  Song ID is a required parameter.\r\n";
 } elsif ($topic eq 'requests') {
  # requests help
  $helptext .= "REQUESTS\r\n
usage: requests\r\n
Displays the request queue.  An alias for \'list requests\'.\r\n";
 } elsif ($topic eq 'skip') {
  # skip help
  $helptext .= "SKIP\r\n
usage: skip
Skips the currently playing song and adds the song to the skipped list.\r
Must have administrator priveleges.\r\n";
 } elsif ($topic eq 'help') {
  $helptext .= "HELP\r\n
usage: help or ?\r\n
Duh.\r\n";
# } elsif ($topic eq 'set') {
  # set help
 } elsif ($topic eq 'quit') {
  $helptext = "QUIT\r\n
usage: quit\r\n
Disconnect from the server.\r\n";
 } elsif ($topic eq 'top') {
  $helptext = "TOP\r\n
usage: top <number> [songs requests skips]\r\n
This command returns the top <number> of the requested song type.\r
The first argument must be numeric and is the number of songs you\r
want to see.  The second argument is optional and defaults to \'songs\'.\r
Example on how to use this command:\r
If you wanted to see the top 10 songs requested, issue the command\r
\'top 10 requests\'.  If you wanted to see the top 25 songs skipped,\r
issue the command \'top 25 skips\'.  If you want to see the top 5 songs\r
played on the server, issue \'top 5\'.\r\n";
 } elsif ($topic eq 'skipped' || $topic eq 'played' || $topic eq 'requested') {
  $helptext = "SKIPPED PLAYED REQUESTED\r\n
usage: skipped played requested\r\n
These three commands are aliases for \'top 10 x\'.  So, \'skipped\'\r
is the same as saying \'top 10 skips\', \'played\' is equivalent\r
to \'top 10 songs\', and \'requested\' is the same as \'top 10 requests\'.\r\n";
 } else {
  $helptext = "No help on that topic.\r\n";
 }
 return $helptext;
}

#sub auth {
# my $auth_ip = shift;
#
#}

sub show_current {
 open(CUR,$IRP::Globals::GLOBAL_current_song);
 my $current_song = <CUR>;
 close(CUR);

 return "$current_song\r\n";
}

sub show_info {
 my $song_id = shift;
 my $fail_string = "\rNo ID3 tag for song $song_id\r\n";

# if (!$song_id || $song_id eq "\n") {
#   $song_id = show_current();
#   if ($song_id =~ /^(\d*)[$IRP::Globals::GLOBAL_delim].*/) {
#     $song_id = $1;
#   } else {
#     return $fail_string;
#   }
# }

 my ($id, $perc, $mp3_file);
 if (!$song_id || $song_id eq "\n") {
  my @current = IRP::Files::get_current_info();
  $requested = $current[0];
  $song_id = $current[1];
  $perc = $current[2];
  $mp3_file = $current[3];
 } else {
  $mp3_file = IRP::Files::get_mp3_file($song_id);
 }
 return $fail_string unless $mp3_file;
 my $mp3 = MP3::Info::get_mp3info($mp3_file);
 my $info_string = "IRP SONG ID: $song_id\nFILENAME: $mp3_file\n";
 $info_string .= "PERCENT COMPLETE: $perc\n" if $perc;

 if ($mp3) {
   foreach my $key (sort keys %{$mp3}) {
     #print "[show_info] got $key: $mp3->{$key}\n";
     $info_string .= "$key: $mp3->{$key}\n" if $mp3->{$key};
    }
 } else {
   $info_string .= "No mp3 file info.\n";
 }

 $mp3 = MP3::Info::get_mp3tag($mp3_file);

 if ($mp3) {
   foreach my $key (sort keys %{$mp3}) {
     #print "[show_info] got $key: $mp3->{$key}\n";
     $info_string .= "$key: $mp3->{$key}\n" if $mp3->{$key};
    }
 } else {
   $info_string .= "No ID3 tag.\n";
 }

 return $info_string;
}

sub show_playlist {
 my $playlist = shift;

 open(LIST,$IRP::Globals::GLOBAL_internal_playlist_file);
 my @list = <LIST>;
 close(LIST);
 my $list_string = '';

 foreach my $song (@list) {
   $list_string .= "$song\r";
 }

 return $list_string;
}

sub show_list {
 my $list_type = shift;
 my ($list_string, @list_file) = ('',());;

 if (!$list_type || $list_type eq 'songs' || $list_type eq 'playlist') {
   $list_file[0] = $IRP::Globals::GLOBAL_internal_playlist_file;
 } elsif ($list_type eq 'requests') {
   $list_file[0]= $IRP::Globals::GLOBAL_priority_request_file;
   $list_file[1] = $IRP::Globals::GLOBAL_request_file;
 } elsif ($list_type eq 'skips') {
   $list_file[0] = $IRP::Globals::GLOBAL_skip_file;
 } elsif ($list_type eq 'history') {
   $list_file[0] = $IRP::Globals::GLOBAL_history_file;
 } else {
   return "Invalid LIST type.  Valid types: songs, requests, skips, history.\n";
 }

 foreach my $lfile (@list_file) {
  open(LIST,$lfile);
  my @list = <LIST>;
  close(LIST);
                    
  foreach my $song (@list) {
    $list_string .= $song;
  }
 }

 return $list_string;
}

sub skip_current {
	print STDERR "[skip_current]skipping current song.\n" if $IRP::Globals::DEBUG;
	my ($request, $id, $perc, $song) = IRP::Files::get_current_info();
	IRP::Files::trim_file($IRP::Globals::GLOBAL_skip_file);
	IRP::Files::file_push($IRP::Globals::GLOBAL_skip_file, "$id$IRP::Globals::GLOBAL_delim$song\n");

	open(SKIP,">$IRP::Globals::GLOBAL_skip_current_file")
		or die "[skip_current]cant open $IRP::Globals::GLOBAL_skip_current_file: $!";
	close(SKIP);

	IRP::Files::count_song($IRP::Globals::GLOBAL_skip_count, $song);
}

sub restart_current {
	print STDERR "[restart_current]restarting current song.\n" if $IRP::Globals::DEBUG;
	open(RESTART, ">$IRP::Globals::GLOBAL_restart_current_file");
	close(RESTART);
}

sub rand_requests {
	IRP::Files::randomize_file($IRP::Globals::GLOBAL_request_file);
}

sub add_request {
	my $req_id = shift;
	my $priority_request = shift || 0;
	my $bad_id_str = "Invalid Song ID.\n";

	return $bad_id_str if !($req_id =~ /^\d+$/);

	my %playlist = IRP::Files::playlist_hash();
	my $request = $playlist{$req_id};

	if (!$request) {
		print STDERR "[add_request]bad song id.\n" if $IRP::Globals::DEBUG;
		return "STATUS: NOT REQUESTED (Bad song ID.)\n";
	}

	print STDERR "[add_request]got request $request\n" if ($IRP::Globals::DEBUG && !$priority_request);
	print STDERR "[add_request]got PRIORITY request $request\n" if ($IRP::Globals::DEBUG && $priority_request);

	my $song_info = show_info($req_id);

	if (!$priority_request) {
		##check to see if the song is currently playing##
		my @current_info = IRP::Files::get_current_info();
		my ($cur_song, $perc);

		$cur_song = "$current_info[0]$IRP::Globals::GLOBAL_delim$current_info[2]";
		$perc = $current_info[2];

		if ("$req_id$IRP::Globals::GLOBAL_delim$request" eq $cur_song) {
			print STDERR "[add_request]current song.\n" if $IRP::Globals::DEBUG;
			my $return_str = "STATUS: NOT REQUESTED (Currently playing.)\n";
			$song_info = show_info();
			return "$return_str$song_info";
		}

		##check to see that the song is not in the priority requests##
		if (IRP::Files::is_in_file($IRP::Globals::GLOBAL_priority_request_file, "$req_id$IRP::Globals::GLOBAL_delim$request")) {
			print STDERR "[add_request]already requested (priority).\n" if $IRP::Globals::DEBUG;
			my $return_str = "STATUS: NOT REQUESTED (Already in request queue.)\n";
			return "$return_str$song_info";
		}

		##check to see that the song is not in the request queue##
		if (IRP::Files::is_in_file($IRP::Globals::GLOBAL_request_file, "$req_id$IRP::Globals::GLOBAL_delim$request")) {
			print STDERR "[add_request]already requested.\n" if $IRP::Globals::DEBUG;
			my $return_str = "STATUS: NOT REQUESTED (Already in request queue.)\n";
			return "$return_str$song_info";
		}

		##optionally check to see if the song is in the recent history##
		if ($IRP::Globals::GLOBAL_check_history) {
			print STDERR "[add_request]checking history.\n" if $IRP::Globals::DEBUG;
			if (IRP::Files::is_in_file($IRP::Globals::GLOBAL_history_file, "$req_id$IRP::Globals::GLOBAL_delim$request")) {
				print STDERR "[add_request]request in history.\n" if $IRP::Globals::DEBUG;
				my $return_str = "STATUS: NOT REQUESTED (Played in last $IRP::Globals::GLOBAL_max_file_size songs.)\n";
				return "$return_str$song_info";
			}
			print STDERR "[add_request]not in history.\n" if $IRP::Globals::DEBUG;
		}

		IRP::Files::file_push($IRP::Globals::GLOBAL_request_file, "$req_id$IRP::Globals::GLOBAL_delim$request\n");
	} else {
		##deal with priority request##
		if (IRP::Files::is_in_file($IRP::Globals::GLOBAL_priority_request_file, "$req_id$IRP::Globals::GLOBAL_delim$request")) {
			print STDERR "[add_request]already in priority request queue.\n" if $IRP::Globals::DEBUG;
			return "STATUS: NOT REQUESTED. (Already in priority request queue.)\n$song_info";
		} else {
			IRP::Files::file_push($IRP::Globals::GLOBAL_priority_request_file, "$req_id$IRP::Globals::GLOBAL_delim$request\n");
		}
	}

	IRP::Files::trim_file($IRP::Globals::GLOBAL_last_requested);
	IRP::Files::file_push($IRP::Globals::GLOBAL_last_requested, "$req_id$IRP::Globals::GLOBAL_delim$request\n");

	IRP::Files::count_song($IRP::Globals::GLOBAL_request_count, $request);

	return "STATUS: PRIORITY REQUESTED.\n$song_info" if $priority_request;
	return "STATUS: REQUESTED.\n$song_info";
}

sub show_top {
	my $number = shift;
	my $song_type = shift;
	my $song_file;
	my $return_str = '';

	$song_file = $IRP::Globals::GLOBAL_skip_count if $song_type eq 'skips';
	$song_file = $IRP::Globals::GLOBAL_request_count if $song_type eq 'requests';
	$song_file = $IRP::Globals::GLOBAL_play_count if (!$song_type or $song_type eq 'songs');
	if (!$song_file) {
		print STDERR "[show_top]bad song_type \'$song_type\' passed.\n" if $IRP::Globals::DEBUG;
		return show_help('top');
	}

	print STDERR "[show_top]song_file is $song_file.\n" if $IRP::Globals::DEBUG;

	open(SONGS, $song_file) or print STDERR "[show_top]could not open: $!\n";
	my @songs = <SONGS>;
	close(SONGS);
	my $song_count = @songs;

	if ($song_count <= $number) {
		print STDERR "[show_top]returning the entire file.\n" if $IRP::Globals::DEBUG;
		if ($song_count < $number) {
			print STDERR "[show_top]only $song_count songs in file.\n" if $IRP::Globals::DEBUG;
			$return_str = "There have only been $song_count different songs ";
			$return_str .= "requested.\n" if $song_type eq 'requests';
			$return_str .= "skipped.\n" if $song_type eq 'skips';
			$return_str .= "played.\n" if (!$song_type or $song_type eq 'songs');
		}
		foreach my $line (@songs) {
			$return_str .= $line;
		}
	} else {
		for(my $i=0;$i<$number;$i++) {
			print STDERR "[show_top]adding $songs[$i]" if $IRP::Globals::DEBUG;
			$return_str .= $songs[$i];
		}
	}
	return $return_str;
}
			
sub authenticated {
	print STDERR "[authenticated]everyone is right now.\n" if $IRP::Globals::DEBUG;
	return 1;
}

sub auth_first {
	return "athenticate first.\n";
}

sub auth {
	print STDERR "[auth]authenticating everyone today.\n" if $IRP::Globals::DEBUG;
	print "ok authenticated.\n";
}
1;
