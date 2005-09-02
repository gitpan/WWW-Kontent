=head1 NAME

WWW::Kontent::Parser::Kolophon - Kolophon parser for Kontent

=head1 SYNOPSIS

	my $skel=WWW::Kontent::parse($text, 'text/x-kolophon', $request);

=head1 DESCRIPTION

Kolophon is a markup language specifically designed for use with Kontent.  A 
complete document (in Kolophon) describing the language is available in the 
F<pages/kolophon.kol> file of your Kontent distribution, and on most 
Kontent-based sites can be accessed with the path F<help/kolophon>.

This module is a parser for Kolophon, intended for use through the 
C<WWW::Kontent::parse> function by adapters.  It registers itself to handle the 
MIME type C<text/x-kolophon>.

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Foundation>

=cut

module WWW::Kontent::Parser::Kolophon;

my $parser_regex=rx+^(.*?)(\*\*|//|__|==|""|``|\^\^|\,\,|\[\[|\]\]|\{\{|\}\}|\<\<|\>\>|\\\\|\|\||\@\@|\&[\^|\+|\<-|-\>|\<\<|\>\>|``?|''?|"|\||--|-|_])+;

# XXX pugsbug
# The above regex is compressed as small as possible to avoid a Pugs bug.  
# It's somewhat more readable when rendered like this:
#my $parser_regex=rx+
#^	(.*?)
#	(	\*\* |  //  |  __  |  ==  |  ""  |  ``  | \^\^ | \,\,
#	|	\[\[ | \]\] | \{\{ | \}\} | \<\< | \>\>
#	|	\\\\ | \|\| | \@\@
#	|	\& [ \^ | \+ | \<- | -\> | \<\< | \>\> | ``? | ''? | " | \| | -- | - | _ ]
#	)
#+;

use WWW::Kontent::Skeleton;
WWW::Kontent::register_parser('text/x-kolophon', &parse);

our $PROGRESS=0;			# Turn this on to receive loads of tracing output

my %basic is constant=(
	'**'	=> 'strong',
	'//'	=> 'emphasis',
	'__'	=> 'title',
	'=='	=> 'struck',
	'^^'	=> 'superscript',
	',,'	=> 'subscript'
);
my %literal is constant=(
	'""'	=> 'null',
	'``'	=> 'code'
);
my %open  is constant=(
	"[["	=> 'link',
	"{{"	=> 'transclude',
	"<<"	=> 'relate'
);
my %close is constant=(
	"]]"	=> 'link',
	"}}"	=> 'transclude',
	">>"	=> 'relate'
);
my %char is constant=(
	'&+'	=> '&',
	'&--'	=> "\x2014",
	'&-'	=> "\x2013",
	'&|'	=> '\\',
	'&^'	=> "\n",
	'&<-'	=> "\x2190",
	'&->'	=> "\x2192",
	'&``'	=> "\x201c",
	'&"'	=> "\x201d",
	"&''"	=> "\x201d",
	"&`"	=> "\x2018",
	"&'"	=> "\x2019",
	'&<<'	=> "\xab",
	'&>>'	=> "\xbb",
	'&_'	=> ' '
);

my sub do_text($origtext, $request) {
	my $base=WWW::Kontent::Skeleton.new;
	my @stack=($base,);
	my @offstack=[0];
	my $pos=0;
	
	my $text = $origtext;
	say $ERR: "Parsing $origtext.chars() chars of text" if $PROGRESS;
	
	while $text ~~ $parser_regex {
		my($chunk, $tag)=(~$0, ~$1);
		my $length = "$0$1".chars;
		$pos += $length;
		
		say $ERR: "	At $pos [offstack @offstack[]]" if $PROGRESS;
		say $ERR: "		$chunk.chars() literal chars followed by tag '$tag'" if $PROGRESS;
		
		if $chunk.chars {
			$chunk ~~ s:g{\s+}{ };
			@stack[-1].add_text($chunk);
		}
		given $tag {
			when "\\\\" {
				# nothing
			}
			when any(keys %basic) {
				my $tagname=%basic{$_};
				if @stack[-1].tagname eq $tagname {
					@stack.pop;
				}
				else {
					@stack[-1].add_node($tagname);
					push @stack, @stack[-1].children[-1];
				}
			}
			when any(keys %literal) {
				my $tagname=%literal{$_};
				
				if grep { .tagname eq $tagname } @stack {
					@stack.pop until @stack[-1].tagname eq $tagname;
					@stack[-1].children = [];
					@stack[-1].add_text(~$origtext.substr(@offstack[-1], $pos-@offstack[-1]-2));
					@stack.pop;
					@offstack.pop;
				}
				else {
					@stack[-1].add_node($tagname);
					push @stack, @stack[-1].children[-1];
					push @offstack, $pos;
				}
			}
			when any(keys %open) {
				my $tagname=%open{$_};
				@stack[-1].add_node($tagname);
				push @stack, @stack[-1].children[-1];
				push @offstack, $pos;
				
				@stack[-1].properties = hash();
			}
			when "@@" | "||" {
				# XXX likely bugs surrounding this thing's behavior in "" and ``
				my $value = ~$origtext.substr(@offstack[-1], $pos-@offstack[-1]-2);
				say $ERR: "		Extracted string '$value'" if $PROGRESS;
				
				my $reset_pos = 1;
				if $_ eq '@@' {
					@stack[-1].properties<styling> = $value;
				}
				else {
					my $links=any(%open.values);
					if grep { .tagname eq $links } @stack {
						@stack.pop until @stack[-1].tagname eq $links;
						@stack[-1].properties<location> = $value;
					}
					else {
						# False alarm
						$reset_pos = 0;
						@stack[-1].add_text("||");
					}
				}
				
				if $reset_pos {
					@offstack[-1] = $pos;
					@stack[-1].children = [];
				}
			}
			when any(keys %close) {
				my $target_tagname = %close{$_};
				if @stack[-1].tagname ne $target_tagname 
				  and grep { .tagname eq $target_tagname } @stack {
					@stack.pop until @stack[-1].tagname eq $target_tagname;
				}
				
				unless defined @stack[-1].properties<location> {
					my $loc = ~$origtext.substr(@offstack[-1], $pos-@offstack[-1]-2);
					@stack[-1].properties = hash() unless @stack[-1].properties;
					@stack[-1].properties<location> = $loc;
					@stack[-1].children = [ $loc ];
				}
				say $ERR: "		@stack[-1].tagname() location: '@stack[-1].properties()<location>'" if $PROGRESS;
				@stack.pop();
				@offstack.pop();
			}
			when /^\&/ {
				@stack[-1].add_text(%char{$_});
			}
		}
		
		$text.substr(0, $length) = "";
	}
	
	if $text.chars {
		say $ERR: "	$text.chars() literal chars left over" if $PROGRESS;
		$text ~~ s:g{\s+}{ };
		$base.add_text($text);
	}
	return $base.children;
}

my sub do_list($skel, $type, $contents is rw, $request) {
	unless $skel.children[-1].tagname eq 'list' 
		and $skel.children[-1].properties<type> eq $type {
		$skel.add_node('list', :type($type));	
	}
	$skel.children[-1].add_node('item');
	$skel.children[-1].children[-1].children=do_text($contents, $request);
}

sub parse($text, $request) {
	my @paragraphs = $text.split(rx:perl5/(?:\r?\n){2,}/);
	
	my $skel=WWW::Kontent::Skeleton.new;
	
	for @paragraphs {
		$skel.add_node('null');
		
		my @lines = .split(
			rx:perl5/(?:^|\r?\n)([*`](?= )|[>*#;:`@!|\-]|={1,4})/
		);
		if @lines[0] ~~ rx:perl5/^([*`](?= )|[>#;:@!|\-]|={1,4})/ {	#`
			my $leader=~$0;
			@lines.unshift($leader);
			@lines[1].substr(0, $leader.chars) = "";
		}
		else {
			my $text=@lines.shift;
			say "paragraph ($text)" if $PROGRESS;
			$skel.add_node('paragraph');
			$skel.children[-1].children=do_text($text, $request);
		}
		
		for @lines -> $leader, $text is copy {
			$text ~~ s:g/\s+/ /;
			given $leader {
				when '>' {
					warn "blockquote ($text)" if $PROGRESS;
					$skel.add_node('quote', :type<paragraph>);
					$skel.children[-1].children=do_text($text, $request);
				}
				when '`' {
					warn "code ($text)" if $PROGRESS;
					$skel.add_node('code', :type<paragraph>);
					$skel.children[-1].children=[ $text ];
				}
				when '*' {
					warn "bullet ($text)" if $PROGRESS;
					do_list($skel, 'bulleted', $text, $request);
				}
				when '#' {
					warn "number ($text)" if $PROGRESS;
					do_list($skel, 'numbered', $text, $request);
				}
				when ';' {
					warn "term ($text)" if $PROGRESS;
					do_list($skel, 'definition', $text, $request);
					$skel.children[-1].children[-1].properties = { type => 'term' };
				}
				when ':' {
					warn "definition ($text)" if $PROGRESS;
					do_list($skel, 'definition', $text, $request);
				}
				when '@' {
					warn "block styling ($text)" if $PROGRESS;
					$skel.add_node('!', :message("Block styling unimplemented"));
				}
				when '!' | '|' {
					warn "table cell ($text)" if $PROGRESS;
					unless $skel.children[-1].tagname eq 'table' {
						$skel.add_node('table');
						$skel.children[-1].add_node('row');
					}
					$skel.children[-1].children[-1].add_node(
						'cell', :type($_ eq '!' ?? 'header' :: 'data')
					);
					$skel.children[-1].children[-1].children[-1].children=do_text($text, $request);
				}
				when '-' {
					warn "table row ($text)" if $PROGRESS;
					unless $skel.children[-1].tagname eq 'table' {
						$skel.add_node('table');
					}
					$skel.children[-1].add_node('row');
				}
				when /^=+ ?$/ {
					warn "header ($text)" if $PROGRESS;
					$skel.add_node('header', :level($_.chars));
					$skel.children[-1].children=do_text($text, $request);
				}
				default {
					$skel.add_node('!', :message("Kolophon panic: Unrecognized leader $leader"));
				}
			}
		}
	}
	return $skel;
}
