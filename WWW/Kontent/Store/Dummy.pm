use WWW::Kontent::Foundation;

module WWW::Kontent::Store::Dummy;

class WWW::Kontent::Store::Dummy::Rev is WWW::Kontent::Revision {
	has $.page;
	has %.attributes;
	
	submethod BUILD($.page) {
		%.attributes={
			type => 'text/plain',
			content => "Hello, World!"
		};
	}
	
	method driver(WWW::Kontent::Request $request) { return }
	method adapter(WWW::Kontent::Request $request) {
		$request<type> = %.attributes<type>;
		$request<skeleton><parts>.push(%.attributes<content>);
	}
}

class WWW::Kontent::Store::Dummy::Page is WWW::Kontent::Page {
	has $.parent;
	has @.revisions;
	
	submethod BUILD(?$parent = undef) {
		@.revisions=[ WWW::Kontent::Store::Dummy::Rev.new(:page($_)) ];
	}
	
	method default_resolve(String $name) { return WWW::Kontent::Store::Dummy::Page.new() }
}

sub get_root() returns WWW::Kontent::Store::Dummy::Page {
	return WWW::Kontent::Store::Dummy::Page.new();
}