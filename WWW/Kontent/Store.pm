=head1 NAME

WWW::Kontent::Store - Base classes for Kontent stores

=head1 SYNOPSIS

	class MySavedPage is WWW::Kontent::SavedPage { ... }
	class MyDraftPage is WWW::Kontent::DraftPage { ... }
	class MySavedRev is WWW::Kontent::SavedRevision { ... }
	class MyDraftRev is WWW::Kontent::DraftRevision { ... }
	
	say "$page.path() ('$page.cur.attributes<kontent:title>') has {+$page.revisions} revisions.";

=head1 DESCRIPTION

WWW::Kontent::Store contains the classes defining Kontent pages and revisions.
The classes in this module are abstract, and are usually inherited from by 
store modules.

=head2 WWW::Kontent::Page

This is a base class for a Kontent page.  A store will not usually derive 
directly from this class; rather, it will derive its child classes, C<SavedPage>
and C<DraftPage>.

=head3 Methods

=over 4

=item C<name>

Returns the name of the page.  In DraftPages, this should be writable.  Store 
authors must override this method to give it a body.

=item C<parent>

Returns the page's parent page.  Note that this must be the parent I<as seen by 
Kontent>, which may be different from the parent reflected in the store if 
a special page class is bridging between two stores.  Hence, it's probably best 
to have parent pages pass themselves into the constructors of their children.
Store authors must override this method to give it a body.

=item C<path>

Returns the path from the root page to this page.  This method has a default 
implementation using C<name> and C<parent>, but store authors may want to 
override it for efficiency.

=back 4

=cut

class WWW::Kontent::Page {
    method name() returns Str { ... }
    method parent() returns WWW::Kontent::Page { ... }
    
	method path() {
		if(.parent) {
			return join "/", grep { $_ ne '' } $_.parent().path(), $_.name();
		}
		else {
			return "";
		}
	}
}

=head2 WWW::Kontent::SavedPage

SavedPage represents a page retrieved from whatever backing store the store 
module interfaces with.  SavedPages are basically immutable.

=head3 Methods

=over 4

=item C<revisions>

Returns an array of SavedRevision objects representing the page's revisions.

=item C<cur>

Returns a SavedRevision object representing the page's current revision.  This 
method defaults to simply calling C<revisions> and extracting the last element, 
but store authors may want to override it with a more efficient implementation.

=item C<children>

Returns an array containing the names of the page's children.

B<XXX should probably be one of the default_ methods>

=item C<default_resolve>

Finds the child page of the given name and returns it.  Page classes will 
typically use this method to resolve a page, but may override it to implement a 
bridge.

=item C<default_create>

Creates a child page of the given name and returns a draft of its first 
revision.  Page classes will typically use this method to resolve a page, but 
may override it to implement a bridge or simply set a default page class.

=item C<pool>($module)

Returns a pool in the current store with the module name $module.

=back 4

=cut

class WWW::Kontent::SavedPage is WWW::Kontent::Page {
	method revisions() returns Array of WWW::Kontent::Revision { ... }
	method cur() returns WWW::Kontent::Revision { .revisions[-1] }
	
	method children() returns Array of String { ... }
	
	method default_resolve(String $name) returns WWW::Kontent::Page { ... }
	method default_create(String $name) returns WWW::Kontent::Draft { ... }
	method pool(Str $module) returns WWW::Kontent::Pool { ... }
}

=head2 WWW::Kontent::DraftPage

DraftPages represent a page which has been created in the Kontent store, but 
has not yet been committed.  Each DraftPage has a single DraftRevision; 
committing the DraftRevision should also save the DraftPage.  The C<name> 
field in a DraftPage should be mutable.

=head3 Methods

=over 4

=item C<draft_revision>

Returns the draft revision associated with this draft page.

=back 4

=cut

class WWW::Kontent::DraftPage is WWW::Kontent::Page {
	method name() returns Str is rw { ... }
    method draft_revision() returns WWW::Kontent::DraftRevision { ... }
}

=pod

=head2 WWW::Kontent::Revision

This is a base class for a Kontent page.  A store will not usually derive 
directly from this class; rather, it will derive its child classes, C<SavedPage>
and C<DraftPage>.

=head3 Methods

=over 4

=item C<page>

Returns the page this revision belongs to. 

=item C<attributes>

Returns a hash containing all attributes of this revision.

=item C<revno>

Returns the revision number of this revision; this number is 1-based, increasing 
by 1 in each revision.

=item C<driver>

Calls the page class's driver method.

A class's driver should implement any complex behavior the page class requires, 
such as database updates, querying for information, or complex calculations.  A 
L<WWW::Kontent::Request> object must be passed in to this method.

