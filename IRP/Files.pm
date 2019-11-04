##########################################################################
#  irpd_files.pl                                       John Sachs        #
#  3/5/2001                                            john@zlilo.com    #
#         subroutines for manipulating the data files for irpd.          #
#    Released under the GPL  see www.gnu.org for more information        #
##########################################################################
package IRP::Files;

sub create_playlist {
	my $playlist_file = shift;
	my %playlist;

	open (DATA, $playlist_file) or die "failed to open playlist: $!";
	my @file = <DATA>;
	close (DATA);

	my $song_num=0;
	foreach my $line (@file) {
		## skip comments ##
		next if $line =~ /^\#/;
	        $song_num++;
		print "[create_playlist]$song_num $line" if $IRP::Globals::DEBUG>1;
	        $playlist{$song_num} = $line;
	}

	return %playlist;

}	

sub create_internal_playlist_file {
	my $playlist_file = shift;
	#my $internal_playlist_file = shift;
	my %playlist = create_playlist($playlist_file);
	my $song_count = 0;

	open(PLAYLIST, ">$IRP::Globals::GLOBAL_internal_playlist_file") or die "cant create $IRP::Globals::GLOBAL_internal_playlist_file: $!";
	foreach my $key (sort keys %playlist) {
		$song_count++;
		print PLAYLIST "$key$IRP::Globals::GLOBAL_delim$playlist{$key}";
	}
	close(PLAYLIST);

	return $song_count;
}

sub playlist_hash {
	my %playlist_hash;

	open (PLAYLIST, $IRP::Globals::GLOBAL_internal_playlist_file) or die "[playlist_hash] cant open internal playlist file: $!";
	while (<PLAYLIST>) {
		chomp;
		#print "1:$_\n";
		if (/^(\d*)[$IRP::Globals::GLOBAL_delim](.*)$/) {
			#print "[playlist_hash] got playlist_hash[$1] = $2\n";
			$playlist_hash{$1} = $2;
		} else {
			print "[playlist_hash] doom.\n";
		}
	}
	close (PLAYLIST);

	return %playlist_hash;
}

sub get_mp3_file {
	my $song_id = shift || return undef;
	my %playlist = playlist_hash();

	return $playlist{$song_id};
}

sub get_song {
	my $song_num = shift;
	my %pl_hash = @_;

	print "[get_song]getting $pl_hash{$song_num}" if $IRP::Globals::DEBUG;
	my $mp3 = $pl_hash{$song_num};

	return $mp3;
}

##depreciated...not used anywhere...get rid of soon.
sub priority_file_push {
	my $file = shift;
	my $rec = shift;

	`touch $file` unless -e $file;

	open(FILE, $file);
	my @old = <FILE>;
	close(FILE);

	##return false if its already first record.
	##kinda lame but better than adding the same pri req multiple times
	##should add this functionality elsewhere but whatever.
	return 0 if $old[0] eq $rec;

	my $tmp_file = "$file.tmp";
	open(TMP, ">$tmp_file");
	print TMP $rec;

	foreach my $oldrec (@old) {
		print TMP $oldrec;
	}

	close(TMP);

	rename $tmp_file, $file;
	return 1;
}

sub file_push {
	my $file = shift;
	my @rec = @_;

	`touch $file` unless -e $file;

	#lock_file($file);
	open (PUSH, ">>$file") or die "[file_push] doomed: $!";

	foreach my $record (@rec) {
		print STDERR "[file_push] -$file- pushing: $record\n" if $IRP::Globals::DEBUG;
		print PUSH $record;
	}

	close (PUSH);
	#unlock_file($file);
}

sub file_pop {
	my $file = shift;
	my $result = '';

	return undef unless -e $file;

	#lock_file($file);
	open (POP, $file);
	my @file_contents = <POP>;
	close (POP);

	$result = $file_contents[0];

	open (NEW, ">$file");
	for (my $i=1;$file_contents[$i];$i++) {
		print NEW $file_contents[$i];
	}
	close (NEW);
	#unlock_file($file);

	#if ($result =~ /^(\d+)[$IRP::Globals::GLOBAL_delim](.*)$/) {
	#	print STDERR "[file_pop]trimming song id from popped song.\n" if $IRP::Globals::DEBUG;
	#	$result = $2;
	#}
	return $result;
}

