package IRP::Icecast;

use IRP::Globals;

sub icecast {
	my $command = shift;
	my $icecast_stats_log = "$IRP::Globals::GLOBAL_icecast_prefix/logs/stats.log";

	return "Command not recognized.\n" unless ($command eq 'who' || $command eq 'uptime');

	my $look_for;
	$look_for = '--- Source ---' if $command eq 'uptime';
	$look_for = '--- Listeners ---' if $command eq 'who';

	## open stats log file and get ready to parse it ##
	open (STATS, $icecast_stats_log) or return undef;
	my @stats = <STATS>;
	close (STATS);

	## parse it ##
	my $recording = 0;
	my @return = ();
	foreach my $line (@stats) {
		if (($line =~ /server uptime/) && $command eq 'uptime') {
			push (@return, $line);
			next;
		}

		if ($line =~ /^Listing sources \((\d+)\):$/) {
			if ($1 ne '1') {
				return "This icecast server is streaming from $1 sources.  I cannot \'$command\'.\n";
			}
		}
			
		unless ($recording) {
			$recording = 1 if ($line =~ /^$look_for$/);
			next;
		}

		if ($command eq 'who') {
		if ($line =~ /^Client.*\[(.*)\] (connected for .*), \d+ bytes.*agent: \[(.*)\]/) {
			my $count = $#return+2;
			push (@return, "$count. $1 - $3\n	$2\n");
		}
		} elsif ($command eq 'uptime') {
		if ($line =~ /^Source.*(\[.*), type:.*/) {
			push (@return, "$1\n");
			last;
		}
		}
	}

	return @return if @return;
	return "No clients connected.\n" if $command eq 'who';
	return "No stream source: radio not up?\n" if $command eq 'uptime';
}

1;
