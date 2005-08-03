class WWW::Kontent::Renderer::Dump is WWW::Kontent::Renderer;
WWW::Kontent::register_renderer('dump', ::WWW::Kontent::Renderer::Dump);
	
method render(WWW::Kontent::Request $r) {
	$r.type = 'text/plain';
	my $rev=$r.revision;
	return $rev.adapter($r).perl();
}