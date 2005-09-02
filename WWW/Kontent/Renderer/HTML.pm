=head1 NAME

WWW::Kontent::Renderer::HTML - HTML renderer for Kontent

=head1 SYNOPSIS

	GET /path/to/page.html
	GET /path/to/page

=head1 DESCRIPTION

The HTML render converts a Kontent skeleton to HTML.  In most cases this will 
be valid XHTML 1.0, and is DTDed as such; however, certain pathological 
skeletons (such as those containing empty lists or nested links) will not be.

This is by far the most complete renderer shipped with Kontent at this time, 
and it may be educational to see how it operates.

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>

The W3C XHTML 1.0 standard: L<http://www.w3.org/TR/xhtml1/>

=cut

class WWW::Kontent::Renderer::HTML is WWW::Kontent::Renderer;
WWW::Kontent::register_renderer('html', ::WWW::Kontent::Renderer::HTML);

use HTML::Entities;

has $.uri_prefix;

#XXX private and trusts instead of public...
method _makelink($request, $path is copy, ?$content is copy, ?$rev, ?$mode, ?$format) {
	if $rev    { $path ~= "[$rev]"    }
	if $format { $path ~= ".$format" }
	if $mode   { $path ~= "\{$mode}" }
	
	my($title, $class)=("(page does not exist)", " broken");
	if $path ~~ /\:/ {
		$title="External link: $path";
		$class=" external";
	}
	else {
		try {
			#warn "attempting to grok: $path";
			my @revs=$request.grok_link($path);
			#warn "link grokked: @revs[]";
			
			if @revs and @revs[0] {
				my $subrev = @revs[0];
				my $page = $subrev.page;
				$title=$subrev.attributes<kontent:title>;
				$path = "$.uri_prefix/$page.path()";
				$class="";
			}
		};
		if $! {
			#warn "failed";
			my $page = $.revision.page;
			$path = "$.uri_prefix/$page.path()/$path";
			#warn $!;
		}
	}

	$content //= $title;
	
	return qq(<a title="{HTML::Entities::encode_entities($title)}" class="pagelink$class" href="{HTML::Entities::encode_entities($path)}">{$content}</a>);
}

method render(WWW::Kontent::Request $r) {
	$r.type = 'text/html';
	
	WWW::Kontent::Supervisor::emit_header();
			
	my $rev  = $r.revision;
	my $page = $r.page;
	my $path = $page.path;
	 
	my $title = $rev.attributes<kontent:title>;
	my $content = "";
	
	my $uri_prefix = WWW::Kontent::setting("uri_prefix");
	$.uri_prefix = $uri_prefix;
	
	my @modes=$rev.modelist($r);
	my $modelinks=[~] map {
			qq(<li id="modelinks-$_")
				~ ($_ eq $r.mode ?? qq( class="selected") :: "") ~
			qq(><a href="$uri_prefix/{$path}\{$_}">{ucfirst $_}</a></li>)
		} @modes;
	
	given $r.mode {
		when 'history' {
			$content = [~] gather {
				take qq(<h2>$title (revision history)</h2>\n);
				take qq(<table id="revhisttable">\n    <tr><th>Date</th><th>Author</th><th>Log Message</th></tr>\n);
				for reverse $page.revisions {
					my $l=localtime $_.attributes<rev:date>;
					take qq(    <tr>
        <td class="revhisttable-date">
        	{$?SELF._makelink($r, $path,
        		sprintf("%4d-%.2d-%.2d&nbsp;%.2d:%02d",  $l.year, $l.month, $l.day, $l.hour, $l.min), :rev($_.revno))}
        </td>
        <td class="revhisttable-author">
        	{$?SELF._makelink($r, $_.attributes<rev:author>)}
        </td>
        <td class="revhisttable-log">
        	{$_.attributes<rev:log>}
        </td>
    </tr>
);
				}
				take qq(</table>);
			}
		}
		default {
			#warn "running adapter";
			my $skel = $rev.adapter($r);
			#warn "processing skeleton";
			$content = [~] $?SELF.:process_skel($skel, $r);
			#warn "building page";
		}
	}
	
	return $content if $r.nested;
	
	my $sitename=WWW::Kontent::setting("site_name") // "(Edit kontent/settings/site_name)";
	my $css=WWW::Kontent::setting("html_styles") // '';
	my $user=$r.user;
	my $username=$user.attributes<kontent:title>;
	my $userpath=$user.page();
	$userpath=$userpath.path();
	my $template=WWW::Kontent::setting("html_template");
	
	#This treats $template as a double-quoted string with nulls as delimiters.
	return eval "qq\0$template\0";
}

