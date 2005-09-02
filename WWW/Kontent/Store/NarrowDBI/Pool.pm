=head1 NAME

WWW::Kontent::Store::NarrowDBI::Pool - no user servicable parts inside

=head1 DESCRIPTION

This module contains the Pool implementation for NarrowDBI; see 
L<WWW::Kontent::Store::NarrowDBI> for details on NarrowDBI's behavior.

=cut

class WWW::Kontent::Store::NarrowDBI::Pool is WWW::Kontent::Pool {
	has $.module;
	has %:sth;
	
	submethod BUILD($.module, %:sth) {}
	
	method read(Str $key) returns Str {
		%:sth<getpooldata>.execute($.module, $key);
		my $r=%:sth<getpooldata>.fetchrow_arrayref;
		if $r {
			return ~$r[0];
		}
		else {
			return;
		}
	}
	
	method add(Str $key, Str $value, Num ?$time = time) returns Void {
		%:sth<addpooldata>.execute($.module, $key, $value, $time) == 1
			|| WWW::Kontent::error("Tried to add existing pool key '$key': %:sth<dbh>.errstr()");
	}
	
	method modify(Str $key, Str $value, Num ?$time = time) returns Void {
		%:sth<setpooldata>.execute($value, $time, $.module, $key) == 1
			|| WWW::Kontent::error("Tried to modify non-existent pool key '$key': %:sth<dbh>.errstr()");
	}
	
	method write(Str $key, Str $value, Num ?$time = time) returns Void {
		%:sth<setpooldata>.execute($value, $time, $.module, $key) == 1
			|| %:sth<addpooldata>.execute($.module, $key, $value, $time) == 1
				|| WWW::Kontent::error("Could not create or modify pool key '$key'");
	}
	
	method delete(Str $key) returns Void {
		%:sth<delpooldata>.execute($.module, $key);
	}
	
	method list(Str $key) {
		return gather {
			%:sth<listpooldata>.execute($.module);
			my $r;
			while $r = %:sth<listpooldata>.fetchrow_arrayref {
				take ~$r[0];
			}
		}
	}
	
	method when(Str $key) returns Num {
		%:sth<getpooltime>.execute($.module, $key);
		my $r=%:sth<getpooltime>.fetchrow_arrayref;
		if $r {
			return +$r[0];
		}
		else {
			return;
		}
	}
	
	method touch(Str $key, ?$time = time) returns Void {
		%:sth<setpooltime>.execute($time, $.module, $key);
	}
}