=head1 NAME

WWW::Kontent::Class::Setting - Page class for a setting in Kontent

=head1 SYNOPSIS

	# Attributes
	kontent:class=setting
	kontent:version=1
	setting:value=the setting's value
	setting:desc=documentation about the setting
	setting:desctype=text/x-kolophon

=head1 DESCRIPTION

Setting is a page class representing a Kontent setting.

B<Note>: Settings are fairly magical pages, and Kontent's core is sensitive to 
their internal structure.  Settings should only be placed under the 
C</kontent/settings> page in your Kontent store, and should never have child 
pages.  However, it is safe to create settings with names Kontent doesn't use.

Each setting has a value and a description; the description serves as 
documentation of the setting's meaning.  Both values and descriptions can be
edited through the page's 'edit' mode, although the description is usually 
left alone.

Internally, settings are retrieved through the C<WWW::Kontent::setting> 
function.  Settings are usually interpreted as simple text strings, but are 
sometimes treated as YAML documents or interpolated like Perl 6 string literals;
this should be noted in the description.

=head2 Attributes

=over 4

=item C<setting:value>

The value of the setting.

=item C<setting:desc>

The setting's description.

=item C<setting:desctype>

The MIME type of the description.  Defaults to C<text/x-kolophon>.

=back 4

=head2 Modes

view, history, edit

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>

=cut

class WWW::Kontent::Class::Setting is WWW::Kontent::Class;
WWW::Kontent::register_class('setting', $?CLASS);

has $.draftrev;

method create_(Str $name) {
	WWW::Kontent::error("Can't create a subpage of a Setting", :code(403));
}

method driver_($request) {
	if $request.mode eq 'create' | 'edit' {
		my $rev = .revision;
		if $rev.isa(WWW::Kontent::DraftRevision) {
			my $p = $request.parameters;
			$rev.revno = $p<revno> // $rev.revno;
			
			given $rev.attributes {
				if $request.mode eq 'create' {
					$_<kontent:title> = lc $p<title> // ~$_<kontent:title>;
					$_<kontent:title> ~~ s:g/<[ _]>+/_/;
					$_<kontent:title> ~~ s:g/\W//;
					
					my $page=$rev.page;
					$page.name = $_<kontent:title>;
				}
				
				$_<setting:desc>  = $p<desc>  // ~$_<setting:desc>;
				$_<setting:value> = $p<value> // ~$_<setting:value>;
				$_<rev:log>	      = $p<log>;
				
				$_<setting:desctype>  //= 'text/x-kolophon';
				$_<rev:author>    = $request.user_pathstr;
			}
			
			if $p<action> eq 'save' {
				$rev.commit();
			}
		}
		else {
			my $page = $rev.page;
			my $cur  = $page.cur;
			$.draftrev = $rev.revise($cur.revno + 1);
			$.draftrev.driver($request);
		}
	}
}

method adapter_($request) {
	my $skel=WWW::Kontent::Skeleton.new;
	my $rev = .revision;
	my $page= $rev.page;
	
	return $.draftrev.adapter($request) if $.draftrev;
	
	given $request.mode {
		when 'edit' | 'create' {
			$skel.add_node('header', :level<0>);
			$skel.children[-1].add_text("Setting: " ~ $rev.attributes<kontent:title> ~ " (editing)");
			if $request.parameters<action> eq 'save' {
				$skel.add_node('paragraph');
				$skel.children[-1].add_text("Your revisions have been saved.  ");
				$skel.children[-1].add_node('link', :location($page.path));
				$skel.children[-1].children[-1].add_text("View the revised page...");
			}
			else {
				$skel.add_node('header', :level<1>);
				$skel.children[-1].add_text("Edit setting");
				
				my $f = $skel.add_node('form');
				if $_ eq 'create' {
					$f.add_node('textfield', :name<title>, :label<Title>,
								:value(~$rev.attributes<kontent:title>));
				}
				
				$f.add_node('textfield', :name<value>, :label<Value>, :type<multiline>, 
							:value(~$rev.attributes<setting:value>));
				$f.add_node('textfield', :name<desc>, :label<Description>, :type<multiline>
							:value(~$rev.attributes<setting:desc>));
				$f.add_node('textfield', :name<log>, :label("Log message"), 
							:value($request.parameters<log>));
				
				my $c = $f.add_node('choicefield', :type<action>);
				$c.add_node('choice', :value<save>);
				$c.children[-1].add_text('Save changes');
			}
		}
		default {
			$skel.add_node('header', :level<0>);
			$skel.children[-1].add_text("Setting: "~$rev.attributes<kontent:title>);
			
			$skel.add_node('list', :type<definition>);
			
			$skel.children[-1].add_node('item', :type<term>);
			$skel.children[-1].children[-1].add_text("Current value");
			$skel.children[-1].add_node('item');
			$skel.children[-1].children[-1].add_node('code', :type<paragraph>);
			$skel.children[-1].children[-1].children[-1].add_text(~$rev.attributes<setting:value>);
			
			$skel.children[-1].add_node('item', :type<term>);
			$skel.children[-1].children[-1].add_text("Description");
			$skel.children[-1].add_node('item');
			$skel.children[-1].children[-1].children = [ WWW::Kontent::parse(
				~$rev.attributes<setting:desc>, 
				~$rev.attributes<setting:desctype>,
				$request
			) ];
		}
	}
	
	return $skel;
}

method modelist_(WWW::Kontent::Request $request) {
	return <view history edit>;
}