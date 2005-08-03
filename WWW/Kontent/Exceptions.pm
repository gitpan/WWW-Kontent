=head1 NAME

WWW::Kontent::Exceptions - Kontent exceptions

=head1 SYNOPSIS

	WWW::Kontent::error("message", :code(402));
	WWW::Kontent::restart(:mode('view'));

=head1 DESCRIPTION

WWW::Kontent::Exceptions contains functions and classes used to communicate 
errors and other conditions within Kontent.  As Pugs cannot currently throw full
objects, this is currently done with strings.

=head2 Functions

=over 4

=cut

module WWW::Kontent::Exceptions;

class WWW::Kontent::Exceptions::Error {
	has $.msg;
	has $.code;
}

class WWW::Kontent::Exceptions::Restart {
	has $.address;
	has $.mode;
	has $.format;
}

=item C<error>

Communicates a fatal error, such as "page not found", to Kontent.  The error 
message is passed in, and an optional HTTP status code can be specified with 
the named parameter 'code'.

=cut

sub WWW::Kontent::error($msg, +$code = 500) {
	die "[$code] $msg";
	die WWW::Kontent::Exceptions::Error.new(:msg($msg), :code($code));	#XXX not yet possible
}

=item C<restart>

Tells Kontent to change the specified attributes in the request object and 
restart its attempt to render the page.  This can be used to handle situations 
such as redirects and changes in the page's mode or format.

To help prevent restart loops, at least one attribute I<must> be changed.  If 
you're really sure you don't need to reset anything, simply pass in 
C<:renderer(undef)>; the correct renderer will be filled in after the restart.

B<XXX currently very out of date>

=cut

sub WWW::Kontent::restart(*%changes) {
	WWW::Kontent::error("Restart disallowed") unless %changes.elems > 1;
	die "[restart] %changes.perl()";
	die WWW::Kontent::Exceptions::Restart.new(:address($address), :mode($mode), :format($format));
}

=back 4

=head1 SEE ALSO

L<WWW::Kontent>

=cut