sub get_next_song{ 
	my $song;
	my $id;

	print STDERR "[get_next_song]getting next song...\n" if $IRP::Globals::DEBUG;
	##first check priority requests##
	if (-e $IRP::Globals::GLOBAL_priority_request_file) {
		$song = file_pop($IRP::Globals::GLOBAL_priority_request_file);
		if ($song) {
			chomp($song);
			print STDERR "[get_next_song]got priority requested song $song\n" if $IRP::Globals::DEBUG;
			return "1$IRP::Globals::GLOBAL_delim$song";
		}
	}

	##now check regular requests
	if (-e $IRP::Globals::GLOBAL_request_file) {
		$song = file_pop($IRP::Globals::GLOBAL_request_file);
		if ($song) {
			chomp($song);
			print STDERR "[get_next_song]got requested song $song\n" if $IRP::Globals::DEBUG;
			return "1$IRP::Globals::GLOBAL_delim$song";
		}
	}

	#if no requests, get next song (randomly)
	#use internal playlist for continutity
	open(PLAYLIST, $IRP::Globals::GLOBAL_internal_playlist_file);
	my @playlist = <PLAYLIST>;
	close(PLAYLIST);

	while (1) {
		my $new_song = 0;
		$song = $playlist[rand(@playlist)];
		if ($song =~ /^(\d+)[$IRP::Globals::GLOBAL_delim](.*)$/) {
			$id = $1;
			$song = $2;
		}
		print STDERR "[get_next_song]got $song ($1)\n" if $IRP::Globals::DEBUG;

		next if is_in_file($IRP::Globals::GLOBAL_history_file, "$id$IRP::Globals::GLOBAL_delim$song");
		last;
	}

	print STDERR "[get_next_song]good song.  returning.\n" if $IRP::Globals::DEBUG;
	return "0$IRP::Globals::GLOBAL_delim$id$IRP::Globals::GLOBAL_delim$song";
}

sub is_in_file {
	my $file = shift;
	my $song = shift;
	my $is_in_file = 0;

	return undef unless -e $file;

	print STDERR "[is_in_file]opening $file\n" if $IRP::Globals::DEBUG;
	open(FILE, $file);
	my @file = <FILE>;
	close(FILE);

	my $count = @file;
	print STDERR "[is_in_file]$count songs.\n" if $IRP::Globals::DEBUG;

	foreach my $filed_song (@file) {
		chomp $filed_song;
		print STDERR "[is_in_file]comparing:\n\'$song\'\n\'$filed_song\'\n" if $IRP::Globals::DEBUG>1;
		if ($song eq $filed_song) {
			print STDERR "[is_in_file]match.\n" if $IRP::Globals::DEBUG;
			$is_in_file = 1;
			last;
		}
	}

	print STDERR "[is_in_file]no match.\n" if ($IRP::Globals::DEBUG && !$is_in_file);
	return $is_in_file;
}

## returns a list consisting of id, percent complete, filename in that order ##
sub get_current_info {
	my ($requested, $id, $percent, $filename);

	return undef unless -e $IRP::Globals::GLOBAL_current_song;

	open(CURRENT, $IRP::Globals::GLOBAL_current_song);
	my $current_song = <CURRENT>;
	close(CURRENT);

	print STDERR "[get_current_info]got $current_song\n" if $IRP::Globals::DEBUG;

	if ($current_song =~ /^([1|0])[$IRP::Globals::GLOBAL_delim](\d+)[$IRP::Globals::GLOBAL_delim](\d+\.\d+)[$IRP::Globals::GLOBAL_delim](.*)$/) {
        $requested = $1;
		$id = $2;
		$percent = $3;
		$filename = $4;
	} else {
		print STDERR "[get_current_info]allbad: $current_song\n" if $IRP::Globals::DEBUG;
		return undef;
	}

	print STDERR "[get_current_info]returning ($requested, $id, $percent, $filename)\n" if $IRP::Globals::DEBUG;
	return ($requested, $id, $percent, $filename);
}

sub set_current_song {
    my $requested = shift;
	my $current_id = shift;
	my $current_song = shift;
	my $perc_complete = shift;

	print STDERR "[set_current_song]setting current song to $current_song ($current_id).\n" if ($IRP::Globals::DEBUG && $perc_complete eq '0');
	open(CURRENT, ">$IRP::Globals::GLOBAL_current_song") or die "cant open $IRP::Globals::GLOBAL_current_song: $!";
	print CURRENT "$requested$IRP::Globals::GLOBAL_delim$current_id$IRP::Globals::GLOBAL_delim$perc_complete$IRP::Globals::GLOBAL_delim$current_song";
	close(CURRENT);
}

