#!/usr/bin/perl
##
## Pidgin "Online Scheduler" plugin by Davyd McColl, based off of
## Pidgin "Office Hours" plugin by Kev 'Kyrian' Green.
## Many thanks to Kev for his script -- without it, this one would never have been born. I've wanted
##  to create a plugin like this for ages and didn't know where to begin because
##    a) Perl and I are not Best Friends (but I'll dabble for a cause!)
##    b) Pidgin plugin documentation is SHOCKING -- without trawling the web for other plugin
##        scripts, I wouldn't have known how to get things like checkboxes for the preferences dialog
##        -- as much as there are short examples on how to write plugins, there is no proper API documentation
##        and the Perl interface does not mirror the C interface as you would be led to believe -- primarily, 
##        there are different function calls. Not to mention that the C plugin documentation is also quite frugal.
##        At least http://developer.pidgin.im/wiki/Perl_API may give you an idea what to google for...
##      It's really a pity about (b) because Pidgin does provide a lot of power to the plugin programmer -- just
##      that you need a lot of luck, patience and "just try it and see what happens" attitude to figure it all out.
## License:
## Office Hours doesn't mention a licensing scheme -- which kind of leaves it open...
## The Office Hours code I found was at: http://www.orenet.co.uk/opensource/pidgin-oo/. as of writing, the contents
##  of this directory look like:
#[TXT] TODO.txt                09-Oct-2009 12:52  2.7K  
#[TXT] pidgin-office-hours.pl  09-Oct-2009 12:51   11K  
#[TXT] readme.txt              09-Oct-2009 12:52  2.5K  
#Since Kev didn't apply a licence, I'm taking the initiative to apply the BSD license here -- basically, the only
# thing you can't do is claim this code is your own. Neither Kev nor I take any responsibility for any consequences
# (good or bad) that come about as a result of using, reading, thinking about or talking about this plugin. You
# use and associate with this plugin at YOUR OWN RISK. That being said, I'm sure we both hope you find it useful.

use Getopt::Long;
use Purple; # Script barfs if this is not installed, and I can't see how to allow 'help' to work even if it is not installed???
use POSIX; # Needed for mktime() else nothing works.

my $help = undef;
my $rv = GetOptions( 'help|h' => \$help );

## First add a help option to find out what the file does if it's called
## directly. It shouldn't be, but it'd be helpful to have such a thing.
if ($help) {
        print qq|
This is a plugin for Pidgin. Install it in your ~/.pidgin/plugins/ directory
and restart Pidgin.

Don't run this directly, there is no point ;-)
|;
        exit;
}


## Our information structure.
%PLUGIN_INFO = (
    perl_api_version => 2,
    name => 'Online Scheduler', ##  Plugin
    version => '0.2',
    summary => 'Perl plugin to auto-login and auto-logout based on times',
    description => 'Automatically log in and out of all accounts according to week day and time. Useful for shifting your presence from home to work and vice versa.',
    author => 'Davyd McColl <davydm@gmail.com>, credit to Office Hours by Kev Green <kyrian@ore.org> for the starting point',
    url => 'http://code.google.com/p/pidgin-online-scheduler/',
    load => 'plugin_load',
    unload => 'plugin_unload',
    prefs_info => 'plugin_prefs_cb'
);

## How often we 'tick' into active state, not too often, but not too seldom,
## I hope.
#$tick_int_secs = 900; # 15 minutes.
#my $tick_int_secs = 60; # 1 minute, while testing.
#my $tick_int_secs = 300; # 5 minutes, while testing.
my $tick_int_secs = 30;

#$tick_int = $tick_int_secs * 1000; # wtf. is it seconds, miliseconds or what, I can't Google a straight answer!
my $tick_int = $tick_int_secs; # It *is* in seconds.
my $base = "/plugins/core/perl_online_scheduler";

## Start callback.
sub plugin_init {
        return %PLUGIN_INFO;
}

