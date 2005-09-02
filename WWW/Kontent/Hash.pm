=head1 NAME

WWW::Kontent::Hash - Cryptographic hash utility functions for Kontent

=head1 SYNOPSIS

	my $hash=gen_hash('Example', :algorithm<auto>, @data);
	cmp_hash($hash, 'Example', @data) or die "Shouldn't happen!";

=head1 DESCRIPTION

The WWW::Kontent::Hash module is used to create and compare cryptographic 
hashes in Kontent's standard format.  (If you don't know what a cryptographic 
hash is, Wikipedia has a good article on them:
L<http://en.wikipedia.org/wiki/Cryptographic_hash_function>.)

=head2 Algorithm

Kontent is designed to allow the default hash algorithm to be easily changed; 
this helps it adapt to the ever-shifting world of security, where last week's 
best practice is often this week's attack.  Another goal of this module is to 
ensure that no two hashes in Kontent are alike, even if the same piece of data 
appears in different contexts.  For example, if a user's password happens to 
also come up as a session ID, the hashes shouldn't match.

To achieve all this, Kontent joins together a number of constant strings with a 
string representing the part of the system the hash belongs to (such as 
'Session' or 'User') and the actual data being hashed.  The string is then 
hashed, and the Base64 value of the hash is concatenated to the name of the 
hash algorithm used.  The name of the algorithm is used later to ensure that 
the hash is compared using the proper algorithm.

=head2 Supported Algorithms

This module can potentially support any of Perl 5's Digest::* modules.  
Currently it attempts to load the following algorithms:

=over 4

=item * Digest::MD5 (C<md5>)

=item * Digest::SHA1 (C<sha1>)

=back 4

=head2 Subroutines

=over 4

=cut

module WWW::Kontent::Hash;

our $default_algorithm;
our %algorithms;
for <	md5		Digest::MD5
		sha1	Digest::SHA1> -> $name, $module {
	eval q{
		use perl5:\qq[$module];
		%algorithms{$name} = \qq[$module];
		$default_algorithm = $name if %algorithms{$name};
	};
}

=item C<gen_hash>('module', :algorithm<auto>, 'data1', 'data2')

Generates a hash using the indicated algorithm, module and data.  The default
value of the named :algorithm argument is C<auto>, meaning that the most secure 
algorithm available should be used.

B<Note>: Although :algorithm should be optional, in the current version of Pugs 
it is requred.

=cut

sub gen_hash($module, +$algorithm is copy = 'auto', *@data) returns Str is export {
	$algorithm = $default_algorithm if $algorithm eq 'auto';
	
	my $str = join(':', 'kontent', $module, *@data);
	
	my $digest=%algorithms{$algorithm}.new();
	$digest.add($str);
	
	return $algorithm~":"~$digest.b64digest();
}

=item C<cmp_hash>($hash, 'module', 'data1', 'data2')

Compares the given hash to the given module and data.  Internally, this works 
by generating a hash with the same algorithm used to generate $hash, then 
comparing the new hash to $hash.

=cut

sub cmp_hash($hash, $module, *@data) returns Str is export {
	my $algorithm = ~($hash ~~ /^(\w+):/);
	return $hash eq gen_hash($module, :algorithm($algorithm), *@data);
}

=back 4

=head1 SEE ALSO

L<WWW::Kontent>, L<Digest::SHA1>

Bruce Schneier. I<Applied Cryptography, 2nd Edition>, Wiley, 1996, ISBN 0471117099.

=cut