class WWW::Kontent::Store::NarrowDBI::SavedPage is WWW::Kontent::SavedPage {
	has $.parent;
	has $.name;
	
	has $:id;
	has $:currev;
	has %:sth;
	
	submethod BUILD($.parent, $.name, %:sth) {
		# Retrieve the page ID and current revision number from the database
		%:sth<getpageinfo>.execute($.parent ?? $.parent._id :: 0, $.name)
			or WWW::Kontent::error("Can't execute statement handle 'getpageinfo'", :code(500));
		my $row=%:sth<getpageinfo>.fetchrow_arrayref;		# XXX pugsbug? fetches multiple times when written as .fetchrow_arrayref[0,1]
		($:id, $:currev) = $row[0,1];
		$:id || WWW::Kontent::error("The page '$.name' was not found", :code(404));
	}
	
	method :getrev($rid) {
		#Retrieve a revision
		WWW::Kontent::Store::NarrowDBI::SavedRev.new(
			:page($_), :revno($rid), :sth(%:sth)
		);
	}
	
	method revisions() returns Array {
		$:currev || WWW::Kontent::error("The page '$.name' is a stub with no revisions", :code(404));
		gather {
			for 1..$:currev -> $rid {
				take $?SELF.:getrev($rid);
			}
		}
	}
	
	method children() returns Array {
		$:sth<getchildren>.execute($:id);
		gather {
			my $r;
			while $r = $:sth<getchildren>.fetchrow_arrayref {
				take $r[0];
			}
		}
	}
	
	method cur() returns WWW::Kontent::Store::NarrowDBI::SavedRev {
		$:currev || WWW::Kontent::error("The page '$.name' is a stub with no revisions", :code(404));
		return $_.:getrev($:currev);
	}
	
	method default_resolve(String $name) {
		return WWW::Kontent::Store::NarrowDBI::SavedPage.new(
			:parent($_), :name($name), :sth(%:sth)
		);
	}
	
	method default_create(String $name) {
		$:sth<addpage>.execute($:id, $name);
		return WWW::Kontent::Store::NarrowDBI::DraftPage.new(
			:parent($_), :name($name), :sth(%:sth)
		);
	}
	
	# XXX should be handled by trusting Rev and Draft
	method _id() { return $:id }
}

class WWW::Kontent::Store::NarrowDBI::DraftPage is WWW::Kontent::DraftPage {
	has $.parent;
	has $.name is rw;
	has $.draft_revision;

	has $:id;
	has %:sth;
	
	submethod BUILD($.parent, $.name, %:sth) { 
	    $.draft_revision = WWW::Kontent::Store::NarrowDBI::DraftRev.new(
	       :page($_), :revno(1), :sth(%:sth)
	    );
	}
	
	method _commit() {
		%:sth<addpage>.execute($.parent._id, $.name) // die $DBI::errstr;
        %:sth<getpageinfo>.execute($.parent._id, $.name) // die $DBI::errstr;
        my $r = %:sth<getpageinfo>.fetchrow_arrayref;
        $:id = $r[0];
	}
	
	method :writepage() {
		# Create the page itself and retrieve its details.

	}
	
	method _id() { $:id }
}
