=head1 NAME

WWW::Kontent::Renderer::XML - XML renderer for Kontent

=head1 SYNOPSIS

	GET /path/to/page.xml

=head1 DESCRIPTION

The XML renderer renders a Kontent page into XML.  Currently it does this by 
listing the revision's attributes and then dumping the skeleton in an XML 
format.  The dumped skeleton contains everything necessary to recreate the 
skeleton later, makingit useful for syndicating content.

Note, however, that this is scheduled to change; at some point the 
attribute-dumping feature will move into a separate mode, and will be 
separately securable from the skeleton-dumping part.

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>

=cut

class WWW::Kontent::Renderer::XML is WWW::Kontent::Renderer;
WWW::Kontent::register_renderer('xml', ::WWW::Kontent::Renderer::XML);

method render(WWW::Kontent::Request $r) {
	$r.type = 'text/xml';
	my $page=$r.page;
	
	return [~] gather {		#Unexpected Perl 6 Win #1: functions that generate *ML.
		take qq(<?xml version="1.0" encoding="UTF-8"?>\n<kontent xmlns="http://kontent.brentdax.com/xml/1.0">\n) unless $r.nested;
		take qq(    <page location="{$page.path()}">\n);
		given $r.mode {
			when 'view' {
				take $?SELF.:dump($r.revision, $r);
			}
			when 'history' {
				for $page.revisions -> $rev {
					take $?SELF.:dump($rev, $r);
				}
			}
		}
		take qq(    </page>\n);
		take qq(</kontent>\n) unless $r.nested;
	}
}

method :dump($rev, $req) {
	return [~] gather {
		take qq(        <revision number="$rev.revno()">\n);
		my %attrs=$rev.attributes;
		for %attrs.keys -> $k {
			take qq(            <attribute name="$k"><![CDATA[$rev.attributes(){$k}]]></attribute>\n);
		}
		
		take qq(            <content>);
		my $skel=$rev.adapter($req);
		take $skel.process_xml();
		take qq(</content>\n);
		take qq(        </revision>\n);
	}
}

method :dumptags($self: $contents) {
#	die $contents.perl();
#	warn ref $contents, "($contents.elems())";
	return [~] gather {
		temp our $x = $x * 10;
		for *$contents {
			take "<!--\n {++$x}: {ref $_} -->";
			
			if $_ ~~ Str {
				take "<![CDATA[$_]]>";
			}
			else {
				take "<!-- first: {ref $_[0]} -->";
				take $self.:dumptag($_);
			}
		}
	};
}

method :dumptag($self: $tag) {
	return [~] gather {
		warn "dumptag: $tag.perl()";
		my ($tagname, $contents)=$tag<tag contents>;
		take "<$tagname";
		for $tag.kv -> $k, $v {
			next unless $k eq any <tag contents>;
			take " $k='$v'";
		}
		if $contents {
			my $in=$self.:dumptags($contents);
			take ">{$in}</$tagname>";
		}
		else {
			take " />"
		}
	}
}

class WWW::Kontent::Skeleton is extended {
	method process_xml() {
		return [~] gather {
			take "<{$.tagname}";
			
			if %.properties {
				for %.properties.kv -> $k, $v {
					take " $k='$v'";
				}
			}
			
			if @.children {
				take ">";
				for @.children {
					if $_ ~~ Str {
						take "<![CDATA[$_]]>";
					}
					else {
						take $_.process_xml();
					}
				}
				take "</{$.tagname}>";
			}
			else {
				take " />";
			}
		}
	}
}
