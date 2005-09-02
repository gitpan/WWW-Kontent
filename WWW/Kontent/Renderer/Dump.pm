=head1 NAME

WWW::Kontent::Renderer::Dump - Skeleton dump renderer for Kontent

=head1 SYNOPSIS

	GET /path/to/page.dump

=head1 DESCRIPTION

Dump is a renderer which outputs the raw skeleton in some form.  It is mainly 
useful for debugging.  The exact form the dump takes may vary from version to 
version, but currently it is a large chunk of Perl 6 code which can be executed 
to recreate the skeleton.

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>

=cut

class WWW::Kontent::Renderer::Dump is WWW::Kontent::Renderer;
WWW::Kontent::register_renderer('dump', ::WWW::Kontent::Renderer::Dump);
	
method render(WWW::Kontent::Request $r) {
	$r.type = 'text/plain';
	my $rev=.revision;
	return $rev.adapter($r).perl();
}