#!/usr/bin/pugs

=head1 TITLE

test.p6 - WWW::Kontent CGI driver

=head1 SYNOPSIS

	# in httpd.conf
	Alias /kontent /path/to/test.p6

=head1 DESCRIPTION

test.p6 (the name is for historical reasons) is the CGI driver for Kontent.
Edit the C<my $root> line to reflect your store's information, and the 
various C<use> lines to include your page classes, renderers, and stores, and 
save your changes.  Then add the line in L</SYNOPSIS> to Apache's httpd.conf 
and restart Apache, or perform an equivalent bit of configuration on whatever 
software you use.  Finally, run F<init_db.sh> to create a base hierarchy in the 
store.  You should now be able to access F<http://servername/kontent>.

=head1 SEE ALSO

L<WWW::Kontent>

=cut

use WWW::Kontent;
my $root = WWW::Kontent::get_root();

use CGI;

sub get_params {
	my %params;
	for param() -> $p {
		%params{lc $p}=~param($p);
	}
	return %params;
}

my $request=WWW::Kontent::Request.new(
	:path(~(CGI::path_info() || param('PATH') // '/')),
	:root($root),
	:parameters(get_params)
);
my $output=$request.go();
print header(:status($request.status), :content_type($request.type)), $output;
