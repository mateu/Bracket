my $i = 1;
while(<>) {
	my ($id, $seed, $team, $region, @remainder) = split(/,/, $_);
	print "[$id,$seed,'$team',$region],\n";
	$i++;
	
}