=item C<adapter>

Calls the page class's adapter method.

The adapter is called by the renderer when it wants to retrieve the page's 
content; it should return a L<WWW::Kontent::Skeleton> object containing content 
appropriate for the current mode.  A WWW::Kontent::Request object must be 
passed in to this method.

=item C<modelist>

Calls the page class's modelist method.  The modelist method should return an 
array containing all the modes supported by the class.

=back 4

=cut

class WWW::Kontent::Revision {
	has WWW::Kontent::Class $._revclass;
	method _fill_revclass() {
		return if defined $._revclass;

		my $class = %WWW::Kontent::classes{$_.attributes<kontent:class>};
		WWW::Kontent::error("Unknown class {$_.attributes<kontent:class>}")
			unless $class;
		$._revclass = $class.new(:revision($_))
	}
	
	method attributes() returns Hash of Str { ... }
	method revno() returns Int { ... }
	method page() returns Page { ... }
	
	#Page class methods
	# XXX handles, and eventually role composition
	method driver(Request $r) returns Void {
		$r.trigger_magic('pre', 'driver', $_);
		._fill_revclass();
		$._revclass.driver_($r);
		$r.trigger_magic('post', 'driver', $_);
	}	
	method adapter(Request $r) returns WWW::Kontent::Skeleton {
		$r.trigger_magic('pre', 'adapter', $_);
		._fill_revclass();
		my $ret=$._revclass.adapter_($r);
		return $r.trigger_magic('post', 'adapter', $_, $ret);
	}
	method modelist(Request $r) returns Array of Str {
		$r.trigger_magic('pre', 'modelist', $_);
		._fill_revclass();
		my $ret=$._revclass.modelist_($r);
		return *$r.trigger_magic('post', 'modelist', $_, $ret);
	}
}

=head2 WWW::Kontent::SavedRevision

Represents a revision retrieved from the database.  Store authors should 
write a class which inherits from this.  Its attributes should be assumed to 
be immutable.

=head3 Methods

=over 4

=item C<revise>

Returns a Draft object with the same attributes as this revision, except with 
the C<rev:> attributes omitted.  The draft should have the revision number 
passed into this method.

=item C<resolve>

Calls the page class's C<resolve> method, which by default calls the page's 
C<default_resolve> method.  This method takes a page name and returns the 
child page with that name.

=item C<create>

Calls the page class's C<create> method, which by default calls the page's 
C<default_create> method.  This method takes a page name and returns a 
DraftPage object for it.  The DraftPage's revision must be committed before it 
will appear in the backing store.

=item C<pool>($module)

Returns a pool in the current store with the module name $module.

=back 4

=cut

class WWW::Kontent::SavedRevision is WWW::Kontent::Revision {
	method revise(Int $revno) returns WWW::Kontent::DraftRevision { ... }
	
	#More page class methods
	# XXX pugsbug
	# I really have no idea why this needs an underscore, but otherwise it 
	#  just calls back into itself.
	# XXX see if magic can be added
	method resolve(String $name) returns WWW::Kontent::Page { ._fill_revclass(); $._revclass.resolve_($name) }
	method create(String $name) returns WWW::Kontent::Draft { ._fill_revclass(); $._revclass.create_($name)  }
	method pool(Str $module) returns WWW::Kontent::Pool { ... }
}

=head2 WWW::Kontent::DraftRevision

This class represents an uncommitted draft revision.  Store authors should 
inherit from this class.

=head3 Methods

=over 4

=item C<commit>

Writes the draft revision (and the page, if it is also a draft) into the 
backing store.

=back 4

=cut

class WWW::Kontent::DraftRevision is WWW::Kontent::Revision {
    submethod BUILD(Int $revno)  { ... }
	method commit() returns Void { ... }
}

=head2 WWW::Kontent::Pool

This class represents a pool of unversioned data tied to a particular store.
Store authors should inherit from this class.

=cut

class WWW::Kontent::Store::Pool {
	method module()                                 returns  Str {...}	
	submethod BUILD($.module                      )              {...}
	method read(  Str $key                        ) returns  Str {...}
	method add(   Str $key, Str $value, Num ?$time) returns Void {...}
	method modify(Str $key, Str $value, Num ?$time) returns Void {...}
	method write( Str $key, Str $value, Num ?$time) returns Void {...}
	method delete(Str $key                        ) returns Void {...}
	method list()                           returns Array of Str {...}
	method when(  Str $key                        ) returns  Num {...}
	method touch(  Str $key,            Num ?$time) returns Void {...}
}

=head1 SEE ALSO

L<WWW::Kontent>

=cut