## Close callback.

## Timed/idle callback. It seems this may need to be defined before "plugin_load" (?)
sub plugin_periodic {
  my $plugin = shift;


  my ($sec, $min, $h, $d, $m, $y, $wday, $yday, $isdist) = localtime();

  my $str_min_end = Purple::Prefs::get_int  ($base."/int_min_end");
  my $str_hr_end = Purple::Prefs::get_int   ($base."/int_hr_end");
  my $str_min_start = Purple::Prefs::get_int($base."/int_min_start");
  my $str_hr_start = Purple::Prefs::get_int ($base."/int_hr_start");

  ## Create utility reference times.
  my $end_ux = mktime(0,
    $str_min_end,
    $str_hr_end,
    $d, $m, $y, $wday, $yday);


  my $start_ux = mktime(0,
    $str_min_start,
    $str_hr_start,
    $d, $m, $y, $wday, $yday);

  ## Perhaps we should check that $end_ux, and $start_ux came out
  ## valid here?

  ## Only on weekdays??
  my $disconnect = 0;
  my $start_time = ($str_hr_start * 60) + $str_min_start;
  my $end_time = ($str_hr_end * 60) + $str_min_end;
  my $now_time = ($h * 60) + $min;
  # TODO: add preferences for days of the week instead of just using 0-6
  if ($start_time < $end_time) {
    if (Purple::Prefs::get_bool($base."/bool_wday_".$wday)) {
      ## Then check the time.
      Purple::Debug::info("OnlineScheduler", "weekday ".$wday." IS enabled\n");
      if (($now_time < $start_time)||($now_time > $end_time)) {
        Purple::Debug::info("OnlineScheduler","Running disconnect() due to current time ".$h.":".$min.":".$sec." and online hours being ".$str_hr_start.":".$str_min_start.":00 to ".$str_hr_end.":".$str_min_end.":00\n");
        ## If so, log out any logged-in accounts...
        $disconnect = 1;
      }
    }
    else {
      Purple::Debug::info("OnlineScheduler", "weekday ".$wday." not enabled\n");
    }
  }
  else  # inverted range; use to log on at night and off in the morning
  {
    Purple::Debug::info("OnlineScheduler", "Inverted time range!\n");
    if (Purple::Prefs::get_bool($base."/bool_wday_".$wday)) {
      Purple::Debug::info("OnlineScheduler", "weekday ".$wday." IS enabled\n");
      ## Then check the time.
      if (($now_time < $start_time) && ($now_time > $end_time)) {
        Purple::Debug::info("OnlineScheduler","Running disconnect_all() due to current time ".$h.":".$min.":".$sec." and online hours being ".$str_hr_start.":".$str_min_start.":00 to ".$str_hr_end.":".$str_min_end.":00\n");
        ## If so, log out any logged-in accounts...
        $disconnect = 1;
      }
    }
    else {
      Purple::Debug::info("OnlineScheduler", "weekday ".$wday." not enabled\n");
    }
  }
  if ($disconnect == 1) {
    auto_disconnect();
  } else {
    auto_connect();
  }

  ## Do our stuff here to calculate the next 'wake up' time
  #my $next_secs = 10 * $to_secs_multi; ## We need to calculate this from the timestamp etc.
  my $next_tick = $tick_int;

  ## Wake ourselves up then (timeout/$next_secs is measured in seconds)
  #Purple::Debug::info("OnlineScheduler","Scheduled next tick with interval ".$tick_int.".\n");
  Purple::timeout_add($plugin, $next_tick, \&plugin_periodic, $plugin);

  return FALSE;
}

