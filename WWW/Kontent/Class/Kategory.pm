=head1 NAME

WWW::Kontent::Class::Kategory - Kategory page class for Kontent

=head1 SYNOPSIS

	# Attributes for a Kategory version 1 page
	kontent:class=kategory
	kontent:version=1
	kategory:class=class for child pages
	kategory:version=class version for child pages

=head1 DESCRIPTION

Kategory is a page class for creating a directory of its child pages; in future 
versions of Kontent it will also serve as a page listing pages with relations 
it, serving the same purpose as a category in many wiki systems.  Kategory pages 
do not have any editing features, and can only be created or modified by using 
a low-level tool such as L<k_manip>.

=head2 Attributes

Kategory pages are sensitive to the following attributes:

=over 4

=item C<kategory:class>

The default class for any child pages.  If this attribute is set, a C<create> 
mode will be available for the Kategory page.

=item C<kategory:version>

The default class version for any child pages.

=back 4

Kategory's behavior is also affected by standard attributes, such as 
C<kontent:title>, and attributes controlling the behavior of any magic modules 
enabled in your Kontent instance.

=head2 MODES

view, history, create (sometimes)

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>

=cut

class WWW::Kontent::Class::Kategory is WWW::Kontent::Class;
WWW::Kontent::register_class('kategory', ::WWW::Kontent::Class::Kategory);

submethod BUILD() {
	my $r=.revision;
	$r.attributes<kontent:version> == 1 or die "Can't handle a version {$r.attributes<kontent:version>} Kategory page";
}

has $.draftrev;

method create_(Str $name) {
	my $newpage=.WWW::Kontent::Class::create_($name);
	
	my $newrev=$newpage.draft_revision;
	$newrev.attributes<kontent:class>  =$.revision.attributes<kategory:class>;
	$newrev.attributes<kontent:version>=$.revision.attributes<kategory:version>;
	
	return $newpage;
}

method driver_(WWW::Kontent::Request $request) {
	if $request.mode eq 'create' {
		my $draftpage = $.revision.create(undef);
		$.draftrev = $draftpage.draft_revision;
		$.draftrev.driver($request);
	}
}
method adapter_(WWW::Kontent::Request $request) {
	return $.draftrev.adapter($request) if $.draftrev;
	
	my $rev=.revision;
	my $page=$rev.page;
	
	my $s=WWW::Kontent::Skeleton.new;
	
	given $request.mode {
		default {
			$s.add_node('header', :level<0>);
			$s.children[-1].add_text("Category: " ~ $rev.attributes<kontent:title>);
			my $l = $s.add_node('list', :type<bulleted>);
			
			for $page.children -> $child {
				my $i = $l.add_node('item');
				$i.add_node('link', :location("$page.path()/$child"));
			}
		}
	}
	
	return $s;
}

method modelist_(WWW::Kontent::Request $request) {
	if $.revision.attributes<kategory:class> {
		return <view history create>;
	}
	else {
		return <view history>;
	}
}