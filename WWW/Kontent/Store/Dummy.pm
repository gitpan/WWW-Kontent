=head1 NAME

WWW::Kontent::Store::Dummy - defunct test store

=head1 DESCRIPTION

This module was used as a dummy store very early in Kontent's development.  It 
has not been kept up, and is now utterly useless.  Do not attempt to use it.

This module will almost certainly be removed in future versions.

=cut

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