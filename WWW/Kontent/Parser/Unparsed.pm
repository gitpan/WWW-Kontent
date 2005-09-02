=head1 NAME

WWW::Kontent::Parser::Unparsed - null parser for Kolophon

=head1 SYNOPSIS

	my $skel1=WWW::Kontent::parse($text1, 'text/plain', $request);
	my $skel2=WWW::Kontent::parse($text2, 'text/css', $request);

=head1 DESCRIPTION

Unparsed is a "null parser", meaning that it does not actually do any parsing; 
it returns a skeleton consisting of a single node containing the entirety of 
the text given to it.  It can be used for pages which have absolutely no 
formatting; the rules governing the design of Kontent renderers ensure that the 
text will be outputted precisely as given (except perhaps for some line 
wrapping).

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>

=cut

module WWW::Kontent::Parser::Unparsed;
WWW::Kontent::register_parser('text/plain' | 'text/css', &parse);

sub parse($text, $request) {
	my $skel=WWW::Kontent::Skeleton.new();
	$skel.add_text("$text");
	return $skel;
}