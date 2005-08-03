=head1 NAME

WWW::Kontent::Request - Kontent request object

=head1 SYNOPSIS

	# Eventually, when Pugs supports this sort of thing
	method adapter(WWW::Kontent::Request $request where { .mode eq 'view' }) {
		return WWW::Kontent::Parser::parse(
			:type($.attributes<kiki:type>),
			:content($.attributes<kiki:content>),
		);
	}

=head1 DESCRIPTION

WWW::Kontent::Request represents a request for a page.  It is used to:

=over 4

=item *
Store and organize information which may be used and modified over the lifetime 
of the request.

=item *
Execute the overall store-driver-renderer control flow.

=item *
Carry information between the various components.

=item *
Parse and resolve paths.

=back 4

=head2 Attributes

=over 4

=item C<path>

L<WWW::Kontent::Path> object representing the path being resolved in this 
request.

=item C<mode>

Contains the name of the rendering mode, such as "view" (the default), "history"
and "edit".  Drivers, adapters, and renderers are all concerned with these 
modes.  This actually retrieves it from the object in C<path>.

=item C<format>

Contains the name of the page's format, such as "html" (the default), "xml", 
"pdf", or "jpg".  This field is mostly the purview of the renderer (and is used 
to select the renderer), but may be of interest to certain adapters as well, 
such as those used to store images.  This actually retrieves it from the object 
in C<path>.

=item C<parameters>

Contains a hash of parameters to the page.  Parameters may be accessed in 
Kolophon by using $$NAME, and are used to communicate information to drivers 
besides the mode and format; they usually correspond to HTTP POST or GET 
parameters.

=item C<nested>

Indicates the subrequest depth.  Zero indicates that this object is the 
top-level request; one indicates it is a first-level subrequest; and so on.  
Many renderers will omit "chrome" such as headers or navigation tools in a 
subrequest, but drivers and adapters may be interested in this as well.

=item C<type>

Contains the MIME type of the final output; as such, this is usually set by the 
renderer, but sometimes the adapter handles this instead.  HTTP supervisors 
will typically output this value as the C<Content-Type> header.

=item C<status>

Contains the HTTP status code that should be returned to the browser; defaults 
to 200.

=item C<root>

Contains the store's root page.

=item C<page>

=item C<revision>

After a call to C<.path.resolve>, contains the page and revision so resolved.
These fields should usually be used only by supervisors; the request object 
will arrange for renderers and page classes to receive their own references to 
the revision object.

=item C<renderer>

Contains the renderer to be used for this request.

=back 4

=cut

class WWW::Kontent::Request {
	has WWW::Kontent::Page $.root is rw;
	has Str %.parameters          is rw;
	
	has WWW::Kontent::Path $.path is rw;
	method page()         { $.path.page     }
	method revision()     { $.path.revision }
	method mode()   is rw { $.path.mode     }
	method format() is rw { $.path.format   }
	
	has String $.type   is rw;
	has Int    $.status	is rw;
	
	has int $.nested is rw;
	has WWW::Kontent::Renderer $.renderer;
	
=head2 Constructors

=over 4

=item C<< WWW::Kontent::Request.new(:root($store_root), :path("/foo/bar[42].atom{edit}"), :parameters({ baz => 'quux' })) >>

The normal constructor for a Request object; usually called only from the 
supervisor.  Parses C<path> if provided to acquire an address.

=cut

	submethod BUILD($.root, ?$path, +%.parameters) {
		$.path = WWW::Kontent::Path.new().parse($path);
		$.status = 200;
	}

=item C<$request.subrequest($path, { :param1<value1>, :param2<value2> })>

Constructs a subrequest with the same format and mode as the current request, 
but the parameters and path provided.

Note that the same renderer class will be used as C<$request>, even if a 
different C<format> is provided.  The reason for this will become clear through 
deep meditation on exactly what the Kolophon code C<{{/images/foo.jpg}}> should 
do in an HTML renderer.

=cut
	
	method subrequest($path, ?%parameters) returns WWW::Kontent::Request {
		my $ret=$_.clone;
		$ret.renderer.=new() if $.renderer;
		$ret.nested++;
		
		$ret.parameters = %parameters;
		$ret.path = WWW::Kontent::Path.new().parse($path);
		return $ret;
	}

=back 4

=head2 Methods

=over 4

=item C<go>

Convenience method which calls C<.path.resolve>, then the revision's driver, 
and finally the renderer.  Returns a string containing the renderer's output.  
It also handles restarts and other inner exceptions.

=cut
	
	method go(WWW::Kontent::Request $r: ) {
		# Limited to avoid infinite loops
		for(0..15) {
			#try
			{
				$.path.resolve($.root);
				my $rev=$r.revision;
				$rev.driver($r);
				
				$.renderer=%WWW::Kontent::renderers{$.path.format}.new()
					unless $.renderer;
				return $.renderer.render($r);
			};
			
			if    $! ~~ /^\[restart\]/ { next }
			elsif $! ~~ /^\[(\d\d\d)\] (.*)/ {
				$.status = $0;
				$.type   = 'text/plain';
				return "Error: $1";
			}
			elsif defined $! {
				die $!;
			}
			else {
				last;
			}
		}
		
		# We can only get here if the above loop never returned
		$.status = 504;
		$.type   = 'text/plain';
		return 'Request restart limit exceeded (possible restart loop).';
	}
}

=back 4

=head1 SEE ALSO

L<WWW::Kontent>

=cut