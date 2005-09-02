=head1 NAME

WWW::Kontent::Magic::Fidelius - Fidelius access-control system for Kontent

=head1 SYNOPSIS

	# Attributes
	fidelius:child=edit(-users/annoying_user) default(any)
	fidelius:self=edit(users/admin1 users/admin2 -any) default(any)

=head1 DESCRIPTION

Fidelius is a simple access-control system for Kontent.  It allows two 
attributes to be used to control who can access which modes of which pages.

The first attribute, C<fidelius:self>, controls which users can view the page.  
Specifically, it allows or denies access to the current user based on the mode.
The second attribute, C<fidelius:child>, controls which users can view children 
of the page; it works by allowing or denying them the ability to resolve child 
pages based on the mode.

Both attributes are constructed in the same way.  The mode is listed, followed 
by a series of users in parentheses.  Users can have a minus sign prefixed to 
their name, in which case they are specifically blocked from accessing the page.
Users who aren't listed are implicitly blocked.

The special mode "all" is checked before any other checks are done; it can be 
used to list users who should always be allowed or denied access, regardless of 
later checks.  The special mode "default" is checked after the current mode; it 
can be used to list users who should be allowed access unless they've been 
specifically blocked.  Finally, the special user "any" can be used in any mode 
(even the special ones) to indicate how users who aren't listed in that mode 
should be treated.  In the future, it is likely that a special user called 
"owner" will also be supported, although the semantics of it haven't been 
decided.

There are two conditions under which Fidelius checks will not be performed at 
all:

=over 4

=item * There is no current user.  This usually only happens when resolving the 
current user, but can also happen when tools use the Kontent libraries.

=item * The appropriate Fidelius attribute (either C<fidelius:self> or 
C<fidelius:child>) does not exist.  Note that this is not the same as the 
attribute being empty.

=back 4

=head1 ETYMOLOGY

The name "Fidelius" is based on a spell from J.K. Rowling's I<Harry Potter> 
series called the Fidelius Charm.  In the books, the Fidelius Charm is used to 
control who can disseminate a piece of information; it is similar in some ways 
to a DRM system, though far more potent and effective.

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Revision>, L<WWW::Kontent::Store>

=cut

module WWW::Kontent::Magic::Fidelius;
# Fidelius - Kontent access control system
# Named for J.K. Rowling's Fidelius Charm, a sort of magical DRM system.

my sub ck($request, $perms) {
#	say $ERR: "Running Fidelius check: $perms";
	# If they don't specify anything at all, assume anyone can access anything.
	return unless defined $perms;
	# No user means nobody to authenticate.
	return unless defined $request.user;
	
	# Otherwise, either the path to the user's page or the string "any" must be 
	# present in either all(foo bar/baz), $mode(foo bar/baz) or 
	# default(foo bar/baz) string.
	my $user = $request.user;
	my $userpath = $user<page>.path();
#	say $ERR: "    User: $userpath";

	my $pagepath = $request.pagepath;
	
	for "all", $pagepath.mode, "default" -> $mode {
#		say $ERR: "    Checking against modestring for $mode";
		if $perms ~~ m:perl5/\b\Q$mode\E\(([^)]*)\)/ {
#			say $ERR: "        $0";
			my $allowed = ~$0;
			if $allowed ~~ m:perl5/(?:^| )(?:any|\Q$userpath\E)\b/ {
#				say $ERR: "        OK";
				return;
			}
			elsif $allowed ~~ m:perl5/(?:^| )-(?:any|\Q$userpath\E)\b/ {
#				say $ERR: "        Blocked";
				last;
			}
		}
	}
#	say $ERR: "    Failed--throwing exception";
	WWW::Kontent::error("You are not permitted to view this page in '$pagepath.mode()' mode.", :code(403));
}

sub pre_resolve_handler($request, $args) {
	my($component, $in_rev) = *$args;
#	warn $request;
	if $request.userpath and $in_rev {
		# We've already resolved the user page
		my $page = $in_rev.resolve($component.name);
		my $rev  = $page.cur;					# Allows retroactive changes
		ck($request, $rev.attributes<fidelius:child>);
	}
}

sub pre_driver_handler($request, $args) {
	my($in_rev)=*$args;
	
	return if $in_rev.isa(WWW::Kontent::DraftRevision);
	
	my $page = $in_rev.page;
	my $rev  = $page.cur;
	ck($request, $rev.attributes<fidelius:self>);
}

WWW::Kontent::register_magic('pre', 'resolve', \&pre_resolve_handler);
WWW::Kontent::register_magic('pre', 'driver',  \&pre_driver_handler );