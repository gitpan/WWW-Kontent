use WWW::Kontent::Store;

=head1 NAME

WWW::Kontent::Foundation - Abstract base classes for Kontent

=head1 SYNOPSIS

	use WWW::Kontent::Fondation;
	
	#A store might do this:
	class MySavedPage is WWW::Kontent::SavedPage { ... }
	class MyDraftRev  is WWW::Kontent::DraftRevision { ... }
	
	# Similarly:
	role MyClass is WWW::Kontent::Class { ... }		#eventually--curently a class, not a role
	class MyRenderer is WWW::Kontent::Renderer { ... } 

=head1 DESCRIPTION

WWW::Kontent::Foundation contains abstract bases for several important 
classes and roles.  It also pulls in L<WWW::Kontent::Store>, which defines the 
six classes needed to represent pages and revisions; see that module for more 
niformation on those classes.

=head2 WWW::Kontent::Renderer

This base class represents a page renderer.  Renderers have only one method, 
C<render>, which takes a request object and returns the page's content; it is 
also expected to set the request object's C<type> attribute to an appropriate 
value.  In addition, C<WWW::Kontent::Renderer> has a public C<revision> 
attribute containing the revision that should be rendered; this attribute is 
managed by C<WWW::Kontent::Renderer> and C<WWW::Kontent::Request> for the 
benefit of the renderer.

=cut

class WWW::Kontent::Renderer {
	has $.revision is rw;
	
	method render(Request $r) returns Str { ... }
}

=head2 WWW::Kontent::Class

This is the base class of a Kontent page class.  It contains a C<revision> 
attribute containing the revision whose class this is; this attribute is 
managed by C<WWW::Kontent::Class> and C<WWW::Kontent::Request> for the benefit 
of the page class.

Page classes must implement two methods, C<driver> and C<adapter>; see 
L</WWW::Kontent::Revision> for information on their signatures and use.  They 
may additionally implement the methods C<resolve> and C<create>; the default 
implementations dispatch to the page object's C<default_resolve> and 
C<default_create> methods, respectively.  It's very common for a page class to 
capture the return value from this base class's C<create> method and set some 
attributes, usually the C<kontent:class> attribute.

To avoid a rather annoying Pugs bug, the four methods currently have an 
underscore appended to their names; that is, they're named C<driver_> and so on.

=cut

class WWW::Kontent::Class {
	has $.revision is rw;
	
	submethod BUILD($.revision) { }
	method driver_(WWW::Kontent::Request $r)  returns Void  {...}
	method adapter_(WWW::Kontent::Request $r) returns WWW::Kontent::Skeleton {...}
	
	# See note in Revision body
	method resolve_(Str $name) returns WWW::Kontent::Page {
		my $page=$.revision.page;	#XXX pugsbug
		$page.default_resolve($name);
	}
	method create_(Str $name) returns WWW::Kontent::Draft {
		my $page=$.revision.page;	#XXX pugsbug
		$page.default_create($name);
	}
}

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Store>

=cut