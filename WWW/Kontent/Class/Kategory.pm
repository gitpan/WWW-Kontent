class WWW::Kontent::Class::Kategory is WWW::Kontent::Class;
WWW::Kontent::register_class('kategory', ::WWW::Kontent::Class::Kategory);

submethod BUILD() {
	my $r=.revision;
	$r.attributes<kontent:version> == 1 or die "Can't handle a version {$r.attributes<kontent:version>} Kategory page";
}

method driver_(WWW::Kontent::Request $request) { return }
method adapter_(WWW::Kontent::Request $request) {
	my $rev=.revision;
	my $page=$rev.page;
	
	my $s=WWW::Kontent::Skeleton.new;
	
	given $request.mode {
		default {
			$s.add_node('header', level(1));
			$s.children[0].add_text("Children");
			my $l = $s.add_node('list', :type<bulleted>);
			
			for $page.children -> $child {
				my $i = $l.add_node('item');
				$i.add_node('link', :location("$page.path()/$child"));
			}
		}
	}
	
	return $s;
}