# ZRN IRPD
The zlilo.com radio network Internet Radio Protocol Daemon

John Sachs (john@zlilo.com)                                       3/2/2001

IRPD is an internet radio station playlist manager and mp3 streamer.  It streams to icecast servers, so you need a working icecast server.  IRPD is available at http://zlilo.com/irpd/.

The idea for irpd is based on Streamcast (ftp.cheapnet.net/pub/streamcast) by Mike Machado (mike@innercite.com), but irpd is a complete rewrite and i believe it includes many useful features that Streamcast cannot implement in its current state. (most notably allowing multiple connections to the server and updating each session realtime).

The multi-threaded server/socket code was take from Perl-esmtpd-0.6 (http://sourceforge.net/projects/perl-esmtpd/) by John M. Hanna.  (You'll recognize the sub routine names...heh.. good code, thanks!)

The features of irpd include:
- on-the-fly mp3 reencoding using either lame or gogo (with mpg123)
- allows song requests
- allows skip current song
- keeps track of play/skip/request history
- configurable recent history file size
- will not replay songs in recent history
- statistics on top songs played/skipped/requested
- a multi-threaded server makes it possible for anyone to create an irp client
- cgi interface
- conf file that makes it easy to configure

Several perl modules are required to run irpd.  These are:
libshout-perl and libshout (both at http://cvs.icecast.org)
`MP3::Info, URI::Escape, File::Basename, Config::IniFiles`
(all available at cpan.org)
The CGI obviously uses CGI...which you probably already have.

If you want re-encoding, you must also have a compatible encoder.  Currently lame and gogo are the supported ones.  If you use gogo (which i recommend), you need mpg123 to do the decoding.
gogo (http://freshmeat.net/redir/gogo/3613/url_tgz/gogo239b.tgz)
lame (http://www.sulaco.org/mp3/download/download.html)
mpg123 (http://freshmeat.net/redir/mpg123/6732/url_tgz/mpg123-0.59r.tar.gz)


## Configuration
Simply edit the irpd.conf file.  The entries are as follows:
```
[debug]
debug=0
```
The debug level.  Default is 0.  1 is normal debug messages, higher numbers produce more output.

```
[files]
history_file_size=25
```
The max number of entries in all the history files.  This means no songs will be replyed in at least this many songs.

```
playlist=
```
The full path to your playlist file.  Simply a file containing fully qualified paths to your mp3s on each line.  A simple way to create a playlist file is with the find command: `find /path/to/mp3 -name \*.mp3 > /path/to/playlist`

```
[server]
prefix=/usr/local/irpd
```
The full path to your installation directory.  If you just install in `/usr/local/irpd`, you can leave this alone.

```
check_history_on_request=1
```
Option to check the recent history file when a user requests a song.  If set to 1, the request will not be allowed if the file has been played in the last `<history_file_size>` songs.

```
run_as_user=nobody
```
The user to run your server as.  Must be started as root, but it will change to this user after it sets up.

```
log_file=irpd.log
```
The name of the file to log to.  This file will be created in `<prefix>`.

```
loglevel=1
```
The level of logging you want in your log file.  Currently, only supports 1 or 2.  Defaults to 1.  2 gives you a few more details about whats going on with each song.

```
port=4669
```
The port number for your server to listen on.

```
interface=127.0.0.1
```
The interface you want it to listen on.

```
banner=http://zlilo.com/zrn
```
Any URL or message you want displayed when someone connects to the server.

```
prompt_char=>
```
The prompt character the server returns when it is waiting for a command. You can leave this as is.

```
enable_skip=1
```
Enable/disable the skip command from a server session *does not affect cgi option! 0 is disable, 1 is enable.

```
enable_replay=1
```
Enable/disable the replay command from a server session *does not affect cgi option! 0 is disable, 1 is enable.

```
enable_restart=1
```
Enable/disable the restart command from a server session *does not affect cgi option! 0 is disable, 1 is enable.

```
enable_rand=1
```
Enable/disable the randomize command (to randomize the request queue) from a server session *does not affect cgi option!  0 is disable, 1 is enable.

```
enable_requests=1
```
Enable/disable requesting functionality from a server session *does not affect cgi option! 0 is disable, 1 is enable.

```
enable_priority_requests=1
```
Enable/disable the priority requesting functionality from a server session.

```
[icecast]
server=
```
The server name where the icecast server is running. Do not use 'localhost' if it is on the same host, use the dns entry for your host.

```
port=8000
```
The icecast port to connect to.

```
mountpoint=/zrn
```
The icecast mountpoint.

```
password=
```
The password needed to connect to icecast server.

```
name=zrn irpd
```
The name icecast will display as the name of your stream.

```
url=http://zlilo.com/zrn
```
The URL the icecast server will send to clients on connect (this is the URL winamp clients see in their little winamp mini browser... should point this to the location of your CGI if you use it.)

```
genre=
```
The genre icecast will report for your stream.

```
public=
```
Tells icecast to make your stream public or not. 1 is public, 0 is not.

```
bitrate=
```
The bitrate to stream as.  This is an important setting, because if you enable reencoding, any mp3s that are not encoded at this rate will be reencoded to this rate.  If you do not enable reencoding, any mp3s that are not encoded at this rate will be skipped. (streaming mp3s at the wrong rate just sounds bad.)

```
sample_frequency=44.1
```
The sample frequency of the stream. This will be auto on files that do not need reencoding. This setting is mainly for the reencoders. I suggest you leave this at 44.1, but if you know what value you want here, you can set it.

```
reencode=1
```
Re-encode mp3s that do not match bitrate. 1 is yes, 0 is no. if 0, mp3s that do not have a bitrate matching `<bitrate>` will be ignored.

```
reencoder=gogo
```
This is the program that does the reencoding.  The options are `'lame'` or `'gogo'`. I recommend gogo as it is a little more efficient and uses less system resources. If you use gogo, however, you must also have mpg123 to decode the stream. lame has mpg123 built in. all the binaries must exist in your path.

```
[cgi]
title=
```
The name of your station as the CGI should display it.

```
pls_url=
```
The URL of your `.pls` file which will be used to allow people to listen to your station.

```
site_url=
```
Any URL you'd like for your home page, website root url, etc.

```
print_percent=1
```
This is purely aesthetics, personal preference. If set to 1, the percent played will be displayed after the song name on the cgi main page. If set to 0, no percent will be displayed.

```
print_time=2
```
This is more aesthetics. There are three options for this setting: 0, 1, or 2. If set to 1, the time of the song thats been played so far will be displayed after the song name on the main page.  If set to 2, it will also include the total time like this: `"[1:27 of 3:48]"`. If set to 0, no time will be displayed.

```
allow_skips=1
```
Allow users to skip songs using the CGI. 1 is yes, 0 is no. The server setting has no effect on disabling or enabling this functionality in the CGI.

```
allow_request=1
```
Allow users to request songs via the CGI. 1 is yes, 0 is no. This works regardless of whether it is disabled in the server or not.

```
allow_restart=1
```
Allow users to restart the current song via the CGI. 1 is yes, 0 is no. This works regardless of whether it is disabled in the server or not.

```
allow_replay=1
```
Allow users to replay (priority request) the current song via the CGI. 1 is yes, 0 is no. This works regardless of whether it is disabled in the server or not.

```
allow_rand=1
```
Allow users to randomize the request queue via the CGI. 1 is yes, 0 is no. This works regardless of whether it is disabled in the server or not.

```
max_page_size=20
```
The number of lines (songs) to show on one page.

```
bgcolor=black
test=yellow
link=red
vlink=red
```
The colors the CGI will use. Match this to the rest of your site or whatever.


## Usage
Once you have the conf file the way you want it and you have a playlist, you are ready to start up irpd. Simply run the zrn-irpd executable perl script. It should start up and fade into the the background. You can now connect to the icecast/streamcast url with your mp3 player and should hear your streaming station.

To test out the server, telnet to the host irpd is running on at the port the server is configured for (4669). You should see your banner and the prompt. You can now issue commands and get responses from the server.

## Available commands are:

```
auth
current
info
list
played
reload
request
requests
requested
skip
skips
skipped
songs
help
quit
top
```

### auth
The auth command in IRP works exactly like AUTH LOGIN for SMTP.
Upon receiving the AUTH command, the server will issue a base64 encoded
request for a username, and expect a base64 encoded username back.
Then the server will issue a base64 encoded request for a password and
expect a base64 encoded password back.  Upon successful authentication,
the user will have access to admin commands.
*NOTE: this is all a good idea and everything, but 'auth' is currently not doing much of anything.  Hopefully soon, you will be able to authenticate and only issue certain commands if you are authenticated.

### current
Displays information for the currently playing song.
This is exactly like using the 'info' command with no arguments.

### info [song id]
Displays file information and ID3 tag for the specified song id.  If no
song id is given, information for the currently playing song
will be displayed

### list [songs requests skips history]
This command will display a list based on the specified parameter.
If no parameter is specified, 'songs' is the default and the playlist
is displayed.  The 'requests' parameter displayes the request queue,
'skips' displays the last  songs skipped and
'history' displays the last  songs played.

### skipped played requested
These three commands are aliases for 'top 10 x'.  So, 'skipped'
is the same as saying 'top 10 skips', 'played' is equivalent
to 'top 10 songs', and 'requested' is the same as 'top 10 requests'.

### reload
Reloads the playlist.  Must have administrator priveleges.
*Everyone has administrator priveleges right now*

### request <song id>
This command will add the song corresponding to the song id specified to the
request queue. Song ID is a required parameter.

### playlist songs requests skips history
These are all aliases for `'list x'`. `'playlist'` is an alias for
`'list songs'`. The rest are pretty self explanatory.

### skip
Skips the currently playing song and adds the song to the skipped list.

### quit
Disconnect from the server.

### top <number> [songs requests skips]
This command returns the top `<number>` of the requested song type.
The first argument must be numeric and is the number of songs you
want to see. The second argument is optional and defaults to `'songs'`.

Example on how to use this command:
If you wanted to see the top 10 songs requested, issue the command
'top 10 requests'. If you wanted to see the top 25 songs skipped,
issue the command 'top 25 skips'. If you want to see the top 5 songs
played on the server, issue 'top 5'.


## *undocumented features*
These are features not in the help list...may or may not want users to know about them:

`'restart'` will restart the current song.
[cgi] section of the conf cile allows for 'allow_restart'.  if set to 1, users can restart the song via the cgi.

`'rand'` or `'randomize'` will randomize the request queue.

`'prequest <song id>'` will add a priority request (request a song that will be bumped to the top of any existing request queue).  priority requests are in their own queue and will not be randomized with the regular requests with the 'randomize' command.

`'replay'` is a priority request for the current song.
`[cgi]` section of the conf file allows for `'allow_replay'`.  if set to 1, users can add priority request of current song via the cgi.
