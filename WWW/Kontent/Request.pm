=head1 NAME

WWW::Kontent::Request - Kontent request object

=head1 SYNOPSIS

	# Eventually, when Pugs supports this sort of thing
	method adapter(WWW::Kontent::Request $request where { .mode eq 'view' }) {
		return WWW::Kontent::Parser::parse(
			$.attributes<kiki:content>,
			$.attributes<kiki:type>,
			$request
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

=item C<pagepath>

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

Contains a hash of parameters to the page.  Parameters are used to communicate 
information to drivers besides the mode and format; they usually correspond to 
HTTP POST or GET parameters.

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

After a call to C<.resolve>, contains the page and revision so resolved.
These fields should usually be used only by supervisors; the request object 
will arrange for renderers and page classes to receive their own references to 
the revision object.

=item C<renderer>

Contains the renderer to be used for this request.

=item C<session>

Contains a L<WWW::Kontent::Session> object for the current session.

=item C<userpath>

Contains the path to the current user object.  This is retrieved from the 
session during object construction.

=item C<user>

Contains the current revision of the user page.

=back 4

=cut

class WWW::Kontent::Request {
	has WWW::Kontent::Page $.root is rw;
	has Str %.parameters          is rw;
	
	has WWW::Kontent::Path $.userpath is rw;
	method user()         { $.userpath.revision  }
	method user_pathstr() {
		if $.userpath {
			my $page=$.userpath.page;
			return $page.path;
		}
		else {
			return '';
		}
	}
	
	has WWW::Kontent::Path $.pagepath is rw;
	method page()         { $.pagepath.page      }
	method revision()     { $.pagepath.revision  }
	method mode()   is rw { $.pagepath.mode      }
	method format() is rw { $.pagepath.format    }
	
	has Str $.type     is rw;
	has Int $.status   is rw;
	has Str $.location is rw;
	
	has int $.nested is rw;
	
	has WWW::Kontent::Renderer $.renderer;
	has WWW::Kontent::Session  $.session;
	
=head2 Constructors

=over 4

=item C<WWW::Kontent::Request.new>(:root($store_root), :path("/foo/bar[42].atom{edit}"), :sid($session_id), :parameters({ baz => 'quux' }));

The normal constructor for a Request object; usually called only from the 
supervisor.  Parses C<path> if provided to acquire an address.

=cut

	submethod BUILD($.root, ?$path, ?$sid, +%.parameters, +$loaduser = 1) {
		$.session  = WWW::Kontent::Session.new(:root($.root), :sid($sid));
		
		my $user = try { $.session.get("identity") }
				// WWW::Kontent::setting("default_user")
				// '/users/anonymous';
		$.userpath = WWW::Kontent::Path.new().parse($user) if $loaduser;
		$.pagepath = WWW::Kontent::Path.new().parse($path);
		$.status   = 200;
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
		$ret.pagepath = WWW::Kontent::Path.new().parse($path);
		return $ret;
	}

=back 4

=head2 Methods

=over 4

=item C<resolve_all>

Tells the objects in the C<userpath> and C<pagepath> attributes to resolve 
themselves; in the process, fills the C<user>, C<page>, and C<revision> 
attributes.

=cut

	method resolve_all() {
		$.userpath.resolve($.root, $_) if $.userpath;
		$.pagepath.resolve($.root, $_);
	}

=item C<go>

Convenience method which calls C<.resolve>, then the revision's driver, 
and finally the renderer.  Returns a string containing the renderer's output.  
It also handles restarts and other inner exceptions.

=cut
	
	method go(WWW::Kontent::Request $r: Int ?$depth = 0) {
		my Str $output;
		
		#try {
			$r.resolve_all();
			
			my $rev=$r.revision;
			$rev.driver($r);
			
			$.renderer=%WWW::Kontent::renderers{$.pagepath.format}.new()
				unless $.renderer;
			$output=$.renderer.render($r);
		#};
		
		if    $! ~~ /^\[restart\]/ {
			if $depth < 8 {
				$r.go($depth+1);
			}
			else {
				$.status = 504;
				$.type   = 'text/plain';
				return "Error: restart limit exceeded--possible restart loop";
			}
		}
		elsif $! ~~ /^\[(\d\d\d)\] (.*)/ {
			$.status = $0;
			$.type   = 'text/plain';
			return "Error: $1";
		}
		elsif defined $! {
			$.status = 500;
			$.type   = 'text/plain';
			return "Uncaught exception: $!";
		}
		else {
			return $output;
		}
	}
	
	method :resolve_partial($self: Str $path) {
		if $path eq '' {
			# Empty path--could refer to the current page or any of its 
			# parents.  Return them all and let the caller deal with the 
			# repercussions.
			return gather {
				my $cursor=$.pagepath.page;
				while $cursor {
					take $cursor.cur;
					$cursor = $cursor.parent;
				}
			}
		}
		
		my $pathobj=WWW::Kontent::Path.new().parse($path);
		
		if $path ~~ m{^/} {
			# Full path--just resolve from the root page.
			
			try { $pathobj.resolve($.root, $self) };
			return [ $pathobj.revision ];
		}
		else {
			# Partial path--try to resolve the path under the current page, 
			# then each of its ancestors.
			
			return gather {
				my $cursor=$.pagepath.page;
				
				while $cursor {
					try {
						$pathobj.resolve($cursor, $self);
						take $pathobj.revision;
					};
					$cursor = $cursor.parent;
				}
			}
		}
	}
	
=item c<grok_link>($path)

Resolves a partial path (one that may be relative to the current page or any of 
its parents, and whose final component may be the title of a page rather than 
its name).  Returns an array of Revision objects which match the path in 
question.

=cut
	
	method grok_link(Str $path) returns Array of WWW::Kontent::Revision {
		# If the last component looks like a path, not a title...
		if $path ~~ m< / \w+ [ \.\w+ ]? [ \{ \w+ \} ]? $> {
			# Attempt to resolve normally.
			my $ret=.:resolve_partial($path);
			return [ $ret[0] ] if $ret;
		}
		
		# If we got here, path resolution didn't work--we'll have to use title 
		# resolution.
		if $path ~~ m{^ (.*) [^|/] (<-[/]>+) $} {
			my ($prefix, $title)=(~$0, ~$1);
			
			my @candidates=.:resolve_partial($prefix);
			for *@candidates -> $rev {
				my $page=$rev.page;
				my @results;
				if @results = $page.children_with('kontent:title' => $title) {
					return map {
						my $sp=$rev.resolve(~$_);
						$sp.cur
					} @results;
				}
			}
		}
		
		return [];
	}
	
=item C<trigger_magic>('pre', 'resolve', $foo, $bar)

Triggers any magic hooks associated with the event in question.  The last 
data argument is returned, and may be modified by the magic hooks.

=cut
	
	method trigger_magic($self: $when, $event, *@args is copy) {
#		warn "triggering $when-$event magic: {@args.perl()}";
		if %WWW::Kontent::magic{$when}{$event} {
#			warn "    There is magic for this event.";
			$_($self, @args) for *%WWW::Kontent::magic{$when}{$event};
		}
		return @args[-1];
	}
}

=back 4

=head1 SEE ALSO

L<WWW::Kontent>

=cut