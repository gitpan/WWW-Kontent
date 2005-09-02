=head1 NAME

WWW::Kontent::Store::NarrowDBI::Revs - no user servicable parts inside

=head1 DESCRIPTION

This module contains the SavedRevision and DraftRevision implementations for 
NarrowDBI; see L<WWW::Kontent::Store::NarrowDBI> for details on NarrowDBI's 
behavior.

=cut


class WWW::Kontent::Store::NarrowDBI::SavedRev is WWW::Kontent::SavedRevision {
	has $.page;
	has $.revno;
	has %.attributes;
	
	has $:id;
	has %:sth;
	
	submethod BUILD($.page, $.revno, %:sth) {
		# Turn the page/revno pair into a revid
		%:sth<getrevid>.execute($.page._id, $.revno)
			|| WWW::Kontent::error("Can't execute statement handle 'getrevinfo'", :code(500));
		my $row=%:sth<getrevid>.fetchrow_arrayref;		# XXX pugsbug?
		($:id)=int $row[0];
		$:id || WWW::Kontent::error("Revision $:revno of page $.page._id() not found", :code(404));
		
		# Retrieve all attributes for this revid
		%:sth<getrevattrs>.execute($:id)
			|| WWW::Kontent::error("Can't execute statement handle 'getrevattrs'", :code(500));
		my $r;
		while $r = $:sth<getrevattrs>.fetchrow_arrayref {
			%.attributes{$r[0]}=$r[1];
		}
	}
	
	method revise($revno) {
		# Make the draft object
		my $draft=WWW::Kontent::Store::NarrowDBI::DraftRev.new(:revno($revno), :page($.page), :sth(\%:sth));
		
		# Copy all but the rev: keys.
		for %.attributes.kv -> $k, $v {
			next if $k ~~ /^rev:/;
			$draft.attributes{$k} = $v;
		}
		
		return $draft;
	}
	
	method pool($module) {
		return WWW::Kontent::Store::NarrowDBI::Pool.new(:module($module), :sth(\%:sth));
	}
}

class WWW::Kontent::Store::NarrowDBI::DraftRev is WWW::Kontent::DraftRevision {
	has $.page;
	has $.revno is rw;
	has %.attributes is rw;
	
	has %:sth;
	has $:id;
	
	submethod BUILD(Int $.revno, %:sth, $.page) {
		.:ck_conflict() if $.revno;
	}
	
	method :ck_conflict() {
		$:sth<getrevid>.execute($.page._id, $.revno) or WWW::Kontent::error("Can't execute statement handle 'getrevid' during conflict check");
		my $r=$:sth<getrevid>.fetchrow_arrayref;
		
		if $r[0] {
			WWW::Kontent::error("Revision $.revno of $.page.name() already exists", :code(409));
		}
	}
	
	method commit() {
		%.attributes<rev:date>=time;
		
		if $.page.isa(WWW::Kontent::SavedPage) {
			# Make sure the page doesn't exist yet
			#  (the table structure should ensure that you can't commit a duplicate 
			#   revision, but we might as well throw the exception before they go 
			#   to loads of work)
			.:ck_conflict();
		}
		
		# A safe commit must occur in three steps; if it isn't performed in the 
		# proper order, it can leave a non-transactional database in a badly 
		# wedged, inconsistent state in which the page can't even be read.
#		try {
			%:sth<begin>();
			
			#Perform the various writes...
			$.page._commit() if $.page.isa(WWW::Kontent::DraftPage);
			.:write_revision();
			.:write_attributes();
			.:update_page();
			
			#...and commit.
			%:sth<commit>();
#		};
		if $! {
			.:uncommit();
			%:sth<rollback>();
			die $!;
		}
	}
	
	method :write_revision() {
		#The first step is to add the revision to the revs table.  This does 
		#several things:
		# - In a properly configured, non-transactional table, it will keep the 
		#   same revision from being committed twice--even concurrently.
		# - It will assign a revision ID, which we need for the second step.
		$:sth<addrevid>.execute($.page._id, $.revno) or WWW::Kontent::error("Failure while adding new page: %:sth<dbh>.errstr()");
		$:sth<getrevid>.execute($.page._id, $.revno) or WWW::Kontent::error("Unable to retrieve new revision ID: %:sth<dbh>.errstr()");
		my $r=$:sth<getrevid>.fetchrow_arrayref;
		$:id = $r[0];
	}
	
	method :write_attributes() {
		#The second step is to commit all of the attributes.
		for %.attributes.kv -> $k, $v {
			%:sth<addrevattr>.execute($.id, $k, $v) or WWW::Kontent::error("Can't add attribute '$k' to attrs table: %:sth<dbh>.errstr()");
		}
	}
	
	method :update_page() {
		#And the final step is to update the page's record to reflect the new revision.
		%:sth<updaterevno>.execute($.revno, $.page._id);
	}
	
	method :uncommit() {
		# XXX INVENT THIS
		WWW::Kontent::error("PANIC: uncommit unimplemented ($!)");
	}
	
	method pool($module) {
		return WWW::Kontent::Store::NarrowDBI::Pool.new(:module($module), :sth(\%:sth));
	}
}