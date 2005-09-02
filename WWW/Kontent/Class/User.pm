=head1 NAME

WWW::Kontent::Class::User - User page class for Kontent

=head1 SYNOPSIS

	# Attributes
	kontent:class=user
	kontent:version=1
	user:givenname=User's first name
	user:surname=User's last name
	user:email=User's e-mail address
	user:profile=Visible content of user's page
	user:proftype=text/x-kolophon
	user:salt=Short, random string hashed with the password
	user:password=Hashed and salted password value

=head1 DESCRIPTION

User is a class representing a user's page.

Within Kontent, a "user" is simply a page somewhere in your Kontent instance; 
users are usually indicated in revision attributes by storing the path to their 
user page.  User pages are responsible for authenticating the users they 
represent, so different user pages can authenticate in different ways; for 
example, a hypothetical AdminUser class could use challenge-response 
authentication for additional security, while a hypothetical LDAPUser class 
could authenticate against an LDAP server.  Any page that can intelligently 
handle the 'login' mode can act as a user page.

This User class uses a simple hashed and salted password for authentication.  
It keeps a user's given name, surname and e-mail address as attributes; these 
can be used as the site's administrator pleases.  Future versions of User will 
include a feature to send an e-mail message to a user, but this is not yet 
implemented; for now the mode for this simply returns an empty skeleton.

=head2 Attributes

=over 4

=item C<user:givenname>

The user's given name (first name).

=item C<user:surname>

The user's surname (last name).

=item C<user:email>

The user's e-mail address.  This is not currently used by the system.

=item C<user:profile>

The user's profile; this is displayed when the user page is in 'view' mode.

=item C<user:proftype>

The MIME type of the user's profile.  By default this is C<text/x-kolophon>.

=item C<user:salt>

A short, random hexadecimal string which is hashed with the user's password.  
The salt is important to password security; it makes it much harder to perform 
so-called "dictonary attacks" against a stolen Kontent store to retrieve 
passwords.

The salt should be guarded as jealously as the password itself.  It may or may 
not change when the password changes; this should be considered an 
implementation detail, and the value of the salt should not be depended upon 
for anything but password processing.  In particular, it is I<not> a user ID 
number of any kind.

=item C<user:password>

The hashed password.  Note that the password is hashed along with the salt and 
some other data, so this is not I<just> a hash of the password.  This is stored 
in Kontent's standard hash format (hash type, colon, Base64 hash); see 
L<WWW::Kontent::Hash> for more details.

=back

=head2 Modes

view, history, email, login, create, edit

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>, L<WWW::Kontent::Hash>

=cut

class WWW::Kontent::Class::User is WWW::Kontent::Class;
WWW::Kontent::register_class('user', $?CLASS);

use WWW::Kontent::Hash;

has $:draftrev;
has @:valerrors;
has $:authstatus;

method :valerr($message, $request) {
	push @:valerrors, $message;
	$request.parameters<action>='correct';
}

method :hashparams($pass) {
	my $rev=.revision;
	return ($rev.attributes<kontent:title>, $rev.attributes<user:salt>, $pass);
}

method BUILD() {
	my $r=.revision;
	$r.attributes<kontent:version> == 1 or die "Can't handle a version {$r.attributes<kontent:version>} User page";
}

method create_(Str $name) {
	my $page=$_.WWW::Kontent::Class::create_($name);
	
	my $draft=$page.draft_revision;
	$draft.attributes<kontent:class>='kiki';
	$draft.attributes<kontent:version>=1;
	
	return $page;
}

method driver_($self: WWW::Kontent::Request $request) {
	my $rev=.revision;
	my $page=$rev.page;
	my %p=$request.parameters;
	$:authstatus='firsttime';
	
	if $request.mode eq 'login' and $request.parameters<action> eq 'authenticate' {
		if WWW::Kontent::Hash::cmp_hash(
			$rev.attributes<user:password>,
			'User', *$self.:hashparams($request.parameters<pass>)
		) {
			$:authstatus='authenticated';
			
			my $sess=$request.session;
			$sess.set("identity",  $page.path);
			
			$request.user = $rev;
		}
		else {
			$:authstatus='failed';
		}
	}
	elsif $request.mode eq any <create edit> {
		if $rev.isa(WWW::Kontent::DraftRevision) {
			given $rev.attributes {
				$rev.revno = %p<revno> // $rev.revno;
				
				$_<kontent:title>  = %p<username>  if $request.mode eq 'create';
				
				$_<user:givenname> = %p<givenname> // $_<user:givenname>;
				$_<user:surname>   = %p<surname>   // $_<user:surname>;
				$_<user:email>     = %p<email>     // $_<user:email>;
				$_<user:profile>   = %p<profile>   // $_<user:profile>;
				$_<user:proftype>  = 'text/x-kolophon';
				
				$_<user:salt>      = $_<user:salt> // sprintf "%08x", rand(+^0);
				$_<rev:author>     = $request.user_pathstr;
				
				if defined %p<pass1> {
					if %p<pass1> & %p<pass2> eq '' {
						.:valerr("No password provided", $request)
							if $request.mode eq 'create';
					}
					elsif %p<pass1> ne %p<pass2> {
						.:valerr("Passwords do not match", $request);
					}
					else {
						# XXX add Magic hook for password quality checking
						$_<user:password> = WWW::Kontent::Hash::gen_hash('User', :algorithm<auto>, $self.:hashparams(%p<pass1>));
					}
				}
				else {
					$_<user:password> = '';
				}
				
				unless defined $page.name {
					# Derive the default name from the title, but normalized to 
					# lowercase, spaces replaced by underscores and repeated sequences 
					# squashed, and everything else deleted entirely.
					my $name = lc $_<kontent:title>;
					$name ~~ s:g/<[ _]>+/_/;
					$name ~~ s:g/\W//;
					$page.name = $name;
				}
				
				if %p<action> eq 'save' {
					$rev.commit;
				}
			}
		}
		else {
			if $request.mode eq 'create' {
				my $draftpage=$rev.create(undef);
				$.draftrev=$draftpage.draft_revision;
			}
			else {
				my $cur = $page.cur;
				$:draftrev = $rev.revise($cur.revno + 1);
			}
			return $:draftrev.driver($request);
		}
	}
}

