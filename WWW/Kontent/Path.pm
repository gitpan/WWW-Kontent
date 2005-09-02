=head1 NAME

WWW::Kontent::Path - Classes for navigating Kontent stores

=head1 SYNOPSIS

	my $path = WWW::Kontent::Path.new;
	$path.parse('foo/bar[42]/baz.pdf{view}');
	$path.resolve(:in($root), :request($r));
	say $path.components[0].name;			# foo
	say $path.components[1].revno;			# 42
	say ref $path.components[3].revision;	# WWW::Kontent::Store::NarrowDBI::SavedRev
	say $path.format;						# pdf

=head1 DESCRIPTION

WWW::Kontent::Path is a class representing a path to a Kontent page.  Besides 
the Path object itself, it also defines WWW::Kontent::Component, a single part 
of a path.

=head2 Paths in Kontent

A path is the portion of the URL which Kontent examines to determine which page 
it should operate on, which mode that page should be processed in, and which 
format it should be rendered in.  Expressed as a Perl 6 grammar, it might look 
something like this:

	grammar Grammar::Kontent::Path {
		rule name   {      \w+     }
		rule revno  { \[   \d+  \] }
		rule format { \. <name>    }
		rule mode   { \{ <name> \} }
		
		rule component { <name> <revno>? }
		rule path {
		 /? [ <revno> | <component> ]
		    [ / <component> ]*
		     <format>?  <mode>?
		}
	}

In somewhat simpler terms, all of these are valid:

	<name>/<name>/<name>
	<name>[<revno>]/<name>{mode}
	[<revno>]/<name>/<name>[<revno>].<format>

As well as most similar combinations.

=head2 WWW::Kontent::Component

Component objects contain two accessors, C<name> and C<revno>, representing the 
name and revision number of that particular part of the path.  C<name> is 
undefined in the first component, representing the root node; if C<revno> is 
undefined it means that the current revision should be used.

After C<resolve> has been called on the WWW::Kontent::Path object it belongs to,
two additional fields become available.  C<page> and C<revision> contain the 
page and revision, respectively, associated with the component.

A component can be stringified, yielding a string something like C<bar[42]>, 
but intelligent enough to omit missing parts of the component.

Component objects should never be allocated by user code; only 
WWW::Kontent::Path should create them.

=cut

class WWW::Kontent::Component is rw {
    has Str $.name;
    has Int $.revno;
    
    has WWW::Kontent::Page $.page;
    has WWW::Kontent::Revision $.revision;
    
    method resolve_in(WWW::Kontent::SavedRevision $in, WWW::Kontent::Request $request) returns WWW::Kontent::Revision {
    	$request.trigger_magic('pre', 'resolve', $_, $in);
        if $in {
            $.page = $in.resolve($.name, $request);
        }
        
        if $.revno {
            $.revision = $.page.revisions[$.revno];
        }
        else {
            $.revision = $.page.cur;
        }
        
        $.revision = $request.trigger_magic('post', 'resolve', $_, $in, $.revision);
  		$.page     = $.revision.page;
  		
        return $.revision;
    }
    
    method prefix:<~> () returns Str {
    	my $str = $.name;
    	$str ~= "[$.revno]" if $.revno;
    	return $str;
    }
}

=head2 WWW::Kontent::Path

Represents a full path (set of components).  Once a Path object has been 
allocated, a string path must be given to the C<parse> method; later, a call 
to C<resolve> (with the root node and request passed in) will find the pages 
and revisions associated with those path components.

The C<components> accessor, filled in by C<parse>, contains an array of 
Component objects.  The C<mode> accessor contains the mode, while the C<format> 
accessor contains the format.  The C<page> and C<revision> accessors retrieve 
the page and revision, respectively, of the last component, and are only useful 
after C<resolve> has been called.

=cut

class WWW::Kontent::Path {
    has WWW::Kontent::Component @.components is rw;
    
    method page()     { @.components[-1].page     }
    method revision() { @.components[-1].revision }
    has Str  $.mode   is rw;
    has Str  $.format is rw;
    
    method parse(Str $path is copy) {
    	# Extract the mode and format first.
        if $path ~~ s/ \{ (\w+) \} $// {
            $.mode   = ~$0;
        }
        else {
        	$.mode = 'view';
        }
        
        if $path ~~ s/ \. (\w+) $// {
            $.format = ~$0;
        }
        else {
        	$.format = 'html';
        }
        
        @.components = gather {
        	# Strip leading or trailing slash, if any.
        	$path ~~ s:g{^/|/$}{};
        	
        	# A leading [NUM] with no name indicates the root revision to use.
            if $path ~~ s{^ \[ (\d+) \] /?}{} {
                take WWW::Kontent::Component.new(:revno(+$0));
            }
            else {
                take WWW::Kontent::Component.new();
            }
        	
        	#Parse the rest of the path
        	if $path {
	            for split '/', $path -> $comp {
	                $comp ~~ /^ (\w+) [ \[ (\d+) \] ]? $/
	                	or WWW::Kontent::error("Invalid component '$comp'", :code(400));
	                take WWW::Kontent::Component.new(:name(~$0), :revno(+$1));
	            }
        	}
        };
		
        return $_;
    }
    
    method resolve(WWW::Kontent::SavedPage $in, WWW::Kontent::Request $request) returns WWW::Kontent::SavedRevision {
    	WWW::Kontent::error("Can't resolve a path which hasn't been parsed yet!")
    		unless @.components;
        @.components[0].page = $in;
        
        my $cur;
        $cur = $_.resolve_in($cur, $request) for @.components;
        return $cur;
    }
    
    method stringify () returns Str {
    	return join '/', grep { $_.chars } ~<< @.components;
    }
}

=head1 SEE ALSO

L<WWW::Kontent>

=cut