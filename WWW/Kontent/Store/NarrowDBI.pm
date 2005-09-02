module WWW::Kontent::Store::NarrowDBI;

=head1 TITLE

WWW::Kontent::Store::NarrowDBI - Flexible Perl 5 DBI store for WWW::Kontent

=head1 SYNOPSIS

	# in kontent-config.yaml
	store:
		module: NarrowDBI
		rootname: mysite
		connection: dbi:driver:dbname
		username: jrandom
		password: secret

=head1 DESCRIPTION

NarrowDBI is a flexible Kontent store which operates via the Perl 5 DBI module. 
It's designed to be simple and easy to configure, and requires no customization 
to suit your classes.

This store supports multiple "roots"--heirarchies of pages--in the same 
database.  This allows a single database to store multiple sites, which may be 
useful in certain situations.  Each root is a page with a parent ID of 0; the 
name of the root is passed as the first argument to get_root.

NarrowDBI guarantees that pages will always be readable, even if Kontent crashes 
in the middle of writing a revision; however, pages may not be writable in such 
a circumstance unless your database supports transactions.

=head2 Configuration

NarrowDBI is configured through the Kontent configuration file, 
F<kontent-config.yaml>; see that file for details.  NarrowDBI recognizes the 
following settings:

=over 4

=item C<rootname>

Required; specifies which root NarrowDBI should use for this Kontent instance.

=item C<connection>

Required; specifies the DBI data source name (connection string) needed to 
connect to the database.

=item C<username>

Optional; gives the database username, if any.

=item C<password>

Optional; gives the database password, if any.

=back 4

In addition, the C<module> field must be set to C<NarrowDBI> for this module to 
be used, and the C<modules> list must include C<Store::NarrowDBI>.

=head2 Representation

NarrowDBI represents each attribute as a new row in an attributes table.  As 
such, it is perhaps one of the least efficient designs for a DBI store, as each 
page retrieval requires that several rows be selected from the attributes table.

A second table maps revision IDs to page IDs and revision numbers; a third maps 
page IDs to parent/name pairs, and keeps track of the page's current revision.  
A forth table represents the pool.

=head1 SEE ALSO

L<WWW::Kontent>, L<WWW::Kontent::Store>

=cut

use perl5:DBI;

class WWW::Kontent::Store::NarrowDBI::SavedPage is WWW::Kontent::SavedPage {...}
class WWW::Kontent::Store::NarrowDBI::DraftPage is WWW::Kontent::DraftPage {...}
class WWW::Kontent::Store::NarrowDBI::SavedRev is WWW::Kontent::SavedRevision {...}
class WWW::Kontent::Store::NarrowDBI::DraftRev is WWW::Kontent::DraftRevision {...}
class WWW::Kontent::Store::NarrowDBI::Pool {...}

use WWW::Kontent::Store::NarrowDBI::Pages;
use WWW::Kontent::Store::NarrowDBI::Revs;
use WWW::Kontent::Store::NarrowDBI::Pool;

my sub prep_sql($dbh, $sql) {
	return $dbh.prepare($sql) or WWW::Kontent::error "Can't prepare statement handle";
}

sub handles($p) {
	my $dbh=DBI.connect($p<connection>, $p<username>, $p<password>)
		|| WWW::Kontent::error("Can't open database", :code(502));
	$dbh<PrintError>=0;
#	$dbh.trace(1);
	my $transaction_in_progress=0;

	my %sth=(
		dbh			=> $dbh,
		
		getpageinfo => prep_sql($dbh, "SELECT pageid, currevno FROM kontent_narrow_pages WHERE parent = ? AND name = ?"),
		getchildren => prep_sql($dbh, "SELECT name             FROM kontent_narrow_pages WHERE parent = ?"),
		getrevid    => prep_sql($dbh, "SELECT revid            FROM kontent_narrow_revs  WHERE pageid = ? AND revno = ?"),
		getrevattrs => prep_sql($dbh, "SELECT name, value      FROM kontent_narrow_attrs WHERE revid = ?"),
		addrevid    => prep_sql($dbh, "INSERT INTO kontent_narrow_revs  (pageid, revno)      VALUES (?, ?)"),
		addrevattr  => prep_sql($dbh, "INSERT INTO kontent_narrow_attrs (revid, name, value) VALUES (?, ?, ?)"),
		updaterevno => prep_sql($dbh, "UPDATE kontent_narrow_pages SET currevno = ? WHERE pageid = ?"),
		addpage		=> prep_sql($dbh, "INSERT INTO kontent_narrow_pages (parent, name)		 VALUES (?, ?)"),
		
		getpooldata => prep_sql($dbh, "SELECT value FROM kontent_narrow_pool WHERE `module` = ? AND `key` = ?"),
		addpooldata => prep_sql($dbh, "INSERT INTO kontent_narrow_pool (`module`, `key`, `value`, `time`) VALUES (?,?,?,?)"),
		setpooldata => prep_sql($dbh, "UPDATE kontent_narrow_pool SET `value` = ?, `time` = ? WHERE `module` = ? AND `key` = ?"),
		delpooldata => prep_sql($dbh, "DELETE FROM kontent_narrow_pool WHERE `module` = ? AND `key` = ?"),
		listpooldata=> prep_sql($dbh, "SELECT key FROM kontent_narrow_pool WHERE `module` = ?"),
		getpooltime => prep_sql($dbh, "SELECT time FROM kontent_narrow_pool WHERE `module` = ? AND `key` = ?"),
		setpooltime => prep_sql($dbh, "UPDATE kontent_narrow_pool SET `time` = ? WHERE `module` = ? AND `key` = ?"),
		
		begin       => { $transaction_in_progress=1 if $dbh.begin_work },
		commit      => { $dbh.commit   if $transaction_in_progress },
		rollback	=> { $dbh.rollback if $transaction_in_progress }
	);
	
	return %sth;
}