method adapter_($self: WWW::Kontent::Request $request) {
	return $:draftrev.adapter($request) if $:draftrev;
	my $rev  = .revision;
	my $page = $rev.page;
	my $skel=WWW::Kontent::Skeleton.new;
	
	given $request.mode {
		when 'create' | 'edit' {
			{
				my $verb = ($request.mode eq 'create' ?? 'creating' :: 'editing');
				$skel.add_node('header', :level<0>);
				$skel.children[-1].add_text("User: {$rev.attributes<kontent:title> // 'Unnamed'} ($verb)");
			}
			
			if $request.parameters<action> eq 'save' {
				$skel.add_node('paragraph');
				$skel.children[-1].add_text("Your revisions have been saved.  ");
				$skel.children[-1].add_node('link', :location($page.path));
				$skel.children[-1].children[-1].add_text("View the revised page...");
			}
			else {
				if @:valerrors {
					$skel.add_node('paragraph');
					$skel.children[-1].add_text("@:valerrors.elems() error{ 's' if @:valerrors != 1 } occurred:");
					
					my $l = $skel.add_node('list', :type<bulleted>);
					for @:valerrors {
						my $i=$l.add_node('item');
						$i.add_text($_);
					}
					
					$skel.add_node('paragraph');
					$skel.children[-1].add_text("Please correct them and try again.");
				}
				my $f=$skel.add_node('form');
				my $p=$f.add_node("paragraph");
				$p.add_node('textfield', :name<username>, :value($rev.attributes<kontent:title>), :label<Username>)
					if $request.mode eq 'create';
				$p.add_node('textfield', :type<masked>, :name<pass1>, :value<>, :label<Password>);
				$p.add_node('textfield', :type<masked>, :name<pass2>, :value<>, :label("Repeat password"));
				
				$p = $f.add_node('paragraph');
				$p.add_node('textfield', :name<givenname>, :value($rev.attributes<user:givenname>), :label("Given name"));
				$p.add_node('textfield', :name<surname>,   :value($rev.attributes<user:surname>  ), :label<Surname>);
				$p.add_node('textfield', :name<email>,     :value($rev.attributes<user:email>    ), :label<E-mail>);
				
				$p = $f.add_node('paragraph');
				$p.add_node('textfield', :type<multiline>, :name<profile>, :value($rev.attributes<user:profile>), :label<Profile>);
				
				$p = $f.add_node('paragraph');
				my $c=$p.add_node('choicefield', :type<action>);
				$c.add_node('choice', :value<save>);
				if $request.mode eq 'create' {
					$c.children[-1].add_text("Create user");
				}
				else {
					$c.children[-1].add_text("Save changes");
				}
			}
		}
		
		when 'email' {
			
		}
		
		when 'login' {
			my $show_form=1;
			
			$skel.add_node('header', :level<0>);
			$skel.children[-1].add_text("User: {$rev.attributes<kontent:title>} (authenticating)");
			
			my $prompt=$skel.add_node('paragraph');
			
			if $:authstatus eq 'authenticated' {
				$show_form = 0;
				$prompt.add_text("Authentication successful.  Welcome, {$rev.attributes<user:givenname>}!");
			}
			elsif $:authstatus eq 'failed' {
				$prompt.add_text("Authentication failed--please try again.");
			}
			else {
				$prompt.add_text("Please authenticate yourself by entering your password.");
			}
			
			if $show_form {
				my $f=$skel.add_node('form');
				$f.add_node('textfield', :type<masked>, :name<pass>, :label<Password>);
				$f.add_node('choicefield', :type<action>);
				$f.children[-1].add_node('choice', :value<authenticate>);
				$f.children[-1].children[-1].add_text("Log in");
			}
		}
		
		default {
			$skel.add_node('header', :level<0>);
			$skel.children[-1].add_text("User: {$rev.attributes<kontent:title>}");
			push $skel.children, WWW::Kontent::parse($rev.attributes<user:profile>, $rev.attributes<user:proftype>, $request);
		}
	}
	
	return $skel;
}

method modelist_() {
	return <view history email login create edit>;
}