method :process_skel($self: $node, $request) {
	#warn "processing $node.id() ($node.tagname())";
	#warn $node.perl();
	given $node.tagname {
		when 'skeleton' | 'null' {
			return $self.:call_skel($node, $request);
		}
		when 'header' {
			my $l=$node.properties<level>+2;
			return "<h$l>", $self.:call_skel($node, $request), "</h$l>";
		}
		when 'paragraph' {
			return "<p>", $self.:call_skel($node, $request), "</p>";
		}
		when 'list' {
			my %tags=( bulleted => 'ul', numbered => 'ol', definition => 'dl');
			temp our $tag=%tags{$node.properties<type>};
			return "<$tag>", $self.:call_skel($node, $request), "</$tag>";
		}
		when 'item' {
			my $thistag='li';
			our $tag;
			if $tag eq 'dl' {
				if $node.properties<type> eq 'term' {
					$thistag = 'dt';
				}
				else {
					$thistag = 'dd';
				}
			}
			return "<$thistag>", $self.:call_skel($node, $request), "</$thistag>";
		}
		when 'table' {
			return "<table>", $self.:call_skel($node, $request), "</table>";
		}
		when 'row' {
			return "<tr>", $self.:call_skel($node, $request), "</tr>";
		}
		when 'cell' {
			my $tag = $node.properties<type> eq 'header' ?? 'th' :: 'td';
			return "<$tag>", $self.:call_skel($node, $request), "</$tag>";
		}
		when 'link' {
			return $self._makelink($request, $node.properties<location>, $self.:call_skel($node, $request));
		}
		when 'transclude' {
			my $subr = $request.subrequest($node.properties<location>, hash { content => $self.:call_skel($node, $request) });
			return $subr.go();
		}
		when 'emphasis' {
			return "<em>", $self.:call_skel($node, $request), "</em>";
		}
		when 'strong' {
			return "<strong>", $self.:call_skel($node, $request), "</strong>";
		}
		when 'title' {
			return "<cite>", $self.:call_skel($node, $request), "</cite>";
		}
		when 'struck' {
			return "<strike>", $self.:call_skel($node, $request), "</strike>";
		}
		when 'superscript' {
			return "<sup>", $self.:call_skel($node, $request), "</sup>";
		}
		when 'subscript' {
			return "<sub>", $self.:call_skel($node, $request), "</sub>";
		}
		when 'code' {
			my $tag = $node.properties<type> eq 'paragraph' ?? "pre" :: "code";
			temp our $skip_whitespace_escape = 1;
			return "<$tag>", $self.:call_skel($node, $request), "</$tag>";
		}
		when 'form' {
			my $rev=$request.revision;
			my $page=$rev.page;
			my $path=$page.path;
			
			return qq(<form method="post" action="$.uri_prefix/$path\.$request.format()\{$request.mode()\}">),
						$self.:call_skel($node, $request), "</form>";
		}
		when 'textfield' {
			my $value=$node.properties<value>;
			HTML::Entities::encode_entities($value);
			
			return gather {
				if $node.properties<label> {
					take qq(<label for="{$node.properties<name>}" class="text">{$node.properties<label>}:&nbsp;</label>);
				}
				
				if $node.properties<type> eq 'multiline' {
					take qq(<textarea name="{$node.properties<name>}">{$value}</textarea>);
				}
				else {
					take qq(<input type="{$node.properties<type> eq 'masked' ?? 'password' :: 'text'}" class="text" name="{$node.properties<name>}" value="{$value}" />);
				}
			}
		}
		when 'boolfield' {			
			return gather {
				take qq(<input type="checkbox" class="bool" name="{$node.properties<name>}" {$node.properties<value> && "checked "}/>);
				
				if $node.properties<label> {
					take qq(<label for="{$node.properties<name>}" class="bool">{$node.properties<label>}</label>);
				}
			}
		}
		when 'metafield' {
			return qq(<input type="hidden" name="{$node.properties<name>}" value="{$node.properties<value>}" />);
		}
		when 'choicefield' {
			temp our $choicetype;
			if $node.properties<type> eq 'action' {
				$choicetype = "action";
				return qq(<div class="action">),
							$self.:call_skel($node, $request),
							qq(</div>);
			}
			else {
				$choicetype = "option";
				return qq(<select name="{$node.properties<name>}">),
							$self.:call_skel($node, $request),
							qq(</select>);
			}
		}
		when 'choice' {
			our $choicetype;
			if $choicetype eq 'action' {
				return qq(<button type="submit" name="action" value="{$node.properties<value>}">),
							$self.:call_skel($node, $request), qq(</button>);
			}
			else {
				return qq(<option value="{$node.properties<value>}">),
							$self.:call_skel($node, $request), qq(</option>);
			}
		}
		when '!' {
			return qq(<div class="warning" title="{$node.properties<message>}">!</div>);
		}
		default { return "<!-- unknown skeleton node: $_ -->", $self.:call_skel($node, $request) }
	}
}

method :call_skel($self: $node, $request) {
	#warn "processing children of $node.id() ($node.tagname())";
	return gather {
		for $node.children -> $_ is copy {
			#warn "    child: $_.id()";
			if $_ ~~ Str {
				my $str=HTML::Entities::encode_entities($_);
				our $skip_whitespace_escape;
				unless $skip_whitespace_escape {
					$str ~~ s:g{\	}{&nbsp;&nbsp;&nbsp; };
					$str ~~ s:g{\ \ }{&nbsp; };
					$str ~~ s:g{\015}{};
					$str ~~ s:g{\n}{<br />};
				}
				take $str;
			}
			else {
				take $self.:process_skel($_, $request);
			}
		}
	}
}
