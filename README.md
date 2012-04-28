
psip-time
=========

This Perl script reads the PSIP data out of an ATSC (North American
Digital TV) stream and recovers the current time code from it.
It then sends the timestamp to ntpd via a shared memory segment.
It's a little rough still, but it does work and and can sync within
a second of other NTP clocks.

References:

* http://en.wikipedia.org/wiki/ATSC_standards
* http://en.wikipedia.org/wiki/Program_and_System_Information_Protocol
* http://www.scribd.com/doc/56914225/21/The-PSIP-according-to-the-ATSC
* http://www.eecis.udel.edu/~mills/ntp/html/drivers/driver28.html

