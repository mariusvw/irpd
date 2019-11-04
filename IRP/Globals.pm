##########################################################################
#  irpd_globals.pl                                     John Sachs        #
#  3/5/2001                                            john@zlilo.com    #
#                    global variables used in irpd                       #
#    Released under the GPL  see www.gnu.org for more information        #
##########################################################################
package IRP::Globals;

use vars qw($GLOBAL_internal_playlist_file $GLOBAL_delim $GLOBAL_current_song
            $GLOBAL_request_file $GLOBAL_skip_current_file $GLOBAL_history_file
            $GLOBAL_max_file_size $GLOBAL_skip_file $GLOBAL_skip_count
            $GLOBAL_request_count $GLOBAL_play_count $GLOBAL_check_history
            $GLOBAL_restart_current_file $VERSION $GLOBAL_icecast_prefix
            $GLOBAL_last_requested $GLOBAL_priority_request_file $DEBUG);

$VERSION = "1.3";

sub set_globals {
	my %irpd_ini = @_;

	my $prefix = $irpd_ini{'server'}{'prefix'} || '.';

	$DEBUG = $irpd_ini{'debug'}{'debug'} || 0;
	$GLOBAL_icecast_prefix = $irpd_ini{'icecast'}{'installdir'};

	$GLOBAL_delim = '|';
	$GLOBAL_check_history = $irpd_ini{'server'}{'check_history_on_request'};
	$GLOBAL_max_file_size = $irpd_ini{'files'}{'history_file_size'} || 25;
	$GLOBAL_internal_playlist_file = "$prefix/.irpd-internal-files/zrn-irpd_playlist";
	$GLOBAL_current_song = "$prefix/.irpd-internal-files/zrn-irpd_current_song";
	$GLOBAL_request_file = "$prefix/.irpd-internal-files/zrn-irpd_requests";
	$GLOBAL_priority_request_file = "$prefix/.irpd-internal-files/zrn-irpd_priority_requests";
	$GLOBAL_skip_current_file = "$prefix/.irpd-internal-files/.zrn-irpd_skip_current";
	$GLOBAL_restart_current_file = "$prefix/.irpd-internal-files/.zrn-irpd_restart_current";
	$GLOBAL_history_file = "$prefix/.irpd-internal-files/zrn-irpd_play_history";
	$GLOBAL_skip_file = "$prefix/.irpd-internal-files/zrn-irpd_last_skipped";
	$GLOBAL_skip_count = "$prefix/.irpd-internal-files/zrn-irpd_skip_count";
	$GLOBAL_request_count = "$prefix/.irpd-internal-files/zrn-irpd_request_count";
	$GLOBAL_last_requested = "$prefix/.irpd-internal-files/zrn-irpd_last_requested";
	$GLOBAL_play_count = "$prefix/.irpd-internal-files/zrn-irpd_play_count";
	$GLOBAL_version_file = "$prefix/.irpd_release";
}
1;