## "Load me" callback. We check config and set up the initial callback here.
sub plugin_load {
  my $plugin = shift;
  # It doesn't work without a root node for your plugin prefs??
  Purple::Prefs::add_none($base);

  # Start and end hour/min of your online hours.
  Purple::Prefs::add_int($base."/int_hr_start",9);
  Purple::Prefs::add_int($base."/int_min_start", 0);
  Purple::Prefs::add_int($base."/int_hr_end",17);
  Purple::Prefs::add_int($base."/int_min_end", 0);
  foreach (0, 1, 2, 3, 4, 5, 6) {
    Purple::Prefs::add_bool($base."/bool_wday_".$_, 1);
  }
  Purple::Prefs::add_string($base."/str_offline_status", "Offline");
  Purple::Prefs::add_string($base."/str_online_status", "Available");

  Purple::Debug::info("OnlineScheduler","Loaded and Activated Online Scheduler Plugin with interval ".$tick_int.".\n");
  # call the main function; it will reschedule iteself
  plugin_periodic($plugin);

}

# Function to generate the Pidgin preferences screen/tab.
sub plugin_prefs_cb {

  $frame = Purple::PluginPref::Frame->new();

  # @todo verify that re-use of $ppref is OK and doesn't screw things up.
  $ppref = Purple::PluginPref->new_with_label("Set status on these days:");
  $frame->add($ppref);

  %days = (0=>"Sunday", 1 => "Monday", 2 => "Tuesday", 3 => "Wednesday", 4 => "Thursday", 5 => "Friday", 6 => "Saturday");

  foreach (0, 1, 2, 3, 4, 5, 6) {
    $ppref = Purple::PluginPref->new_with_name_and_label($base."/bool_wday_".$_, $days{$_});
    $frame->add($ppref);
  }

  $frame->add(Purple::PluginPref->new_with_label("Come online at:"));
  $ppref = Purple::PluginPref->new_with_name_and_label(
    $base."/int_hr_start", "Hour:");
  $ppref->set_type(3);
  $ppref->set_bounds(0,23);
  $frame->add($ppref);

  $ppref = Purple::PluginPref->new_with_name_and_label(
    $base."/int_min_start", "Minute: ");
  $ppref->set_type(3);
  $ppref->set_bounds(0,59);
  $frame->add($ppref);

  $frame->add(Purple::PluginPref->new_with_label("Go offline at:"));
  $ppref = Purple::PluginPref->new_with_name_and_label(
    $base."/int_hr_end", "Hour:");
  $ppref->set_type(3);
  $ppref->set_bounds(0,23);
  $frame->add($ppref);

  $ppref = Purple::PluginPref->new_with_name_and_label(
    $base."/int_min_end", "Minute:");
  $ppref->set_type(3);
  $ppref->set_bounds(0,59);
  $frame->add($ppref);

  $frame->add(Purple::PluginPref->new_with_label("Set the following statuses:"));
  $ppref = Purple::PluginPref->new_with_name_and_label(
    $base."/str_offline_status", "Offline status:");
  $ppref->set_type(2);
  $frame->add($ppref);


  $ppref = Purple::PluginPref->new_with_name_and_label(
    $base."/str_online_status", "Online status:");
  $ppref->set_type(2);
  $frame->add($ppref);
  
  return $frame;
}

## "Unload me" callback. Shouldn't we do more here to prevent memory leaks etc?
sub plugin_unload {
  my $plugin = shift;
  Purple::Debug::info("OnlineScheduler","Removed Online Scheduler Plugin.\n");
}

## The actual function to perform disconnection of all live accounts, if the callback
## thinks we should.
sub auto_disconnect
{
  my $offline_status = Purple::Prefs::get_string($base."/str_offline_status");
  my $offline = Purple::SavedStatus::find($offline_status) || Purple::SavedStatus::new($offline_status, 1);
  Purple::SavedStatus::activate($offline);
}

sub auto_connect
{
  my $online_status = Purple::Prefs::get_string($base."/str_online_status");
  my $online = Purple::SavedStatus::find($online_status) || Purple::SavedStatus::new($online_status, 2);
  Purple::SavedStatus::activate($online);
}


