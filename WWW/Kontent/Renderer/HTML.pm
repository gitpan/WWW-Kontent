class WWW::Kontent::Renderer::HTML is WWW::Kontent::Renderer;
WWW::Kontent::register_renderer('html', ::WWW::Kontent::Renderer::HTML);

use HTML::Entities;

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
			my $pathobj=WWW::Kontent::Path.new().parse($path);
			my $subrev=$pathobj.resolve($request.root);
			
			$title=$subrev.attributes<kontent:title>;
			$class="";
			$path = "/kontent/$path";
		};
	}

	$content //= $title;
	
	return qq(<a title="{HTML::Entities::encode_entities($title)}" class="pagelink$class" href="{HTML::Entities::encode_entities($path)}">{$content}</a>);
}

method render(WWW::Kontent::Request $r) {
	$r.type = 'text/html';
			
	my $rev  = $r.revision;
	my $page = $r.page;
	my $path = $page.path;
	
	my $title = $rev.attributes<kontent:title>;
	my $content = "";
	
	given $r.mode {
		when 'history' {
			$title ~= " (revision history)";
			$content = [~] gather {
				take qq(<table id="revhisttable">\n    <tr><th>Date</th><th>Author</th><th>Log Message</th></tr>\n);
				for reverse $page.revisions {
					my $l=localtime $_.attributes<rev:date>;
					take qq(    <tr>
        <td class="revhisttable-date">
        	{$?SELF._makelink($r, $path, "$l.year()-$l.month()-{$l.day} $l.hour():$l.min()", :rev($_.revno))}
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
			my $skel = $rev.adapter($r);
			$content = $?SELF.:process_skel($skel, $r);
		}
	}
	
	return $content if $r.nested;
	return qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US" lang="en-US">
<head>
	<title>{$title}</title>
	<style type="text/css">
		html {
			background-color: #202040;
			padding: 0 10%;
		}
		body {
			margin: 0;
			padding: 0 1em;
			
			color: black;
			background-color: #E8E8FF;
			font-family: "Trebuchet MS", sans-serif;
			
			width: 100%;
		}
		#content \{ min-height: 100% }
		h1,h2,h3,h4,h5,h6 { color: #202040; font-family: Georgia, sans-serif; margin-top: 1em; margin-bottom: 0.5em; }
		h1 { margin: 0 }
		#revhisttable \{ width: 100% }
		.revhisttable-author, .revhisttable-date \{ width: 18ex }
		#modelinks \{ font-size: smaller; margin: 0; padding: 0 }
		#modelinks li \{ float: left; margin: 0 2ex 1em 0; padding: 0; list-style-type: none }
		#modelinks #modelinks-export \{ float: right; margin-left: 2ex; margin-right: 0 }
		#body \{ clear: both }
		.broken \{ color: red }
		label.text \{ width: 17%; text-align: right; float: left; }
		input.text \{ width: 82%; }
		textarea \{ width: 99%; height: 25em; }
		div.action \{ text-align: center; }
		div.action button \{ margin: 0 1ex; }
		#copyright \{ text-align: center; font-size: smaller; font-style: italic; padding: 1ex }
	</style>
</head>
<body>
	<div id="container">
		<h1>{$title}</h1>
		<ul id="modelinks">
			<li id="modelinks-page">   <a title="View the page's content" href="/kontent/{$path}">Page</a>                     </li>	
			<li id="modelinks-edit">   <a title="Edit this page" href="/kontent/{$path}\{edit}">Edit</a>                        </li>
			<li id="modelinks-add">    <a title="Create a subpage" href="/kontent/{$path}\{create}">Create</a>                  </li>
			<li id="modelinks-history"><a title="View the page's revision history" href="/kontent/{$path}\{history}">History</a></li>
			<li id="modelinks-export"> <a title="View an XML dump of the page" href="/kontent/{$path}.xml">Export</a>          </li>
		</ul>
		<div id="body">
$content
		</div>
		<div id="copyright">&copy; 2005 Contributors.  All rights reserved.</div>
	</div>
</body>
</html>);
}

method :process_skel($self: $node, $request) {
	given $node.tagname {
		when 'skeleton' {
			return $self.:call_skel($node, $request);
		}
		when 'header' {
			my $l=$node.properties<level>+1;
			return [~] "<h$l>", $self.:call_skel($node, $request), "</h$l>";
		}
		when 'paragraph' {
			return [~] "<p>", $self.:call_skel($node, $request), "</p>";
		}
		when 'list' {
			my $tag=$node.properties<type> eq 'bulleted' ?? 'ul' :: 'ol';
			return [~] "<$tag>", $self.:call_skel($node, $request), "</$tag>";
		}
		when 'item' {
			return [~] "<li>", $self.:call_skel($node, $request), "</li>";
		}
		when 'link' {
			return $self._makelink($request, $node.properties<location>, $self.:call_skel($node, $request));
		}
		when 'form' {
			my $rev=$request.revision;
			my $page=$rev.page;
			my $path=$page.path;
			
			return [~] qq(<form method="get" action="/kontent/$path\.$request.format()\{$request.mode()\}">),
						$self.:call_skel($node, $request), "</form>";
		}
		when 'textfield' {
			my $value=$node.properties<value>;
			HTML::Entities::encode_entities($value);
			
			return [~] gather {
				if $node.properties<label> {
					take qq(<label for="{$node.properties<name>}" class="text">{$node.properties<label>}:&nbsp;</label>);
				}
				
				if $node.properties<type> eq 'multiline' {
					take qq(<textarea name="{$node.properties<name>}">{$value}</textarea>);
				}
				else {
					take qq(<input type="text" class="text" name="{$node.properties<name>}" value="{$value}" />);
				}
			}
		}
		when 'boolfield' {			
			return [~] gather {
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
				return [~] qq(<div class="action">),
							$self.:call_skel($node, $request),
							qq(</div>);
			}
			else {
				$choicetype = "option";
				return [~] qq(<select name="{$node.properties<name>}">),
							$self.:call_skel($node, $request),
							qq(</select>);
			}
		}
		when 'choice' {
			our $choicetype;
			if $choicetype eq 'action' {
				return [~] qq(<button type="submit" name="action" value="{$node.properties<value>}">),
							$self.:call_skel($node, $request), qq(</button>);
			}
			else {
				return [~] qq(<option value="{$node.properties<value>}">),
							$self.:call_skel($node, $request), qq(</option>);
			}
		}
		default { return [~] "<!-- unknown skeleton node: $_ -->", $self.:call_skel($node, $request) }
	}
}

method :call_skel($self: $node, $request) {
	return [~] gather {
		for $node.children -> $_ is copy {
			if $_ ~~ Str {
				my $str=HTML::Entities::encode_entities($_);
				$str ~~ s:g{\	}{&nbsp;&nbsp;&nbsp; };
				$str ~~ s:g{\ \ }{&nbsp; };
				$str ~~ s:g{\n}{<br />};
				take $str;
			}
			else {
				take $self.:process_skel($_, $request);
			}
		}
	}
}
