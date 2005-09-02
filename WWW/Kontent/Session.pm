=head1 NAME

WWW::Kontent::Session - Kontent session manager

=head1 SYNOPSIS

	$request.session.get("identity");
	$request.session.set("identity", 'users/anonymous');

=head1 DESCRIPTION

WWW::Kontent::Session is an object representing a Kontent session.  Sessions 
are kept in a pool off the root page, and have zero or more keys, each with an 
accompanying value.

=head2 Attributes

=over 4

=cut

use WWW::Kontent::Hash;

class WWW::Kontent::Session {

=item C<sid>

Returns the session ID associated with this session.  Supervisors should 
arrange to have session IDs sent along with every outgoing request as a cookie.

=cut

	has $.sid;
	has $:pool;
	
=back 4

=head2 Constructors

=over 4

=item C<new>(:root($root), :sid($sid))

Creates a new Session object with the associated session ID.  If no session ID 
is provided, it will generate one by hashing together various pieces of data 
in the environment and a few random numbers.

=cut
	
	submethod BUILD($root, ?$.sid) {
		# Get the Session pool
		$:pool = $root.pool('Session');
		
		unless $.sid {
			# XXX check for collisions
			$.sid=WWW::Kontent::Hash::gen_hash('Session', :algorithm<auto>, $*PID, int(time*1000), map { int rand(+^0) } 1..4);
		}
	}
	
=back 4

=head2 Methods

=over 4

=item C<get>($key)

Retrieves the value of the given key from the session.

=cut
	
	method get(Str $key) {
		$:pool.read("$:sid:$key");
	}
	
=item C<set>($key, $value)

Sets the given key to the given value.

=cut
	
	method set(Str $key, Str $value) {
		$:pool.write("$:sid:$key", $value);
	}

=item C<delete>()

Deletes the entire session.  The behavior of the Session object after this 
method is called is undefined.

=cut

	method delete() {
		for $:pool.list {
			next unless /^$:sid/;
			$:pool.delete($_);
		}
	}
}

=back 4

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Store>

=cut