while(<>) {
	my ($id, $round) = split(/,/, $_);
	chomp $round;
	print "[$id,$round],\n";	
}