sub get_root($p) returns WWW::Kontent::Store::NarrowDBI::SavedPage {
	my %sth=handles($p);
	return WWW::Kontent::Store::NarrowDBI::SavedPage.new(:parent(undef), :name($p<rootname>), :sth(\%sth));
}

sub make_root($p) {
	my %sth=handles($p);
	my $dbh=%sth<dbh>;
	
	unless $dbh.do("SELECT COUNT(*) FROM kontent_narrow_pages") {
		say "Creating pages table...";
		$dbh.do(qq{
			CREATE TABLE `kontent_narrow_pages` (
				`pageid` int(11) NOT NULL auto_increment,
				`parent` int(11) NOT NULL default '0',
				`name` char(32) NOT NULL default '',
				`currevno` int(11) NOT NULL default '0',
				PRIMARY KEY (`pageid`),
				UNIQUE KEY `parent` (`parent`,`name`)
			)
		}) or die "Can't create pages table: $dbh.errstr()";
	}
	else {
		say "Pages table already exists--skipping.";
	}
	
	unless $dbh.do("SELECT COUNT(*) FROM kontent_narrow_revs") {
		say "Creating revisions table...";
		$dbh.do(qq{
			CREATE TABLE `kontent_narrow_revs` (
				`revid` int(11) NOT NULL auto_increment,
				`pageid` int(11) NOT NULL default '0',
				`revno` int(11) NOT NULL default '0',
				PRIMARY KEY (`revid`),
				UNIQUE KEY `new_index` (`pageid`,`revno`)
			)
		}) or die "Can't create pages table: $dbh.errstr()";
	}
	else {
		say "Revisions table already exists--skipping.";
	}
	
	unless $dbh.do("SELECT COUNT(*) FROM kontent_narrow_attrs") {
		say "Creating attrs table...";
		$dbh.do(qq{
			CREATE TABLE `kontent_narrow_attrs` (
				`revid` int(11) NOT NULL default '0',
				`name` varchar(16) NOT NULL default '',
				`value` mediumtext NOT NULL,
				PRIMARY KEY  (`revid`,`name`)
			);
		}) or die "Can't create pages table: $dbh.errstr()";
	}
	else {
		say "Attrs table already exists--skipping.";
	}
	
	unless $dbh.do("SELECT COUNT(*) FROM kontent_narrow_pool") {
		say "Creating pool table...";
		$dbh.do(qq{
			CREATE TABLE `kontent_narrow_pool` (
				`module` TINYTEXT NOT NULL,
				`key`    TINYTEXT NOT NULL,
				`value`  MEDIUMTEXT NOT NULL,
				`time`   DOUBLE PRECISION NOT NULL,
				PRIMARY KEY  (`module`(32),`key`(32))
			);
		}) or die "Can't create pool table: $dbh.errstr()";
	}
	else {
		say "Pool table already exists--skipping.";
	}
	
	#Create and retrieve root page.
	say "Preparing root page...";
	my $rootdraft=WWW::Kontent::Store::NarrowDBI::DraftPage.new(
		:parent(0), :name($p<rootname>), :sth(%sth)
	);
	my $rev=$rootdraft.draft_revision;
	$rev.attributes<rev:author>='/users/contributors';
	$rev.attributes<rev:log>='Initial revision inserted by make_root';
	
	$rev.attributes<kontent:class>='kiki';
	$rev.attributes<kontent:version>=1;
	$rev.attributes<kontent:title>='Kontent root page';
	
	$rev.attributes<kiki:type>='text/x-kolophon';
	$rev.attributes<kiki:content>=q{This is the Kontent store's root page.};
	
	say "Committing root page...";
	try {
		$rev.commit();
	};
	if $! {
		say "Commit failed: $!";
		say "Please ensure that there's nothing wrong with the tables before trying to use Kontent.";
	}
	
	say "Done.";
	return get_root($p);
}