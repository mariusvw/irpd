package IRP::Interface;

use strict;

sub get_name_string {
	my $mp3file = shift;
	my $mp3tag = MP3::Info::get_mp3tag($mp3file);

	$mp3tag = MP3::Info::get_mp3tag($mp3file,1)
		   if (($mp3tag->{ARTIST} =~ /artist/i)
		     || ($mp3tag->{TITLE} =~ /track/i));
	my $name_string = '';

	if (($mp3tag->{ARTIST} && $mp3tag->{TITLE}) &&
	   ($mp3tag->{ARTIST} !=~ /^\s+$/ && $mp3tag->{TITLE} !=~ /^\s+$/)
	   && !($mp3tag->{ARTIST} =~ /artist/i)) {
		$name_string = $mp3tag->{ARTIST} . " - " . $mp3tag->{TITLE};
	} else {
		$name_string = File::Basename::basename($mp3file);
	}

	return $name_string;
}

## calculates when the song will end based on length given in $info
## and the percent already played given in $perc
sub time_to_reload {
	my ($perc, $info) = @_;
	my ($m,$s);

	foreach my $line (split /\n/, $info) {
		if ($line =~ /(\d+)\s+minutes\,\s+(\d+)\s+seconds/) {
			$m = $1;
			$s = $2;
			last;
		}
	}
	$s = ($m * 60 + $s) * abs($perc / 100 - 1);
	$s = sprintf("%.0f", $s);

	return $s;
}

sub get_time_str {
	my $time_played = shift;
	my $percent = shift;
	my $info = shift;
	my ($m,$s);

	foreach my $line (split /\n/, $info) {
		if ($line =~ /^(\d+)\s+minutes\,\s+(\d+)\s+seconds/) {
			$m = $1;
			$s = $2;
			last;
		}
	}
	if ($time_played) {
		##convert to all seconds and do the math##
		my $all_sec = $m * 60 + $s;
		$time_played = $all_sec * ($percent / 100);
		$time_played = sprintf("%.0f", $time_played);

		##convert back to min:sec##
		$m = $time_played / 60;
		$m = sprintf("%i", $m);
		$s = $time_played % 60;
	}

	$s = "0$s" if (length($s)==1);

	return "$m\:$s";
}
1;

sub get_info_string {
	my $mp3file = shift;
	my $html = shift || 1; ## default to return html (for cgi)
	my $stream_bitrate = shift || 0;
	my $sample_freq = shift || 0;
	my $song_info = '';

	my $mp3tag = MP3::Info::get_mp3tag($mp3file);
	my $mp3info = MP3::Info::get_mp3info($mp3file);
	$mp3tag = MP3::Info::get_mp3tag($mp3file,1)
		if (($mp3tag->{ARTIST} =~ /artist|unkown/i)
		   ||($mp3tag->{TITLE} =~ /track/i));
	$mp3file = File::Basename::basename($mp3file);

	if ($mp3tag && $mp3tag->{ARTIST} &&
			!($mp3tag->{ARTIST} =~ /artist/i ||
			$mp3tag->{ARTIST} =~ /^\s+$/)) {
		$song_info .= "<strong>" if $html;
		$song_info .= $mp3tag->{TITLE};
		$song_info .= "</strong>" if $html;
		if ($mp3tag->{ALBUM}) {
			if ($mp3tag->{TRACKNUM}) {
				$song_info .= " is track " .
					$mp3tag->{TRACKNUM};
			}

			$song_info .= " on ";
			$song_info .= "<strong>" if $html;
			$song_info .= $mp3tag->{ALBUM};
			$song_info .= "</strong>" if $html;

			if ($mp3tag->{YEAR}) {
				$song_info .= " (" . $mp3tag->{YEAR} . ")";
			}
		}

		$song_info .= " by ";
		$song_info .= "<strong>" if $html;
		$song_info .= $mp3tag->{ARTIST};
		$song_info .= "</strong><br>\n" if $html;

	} else {
		$song_info .= "<strong>" if $html;
		$song_info .= "no id3 tag.\n";
		$song_info .= "</strong><br>"if $html;
	}
	if ($mp3info) {
		$song_info .= $mp3info->{MM} . " minutes, " . $mp3info->{SS} .
								"  seconds ";
		$song_info .= $mp3info->{BITRATE} . "kbps ";
		if ($stream_bitrate && 
				($mp3info->{BITRATE} != $stream_bitrate)) {
			$song_info .= "(streaming at $stream_bitrate"."kbps) ";
		}
		$song_info .= $mp3info->{FREQUENCY} . "kHz";
		if ($sample_freq && ($mp3info->{FREQUENCY} != $sample_freq)) {
			$song_info .= " (streaming at $sample_freq"."kHz)";
		}
		$song_info .= "<br>" if $html;
		$song_info .= "\n";
	} else {
		$song_info .= "<strong>" if $html;
		$song_info .= "no file info.\n";
		$song_info .= "</strong><br>";
	}

	return $song_info;
}

