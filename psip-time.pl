#!/usr/bin/perl

########################################################################
#
#  ATSC PSIP Time Code Reader
#  Recovers time-of-day from PSIP System Time Table
#
#  This module is free software.  You can redistribute it and/or
#  modify it under the terms of the Artistic License 2.0.
#
#  This program is distributed in the hope that it will be useful,
#  but without any warranty; without even the implied warranty of
#  merchantability or fitness for a particular purpose.
#
########################################################################


use strict;
use warnings;
use Carp qw(cluck);

use Time::HiRes qw( gettimeofday );
use DateTime;
use DateTime::Duration;
use IPC::SysV qw(IPC_PRIVATE IPC_RMID S_IRUSR S_IWUSR);

# Constants
my $IP   = "192.168.1.100";
my $HDHR = "hdhomerun_config";
use constant {
    NTP_SHMID => 0x4e545030,
    INTERVAL  => 60
};

# Globals
my $shmid;
my @median_filter;

########################################################################
#
#  report_timestamp
#
#  Processes a timestamp and sends it to ntpd via shared memory
#
########################################################################

my @timestamps = ();

sub offset
{
    my $array_ref = shift;
    my ( $loc, $rem ) = @{$array_ref};
    return abs( $loc - $rem );
}

sub report_timestamp
{
    my $local_utc  = shift;
    my $remote_utc = shift;

    push @timestamps, [ $local_utc, $remote_utc ];

    if ( scalar @timestamps >= INTERVAL ) {
        ( $local_utc, $remote_utc ) =
          @{ ( sort { offset($a) <=> offset($b) } @timestamps )[ INTERVAL / 2 ]
          };
        my $mode      = 0;
        my $count     = 0;
        my $leap      = 0;
        my $precision = -10;
        my $nsamples  = 0;
        my $valid     = 1;

        my $local_sec  = int($local_utc);
        my $local_usec = ( $local_utc - $local_sec ) * 10**6;

        my $remote_sec  = int($remote_utc);
        my $remote_usec = ( $remote_utc - $remote_sec ) * 10**6;

        my $format  = "ll" . "ql" . "l" . "ql" . "llll" . "l" . "llllllllll";
        my $message = pack( $format,
            $mode,      $count,      $remote_sec,  $remote_usec,
            0,          $local_sec,  $local_usec, $leap,
            $precision, $nsamples,   $valid,       0,
            0,          0,           0,            0,
            0,          0,           0,            0,
            0,          0 );
        my $len = length($message);
        my $ret = shmwrite( $shmid, $message, 0, $len ) || die "$!";
        printf "Sent offset %+0.6f ($len bytes)\n",
          ( $local_utc - $remote_utc );
        die unless ( $len == 96 );    # 64-bit

        @timestamps = ();
    }
}

########################################################################
#
#  process_timestamp
#
########################################################################

my $gps_epoch = DateTime->new(
    year       => 1980,
    month      => 1,
    day        => 6,
    hour       => 0,
    minute     => 0,
    second     => 0,
    nanosecond => 0,
    time_zone  => 'UTC',
);

sub process_timestamp
{
    my $gps_seconds = shift;

    my $dur = DateTime::Duration->new( seconds => $gps_seconds );
    my $remote = $gps_epoch->clone();
    $remote->add_duration($dur);

    my $local_utc  = gettimeofday();
    my $remote_utc = $remote->hires_epoch() + 0.5;

    printf( "%20s  %20s  %+1.6f\n",
        $local_utc, $remote_utc, ( $local_utc - $remote_utc ) );

    report_timestamp( $local_utc, $remote_utc );
}

########################################################################
#
#  main
#
########################################################################

{
    my $buffer  = "";
    my $bufsize = 4096;

    $shmid = shmget( NTP_SHMID, 96, S_IRUSR | S_IWUSR );
    die "shmget: $!" if ( $shmid < 0 );
    print "shm key $shmid\n";

    # Set channel and wait for tuner to lock-on to signal
    system("$HDHR $IP set /tuner0/channelmap us-bcast");
    system("$HDHR $IP set /tuner0/channel auto:30");
    sleep(1);

    # Select program zero and dump binary MPEG
    system("$HDHR $IP set /tuner0/program \"0x0000\" ");
    my $cmd = "$HDHR $IP save /tuner0 - 2>/dev/null";
    open( MPEG, "$cmd |" ) || die $!;

    # Read into the buffer after any bytes from last time
    while ( my $read = read( MPEG, $buffer, $bufsize, pos($buffer) || 0 ) ) {

        # Match 00 cd xx xx 00 00 c1 00 00 00 TT TT TT TT where T is time
        while ( $buffer =~ m|\x00\xcd..\x00{2}\xc1\x00{3}(....)|gc ) {
            my $binary_time = substr( $buffer, ( $-[0] + 10 ), 4 );
            process_timestamp( unpack( "N", $binary_time ) );
        }

        # Slide the unsearched remainder to the front of the buffer.
        my $pos = pos($buffer) || 0;
        substr( $buffer, 0, $pos ) = substr( $buffer, $pos );

    }

    close MPEG;

}

