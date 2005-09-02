=head1 NAME

WWW::Kontent::Class::Kode - Kode page class for Kontent

=head1 SYNOPSIS

	# Attributes
	kontent:class=kode
	kontent:version=1
	kode:driverbody=Driver code
	kode:adapterbody=Adapter code

=head1 DESCRIPTION

Kode is a Kontent class allowing you to write a page with unique behavior.  In 
essence, it can be used to implement the 'view' driver and adapter for a 
one-shot page class.  The edit mode can be used to modify the code, and the 
details of compilation errors are displayed.

Please note that the Kode class can be used to run arbitrary code on the server.
You should probably secure Kode pages very carefully.

=head2 Attributes

=over 4

=item C<kode:driverbody>

The code to be run for the driver in 'view' mode.

=item C<kode:adapterbody>

The code to be run for the adapter in 'view' mode.  As with all adapters, this 
should return a skeleton (L<WWW::Kontent::Skeleton>).

=back 4

=head2 Modes

view, history, edit

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>

=cut

class WWW::Kontent::Class::Kode is WWW::Kontent::Class;
WWW::Kontent::register_class('kode', $?CLASS);

has $.draftrev;
has $.driver_body;
has $.adapter_body;

has %.notes;

method driver_(WWW::Kontent::Request $request) {
	my $rev=.revision;
	given $request.mode {
		when 'view' {
			$.driver_body  = eval(q(sub ($request, $revision) { \qq[ { $rev.attributes<kode:driverbody>  } ] })) // $!;
			$.adapter_body = eval(q(sub ($request, $revision) { \qq[ { $rev.attributes<kode:adapterbody> } ] })) // $!;
			
			if $.driver_body and $.adapter_body {
				$.driver_body($request, $rev);
			}
		}
		when 'create'|'edit' {
			if $rev.isa(WWW::Kontent::DraftRevision) {
				my $p = $request.parameters;
				
				given $rev.attributes {
					$_<kontent:title>   = $p<title>       // $_<kontent:title>;
					$_<kode:driverbody> = $p<driverbody>  // $_<kode:driverbody>;
					$_<kode:adapterbody>= $p<adapterbody> // $_<kode:adapterbody>;
					$_<rev:log>         = $p<log>;
					$_<rev:author>     = $request.user_pathstr;
				}
				
				if $p<action> eq 'save' {
					if $request.mode eq 'create' {
						my $page = $rev.page;
						
						my $name = lc $.revision.attributes<kontent:title>;
						$name ~~ s:g/<[ _]>+/_/;
						$name ~~ s:g/\W//;
						$page.name = $name;
					}
					$rev.commit();
				}
			}
			else {
				$.draftrev = $rev.revise($request.parameters<revno> // $rev.revno + 1);
				$.draftrev.driver($request);
			}
		}
	}
}

method adapter_(WWW::Kontent::Request $request) {
	my $rev=.revision;
	my $page=$rev.page;
	
	if $.driver_body.isa(Code) and $.adapter_body.isa(Code) {
		# Everything was compiled, and compiled correctly, so execute the adapter.
		return $.adapter_body($request, .revision);
	}
	elsif $.draftrev {
		return $.draftrev.adapter($request);
	}
	else {
		my $skel = WWW::Kontent::Skeleton.new;
		given $request.mode {
			when 'view' {
				# If we got here, either the driver or adapter didn't compile properly, so we should whine about it.
				
				$skel.add_node('heading', :level<0>);
				$skel.children[-1].add_text("Code: {$rev.attributes<kontent:title>} (view error)");
				
				unless $.driver_body.isa(Code) {
					$skel.add_node('paragraph');
					$skel.children[-1].add_text("An error occured while compiling the driver code: $.driver_body.");
				}
				unless $.adapter_body.isa(Code) {
					$ksel.add_node('paragraph');
					if $.driver_body.isa(Code) {
						$skel.children[-1].add_text("An ");
					}
					else {
						$skel.children[-1].add_text("Additionally, an ");
					}
					
					$skel.children[-1].add_text("error occurred while compiling the adapter code: $.adapter_body.");
				}
				
				$skel.add_node('paragraph');
				$skel.children[-1].add_text("If you have the necessary permissions, please edit this page to correct the error.");
			}
			when 'create'|'edit' {
				my $ing = ($_ eq 'create' ?? 'creating' :: 'editing');
				$skel.add_node('header', :level<0>);
				$skel.children[-1].add_text("Code: {$rev.attributes<kontent:title>} ($ing)");
				
				if $request.parameters<action> eq 'save' {
					$skel.add_node('paragraph');
					$skel.children[-1].add_text("Your revisions have been saved.  ");
					$skel.children[-1].add_node('link', :location($page.path));
					$skel.children[-1].children[-1].add_text("View the revised page...");
				}
				else {
					my $f=$skel.add_node('form');
					$f.add_node('textfield', :name<title>, :label<Title>, 
								:value($rev.attributes<kontent:title>));
					$f.add_node('textfield', :name<driverbody>, :label("Driver body"),
								:value($rev.attributes<kode:driverbody>),  :type<multiline>);
					$f.add_node('textfield', :name<adapterbody>, :label("Adapter body"),
								:value($rev.attributes<kode:adapterbody>), :type<multiline>);
					$f.add_node('textfield', :name<log>, :label("Log message"),
								:value($rev.attributes<rev:log>));
					$f.add_node('choicefield', :type<action>);
					$f.children[-1].add_node('choice', :value<save>);
					$f.children[-1].children[-1].add_text("Save changes");
					$f.add_node('metafield', :name<revno>, :value($rev.revno));
				}
			}
		}
		return $skel;
	}
}

method modelist_(WWW::Kontent::Request $request) {
	return <view history edit>;
}