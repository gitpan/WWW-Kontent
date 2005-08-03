use WWW::Kontent::Foundation;
use WWW::Kontent::Exceptions;
use WWW::Kontent::Path;
use WWW::Kontent::Request;
use WWW::Kontent::Skeleton;

module WWW::Kontent-0.01;

=head1 NAME

WWW::Kontent - Highly extensible Perl 6 CMS

=head1 DESCRIPTION

Kontent is a web content management system written in Perl 6.  It is currently 
executable in Pugs installations with Parrot available; the storage subsystem 
included in this installation also requires the Perl 5 interop feature, but 
an alternate system could be written.

Kontent's basic principle is separation of concerns: whenever possible, the 
system is separated into swappable components.  The webmaster chooses a 
"supervisor" to interface with their web server and a "store" to hold all pages 
in the system; individual pages have different "classes" implementing different 
behaviors; and each page can be displayed with any of several "renderers".

Kontent is simple enough to need only a small amount of configuration, and 
flexible enough to meet the needs of almost any site.  It takes care of the 
niggling details of web design--tasks like revision control, site templating, 
and user contributions--leaving only the task of plugging in your own content.

=head2 Configuration

Currently only the CGI supervisor is written, and the only useful store is 
NarrowDBI.  This somewhat simplifies the task of configuring Kontent.

Configuring Kontent takes four steps:

=over 4

=item * Point your web server at the appropriate supervisor somehow.  See 
L<test.p6> for information on this.

=item * Edit F<kontent-config.yaml> with the modules you want to be loaded and 
your store's configuration.

=item * Create the database the store interfaces with.

=item * Create the root node:
C<pugs -MWWW::Kontent -e 'WWW::Kontent::make_root'>

=back 4

Some day there should be a set of CGI scripts to automate all of this.

=head2 About the Module

WWW::Kontent first loads several core Kontent modules, including 
L<WWW::Kontent::Foundation>, L<WWW::Kontent::Exceptions>, 
L<WWW::Kontent::Request>, and L<WWW::Kontent::Skeleton>.  It then reads 
Kontent's configuration file, kontent-config.yaml, from the same directory the 
supervisor is in.  It loads all the modules specified in the C<modules> 
configuration group, then curries the specified store's C<make_root> and 
C<get_root> functions to receive the store configuration, storing the resulting 
functions in C<WWW::Kontent::make_root> and C<WWW::Kontent::get_root>.

It also contains two functions, C<register_class> and C<register_renderer>, and 
the corresponding hashes C<%classes> and C<%renderers>.  These are used to 
register and locate classes and renderers, respectively.  Both functions take a 
string containing the class or renderer's name (like 'kiki') and the class 
that name refers to.

=head1 BUGS

Plenty, no doubt; this is an early alpha of an incomplete system written in an 
experimental language with a constantly-changing interpreter.  In particular, 
be on the lookout for intermittent bugs in Perl 5 interop; these usually 
manifest as an inability to find DBI methods like C<execute> or 
C<fetchrow_arrayref>.

Basically, you'd be nuts to try to use this for real right now.

=head1 THANKS TO

A special thanks to Google and The Perl Foundation for funding and managing 
this project, and to the Perl 6, Pugs and Parrot teams for their work on the 
software that made it possible.

=head1 COPYRIGHT

This module and all modules and scripts distributed with it are copyright (C) 
2005 Brent Royal-Gordon.

This distribution is free software, and may be used, modified and distributed 
under the same terms as the official Perl 6 distribution if they have been 
decided, or Perl 5 otherwise.

=cut

use FindBin;

our (&get_root, &make_root, %conf);

{
	my $conffile="$FindBin::Bin/kontent-config.yaml";
	%conf=eval slurp($conffile), :lang<yaml>;
	
	WWW::Kontent::error("Bad configuration file version--check the README file for details")
		unless %conf<config-version> == 1;
	
	for %conf<modules>[] {
		eval qq{require WWW::Kontent::$_};
	}
	
	my $store="WWW::Kontent::Store::%conf<store><module>";
	&get_root := (eval "\&{$store}::get_root").assuming(%WWW::Kontent::conf<store>);
	&make_root := (eval "\&{$store}::make_root").assuming(%WWW::Kontent::conf<store>);
}

our(%renderers, %classes);

sub register_renderer($name, $class) {
	%renderers{$name} = $class;
}

sub register_class($name, $class) {
	%classes{$name} = $class;
}