use strict;
use lib qw(/usr/local/irpd);
use URI::Escape qw(uri_escape);
use IRP::Commands;
use IRP::Globals;
use IRP::Files;
use IRP::Interface;
use IRP::Apache;
use MP3::Info ();
use Config::IniFiles ();
use File::Basename ();

use vars qw($GLOBAL_internal_playlist_file $GLOBAL_delim $GLOBAL_current_song
            $GLOBAL_request_file $GLOBAL_skip_current_file $GLOBAL_history_file
            $GLOBAL_max_file_size $GLOBAL_skip_file $GLOBAL_skip_count
            $GLOBAL_request_count $GLOBAL_play_count $GLOBAL_check_history
            $GLOBAL_restart_current_file $GLOBAL_version_file
            $GLOBAL_last_requested $GLOBAL_priority_request_file $DEBUG);


1;
