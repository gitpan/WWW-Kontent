=head1 NAME

WWW::Kontent::Skeleton - Kontent skeleton (syntax-independent document formatting tree) class

=head1 SYNOPSIS

	my $skel=WWW::Kontent::Skeleton.new();
	$skel.add_node(:tagname<header>, :level(1)).add_text("Merlin's beard!");
	$skel.add_node(:tagname<paragraph>);
	$skel.children[0].add_tag("Hermione cried.");

=head1 DESCRIPTION

The skeleton--a simple, passive N-ary tree--is used to pass information about 
the page's content and formatting to a renderer to be rendered in the 
appropriate format.  The C<tagname> attribute contains a string specifying the 
formatting code to be applied, and the C<children> attribute contains an array 
of child nodes--either other WWW::Kontent::Skeleton objects or plain strings 
containing text.  Any other properties of the node are kept in the C<properties>
attribute.

Plain strings should be preserved in the actual document as closely as possible;
escaping and tagging should be performed so that all content--including 
whitespace--is displayed.

=head2 Valid tagnames

=over 4

=item C<skeleton>

This should always be the top-level node of a skeleton, and may also appear 
within the skeleton.  It does not imply any semantic.

=item C<null>

The null node implies no semantics, but its children should be processed.

=item C<paragraph>

Represents a paragraph of information.

=item C<header>

Has one property, C<level>, ranging between 0 and 4, with lower numbers being 
more important.  Level 0 is reserved for the page's title.  (Higher levels are 
possible but may not be supported by all renderers.)

=item C<list>

Represents a list of some kind.  Has one property, C<type>, which may contain 
any of "bulleted", "numbered", or "definition".  Children must be C<item>s.

B<Note>: Future versions of Kontent are expected to implement definition lists 
in a different way than they are currently.

=item C<item>

Represents an item in a C<list>.  In a definition list, the C<type> property 
can be set to C<term> to indicate the item in question is a term, rather than a 
definition.

=item C<table>

Represents a table.  Its children are C<row> nodes, whose children are C<cell> 
nodes.

=item C<row>

Represents a row in a table.  Its children must be C<cell> nodes.

=item C<cell>

Represents a cell in a table row.  If the C<type> property is set to C<header>, 
the cell should be treated as a header cell.

=item C<emphasis>

Indicates that its child nodes should be emphasized in some manner, usually by 
italicizing.

=item C<strong>

Indicates that its child nodes should be given strong emphasis, usually by 
bolding.

=item C<title>

Indicates that its child nodes should be formatted as if they are the title of 
a book or other work.

=item C<struck>

Indicates that its child nodes should be crossed out or otherwise visibly 
"deleted".

=item C<superscript>

Indicates that its child nodes should be formatted as a superscript.

=item C<subscript>

Indicates that its child nodes should be formatted as a subscript.

=item C<code>

Indicates that its child nodes should be formatted as a piece of code.  If the 
C<type> field is set to C<paragraph>, the code should be treated as a separate 
paragraph and possibly indented.

=item C<link>

Represents a hyperlink.  Has one property, C<location>, containing a Kontent 
path or fully-qualified URL.  (Kontent paths will never have a colon in them, 
while URLs always will.)  If a C<link> node has no children, most renderers 
will fill in the page's title.

=item C<transclude>

Represents a transclusion, indicating that the textual content of the page 
indicated by C<location> should be inserted into the current page.  This is 
usually achieved through use of a subrequest.

=item C<form>

Creates a fill-in form, which when submitted will return to the same page, mode 
and format as is currently in use.

=item C<textfield>

Creates a fill-in field for a string of text.  The C<name> property gives the 
name the field's content should be returned as; C<value> indicates the current 
value of the field; and C<label> gives an optional text label to be displayed 
for the field.  The C<type> property, when set to the value C<multiline>, tells 
the renderer that a large, multiple-line block of text should be expected.

=item C<boolfield>

Creates a fill-in field for a boolean value (often a checkbox).  The C<name>,
C<value> and C<label> properites work as above.

=item C<choicefield>

Creates a fill-in field for one of several choices.  The C<name>, C<value> and 
C<label> properties work basically as above.  The default rendering is usually 
a drop-down box; however, if C<type> is set to C<action>, the C<name> will also 
be forced to equal C<action>, and the form will be submitted once an action is 
chosen.  Action fields are often displayed as a set of buttons.

=item C<choice>

Each C<choicefield> should have several C<choice>s.  The C<value> property gives 
the value associated with this choice; any nodes under this one will be used to 
determine the label text for the choice.

=item C<metafield>

A metafield is an invisible field carrying information back to the server.  The 
C<name> and C<value> properties work basically as above.

=item C<!>

A node whose name consists solely of an exclamation point indicates a warning 
message, usually meaning that the parser found an error in the markup used to 
generate the skeleton.  Each warning has a message, kept (appropriately enough) 
in its C<message> property.

Warnings should be displayed in a noticable but non-disruptive fashion; in the 
HTML renderer, for example, they take the form of a red exclamation point with 
a tooltip containing the message.  

=back 4

=cut

class WWW::Kontent::Skeleton;

has $.tagname is rw;
has @.children is rw;
has %.properties is rw;

submethod BUILD(+$.tagname = 'skeleton', +@.children, *%_) {
	%.properties=%_;
}

=head2 Methods

=over 4

=item C<add_node>

Creates a new node and appends it to the current node's list of children.  The 
tag name is passed as the first parameter; any named parameters are treated as 
node properties.

=cut

method add_node(Str $tagname, *%properties) {
	my $n = WWW::Kontent::Skeleton.new(:tagname($tagname), :_(*%properties));
	#No idea why this is necessary, but I get VUndef errors without it.
	if @.children {
		@.children.push($n);
	}
	else {
		@.children=[ $n ];
	}
	return $n;
} 

=item C<add_text>

Appends one or more text nodes to the current node's list of children.

=cut

method add_text(Str *@content) {
	if @.children {
		@.children.push(*@content);
	}
	else {
		@.children=[ *@content ];
	}
	return *@content;
}

my sub quote($str is copy) {
	$str ~~ s:g{\\}{\\\\};
	$str ~~ s:g{"}{\\"};
	$str ~~ s:g{\n}{\\n};
	$str ~~ s:g{\015}{\\r};
	return qq("$str");
}

=item C<dump>()

Returns an array of strings representing the skeleton from the current node 
down; each string should be treated as a separate line.

=cut

method dump() {
	return gather { 
		take "$.tagname (" ~ ( map -> $k, $v { qq($k=&quote($v)) } %.properties.kv ) ~ ")";
		for @.children {
			if $_ ~~ Str {
				take qq(    &quote($_));
			}
			else {
				take map { "    $_" } $_.dump;
			}
		}
	};
}

=item C<text>()

Assembles a string consisting of all text nodes below the current node, 
concatenated together.

=cut

method text() {
	return [~] gather {
		for .children {
			if $_ ~~ Str {
				take $_;
			}
			else {
				take $_.text();
			}
		}
	}
}

=back 4

=head1 SEE ALSO

L<WWW::Kontent>

=cut