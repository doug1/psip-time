
psip-time
=========

This Perl script reads the PSIP data out of an ATSC (digital TV) MPEG
stream and recovers the current time code from it.  It send the time
to ntpd via a shared memory segment.  It's a little rough still, but
it does work and is within a second of other NTP clocks.

References:

* http://en.wikipedia.org/wiki/ATSC_standards
* http://en.wikipedia.org/wiki/Program_and_System_Information_Protocol
* http://www.scribd.com/doc/56914225/21/The-PSIP-according-to-the-ATSC
* http://www.eecis.udel.edu/~mills/ntp/html/drivers/driver28.html

