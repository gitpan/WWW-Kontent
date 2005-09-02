=head1 NAME

WWW::Kontent::Class::Kiki - Kiki page class for Kontent

=head1 SYNOPSIS

	# Attributes
	kontent:class=kiki
	kontent:version=1
	kiki:content=Page's content
	kiki:type=text/x-kolophon

=head1 DESCRIPTION

Kiki is a page class for a general-purpose text page.  Besides the title, it 
contains only a single body of text, which is parsed of markup (as Kolophon by 
default).  It does not attempt to block anyone from editing; an access control 
system such as L<WWW::Kontent::Magic::Fidelius> can be used to limit editing 
privileges.

=head2 Attributes

Kontent pages are sensitive to the following attributes:

=over 4

=item C<kiki:content>

The text of the page.

=item C<kiki:type>

The MIME type of the text.  Defaults to text/x-kolophon.

=back 4

Kiki's behavior is also affected by standard attributes, such as 
C<kontent:title>, and attributes controlling the behavior of any magic modules 
enabled in your Kontent instance.

=head2 MODES

view, history, create, edit

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>

=cut

class WWW::Kontent::Class::Kiki is WWW::Kontent::Class;
WWW::Kontent::register_class('kiki', $?CLASS);

has $.draftrev;

submethod BUILD() {
	my $r=.revision;
	$r.attributes<kontent:version> == 1 or die "Can't handle a version {$r.attributes<kontent:version>} Kiki page";
}

method create_(Str $name is copy) {
	my $draftpage = $_.WWW::Kontent::Class::create_($name);
	my $rev = $draftpage.draft_revision;
	
	$rev.attributes<kontent:class>   = 'kiki';
	$rev.attributes<kontent:version> = 1;
	
	return $draftpage;
}

method driver_(WWW::Kontent::Request $request) {
	# This method is Complicated because, if we're processing a 'create' or 
	# 'edit' mode request, we want to allocate a draft revision or page, and 
	# let the draft revision handle the actual processing.  (This allows a 
	# subclass's create() override to say 
	# `$rev.attributes<kontent:class>='somethingelse'` and DTRT.)
	
	unless $.revision.isa(WWW::Kontent::DraftRevision) {
		# This is a normal revision...
		if $request.mode eq 'create' | 'edit' {
			# which is about to acquire an inner revision it should dispatch 
			# to.  Create the inner revision and call its driver.
			.:inner_driver($request);
		}
	}
	else {
		# This is a draft revision of some sort, so we need to build it from 
		# a combination of user parameters, stuff the revision it's based on 
		# knew, and defaults.
		my $p=$request.parameters;
		
		$.revision.revno = $p<revno> // $.revision.revno;
		$.revision.attributes<kiki:type>     = 'text/x-kolophon';
		$.revision.attributes<rev:author>    = $request.user_pathstr;
		$.revision.attributes<rev:log>       = $p<log> // '';
		
		$.revision.attributes<kontent:title> =
			$p<title>   // $.revision.attributes<kontent:title>;
		$.revision.attributes<kiki:content>  =
			$p<content> // $.revision.attributes<kiki:content>;
		
		my $page=$.revision.page;
		unless defined $page.name {
			# Derive the default name from the title, but normalized to 
			# lowercase, spaces replaced by underscores and repeated sequences 
			# squashed, and everything else deleted entirely.
			my $name = lc $.revision.attributes<kontent:title>;
			$name ~~ s:g/<[ _]>+/_/;
			$name ~~ s:g/\W//;
			$page.name = $name;
		}
		
		if $request.mode eq 'create' | 'edit' and $p<action> eq 'save' {
			$.revision.attributes<kiki:content> ~~ s:g{\n}{\n};		#Get rid of \r
			# Save all that hard work!
			$.revision.commit;
		}
	}
}

method :inner_driver($request) {
	if $request.mode eq 'create' {
		# Create the draft page and retrieve the draft revision from it.
		my $draftpage = $.revision.create(undef);
		$.draftrev = $draftpage.draft_revision;
	}
	else {
		# Create the draft revision.  (The current revision's revno has 
		# to be used here, but the current revision is the one being 
		# revised.)
		my $page = $.revision.page;			# XXX pugsbug
		my $cur  = $page.cur;
		$.draftrev = $.revision.revise($cur.revno + 1);
	}
	
	my $draftrev=$.draftrev;
	$.draftrev.driver($request);
}

method adapter_(WWW::Kontent::Request $request) {
	my $rev=.revision;
	my $page=$rev.page;
	
	if $.draftrev {
		return $.draftrev.adapter($request);
	}
	else {
		my $skel=WWW::Kontent::Skeleton.new();
		given $request.mode {
			when 'create' | 'edit' {
				my $ing = $request.mode eq 'create' ?? 'creating' :: 'editing';
				
				$skel.add_node('header', :level<0>);
				$skel.children[-1].add_text("{$rev.attributes<kontent:title> // 'Unnamed'} ($ing)");
				
				if $request.parameters<action> eq 'save' {
					$skel.add_node('paragraph');
					$skel.children[-1].add_text("Your revisions have been saved.  ");
					$skel.children[-1].add_node('link', :location($page.path));
					$skel.children[-1].children[-1].add_text("View the revised page...");
				}
				else {
					if $request.parameters<action> eq 'preview' {
						$skel.add_node('header', :level(1));
						$skel.children[-1].add_text("Preview changes");
						
						if $request.mode eq 'create' {
							$skel.add_text("Page name: $page.name()\n");
						}
						
						$skel.children.push(
							WWW::Kontent::parse(
								$request.parameters<content>, 
								$.revision.attributes<kiki:type>, $request
							)
						);
					}
					
					$skel.add_node('header', :level(1));
					$skel.children[-1].add_text(
						$request.mode eq 'create'
					??  "Create Kiki page"
					::  "Edit Kiki page");
					
					my $f=$skel.add_node('form');
					$f.add_node('paragraph');
					$f.add_node('paragraph');
					
					$f.children[0].add_node('textfield', :name<title>, :label<Title>,
						:value($rev.attributes<kontent:title>)
					);
					$f.children[0].add_text("\n");
					$f.children[0].add_node('textfield', :name<content>, 
						:value($rev.attributes<kiki:content>), :type<multiline>);
					
					$f.children[1].add_node('textfield', :name<log>, :label("Log message"),
						:value($rev.attributes<rev:log>)
					);
					$f.children[1].add_text("\n");
					
					my $c=$f.children[1].add_node('choicefield', :type<action>);
					
					$c.add_node('choice', :value<save>);
					$c.children[0].add_text("Save changes");
					
					$c.add_node('choice', :value<preview>);
					$c.children[1].add_text("Preview changes");
				
					$f.add_node('metafield', :name<revno>, :value($rev.revno));
				}
			}
			default {
				$skel.add_node('header', :level<0>);
				$skel.children[-1].add_text(~$rev.attributes<kontent:title>);
				$skel.children.push(WWW::Kontent::parse(~$rev.attributes<kiki:content>, ~$rev.attributes<kiki:type>, $request));
			}
		}
		return $skel;
	}
}

method modelist_(WWW::Kontent::Request $request) {
	return <view history create edit>
}