sub add_history {
	my $id = shift;
	my $song = shift;

	print STDERR "[add_history]adding $song to history.\n" if $IRP::Globals::DEBUG;
	trim_file($IRP::Globals::GLOBAL_history_file);
	file_push($IRP::Globals::GLOBAL_history_file, "$id$IRP::Globals::GLOBAL_delim$song\n");

}

sub trim_file {
	my $file = shift;

	return unless -e $file;

	open(TRIM, $file) or die "[trim_file]cant open $file: $!\n";
	my @count = <TRIM>;
	close(TRIM);
	my $count = @count;

	for(my $i=$count;$i>=$IRP::Globals::GLOBAL_max_file_size;$i--) {
		my $trash = file_pop($file);
	}
}

sub count_song {
	my $file = shift;
	my $song = shift;
	my $tmpfile = "$file.tmp";
	my $found = 0;
	my @tmp_array = ();
	my @tmp_array2 = ();
	my $times = 0;

	if (-e $file) {
		open(OLD, $file);
		my @lines = <OLD>;
		close(OLD);
		my $count = 0;

		foreach my $line (@lines) {
			chomp($line);
			if ($line =~ /^(\d+)[$IRP::Globals::GLOBAL_delim](.*)$/) {
				print STDERR "[count_song]$2 weighs in $1 time(s)\n" if $IRP::Globals::DEBUG>1;
				if ($song eq $2) {
					print STDERR "[count_song]matched.  incrementing count.\n" if $IRP::Globals::DEBUG;
					$times = $1 + 1;
					$found = "$times$IRP::Globals::GLOBAL_delim$song\n";
					$count--;
				} else {
					$tmp_array[$count] = "$line\n";
				}
			} else {
				print STDERR "[count_song]this line:\n\'$line\'\nate it.\n";
			}
			$count++;
		}

		if (!$found) {
			print STDERR "[count_song]adding new entry for $song\n" if $IRP::Globals::DEBUG;
			$tmp_array[$count+1] = "1$IRP::Globals::GLOBAL_delim$song\n";
			@tmp_array2 = @tmp_array;
		} else {
			$count = 0;
			my $printed = 0;
			foreach my $line (@tmp_array) {
				if ($line =~ /^(\d+)[$IRP::Globals::GLOBAL_delim](.*)$/) {
					if ($times > $1 && !$printed) {
						print STDERR "[count_song]found song placement...going at index $count in the array.\n" if $IRP::Globals::DEBUG;
						$printed = 1;
						$tmp_array2[$count] = $found;
						$count++;
					}
					$tmp_array2[$count] = $line;
				} else {
					print STDERR "[count_song]this line:\n\'$line\'\nate it (in second loop).\n";
				}
				$count++;
			}
			if (!$printed) {
				print STDERR "[count_song]for some reason, its going at the end of the file.\n" if $IRP::Globals::DEBUG;
				$tmp_array2[$count] = $found;
			}
		}
	} else {
		print STDERR "[count_song]$file not found, creating new one.\n" if $IRP::Globals::DEBUG;
		$tmp_array2[0] = "1$IRP::Globals::GLOBAL_delim$song\n";
	}

	open(NEW, ">$tmpfile");
	foreach my $line (@tmp_array2) {
		print NEW $line if $line;
	}
	close(NEW);

	rename($tmpfile,$file);

}

sub randomize_file {
	my $file = shift;

	print STDERR "[randomize_file]randomizing $file\n" if $IRP::Globals::DEBUG;
	open(FILE,$file) or return; # die "[randomize_file]cant open $file: $!";
	my @array = <FILE>;
	close(FILE);
	my $elements = @array;

	return unless $elements;

	print STDERR "[randomize_file]$elements in array.\n" if $IRP::Globals::DEBUG>1;

	for (my $i = $elements; --$i; ) {
		my $j = int rand ($i+1);
		next if $i == $j;
		print STDERR "[randomize_file]got good random element $j.  swapping with element $i.\n" if $IRP::Globals::DEBUG>1;
		my $temp = $array[$i];
		$array[$i] = $array[$j];
		$array[$j] = $temp;
	}

	open(FILE,">$file");
	foreach my $element (@array) {
		print FILE $element;
	}
	close(FILE);
}

sub get_version {
        #open(VERSION, $IRP::Globals::GLOBAL_version_file);
        #my $ver = <VERSION>;                
        #close(VERSION);
	#chomp($ver);

        #return $ver;
	$IRP::Globals::VERSION;
}

1;
