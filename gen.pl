#!/usr/bin/perl

$BGP4_URL = "ftp://archive.routeviews.org/bgpdata";
$BGP6_URL = "ftp://archive.routeviews.org/route-views6/bgpdata";

print "Getting url of last dump file\n";
@BGP4_DIR = `curl -s $BGP4_URL/ --list-only`;
@BGP6_DIR = `curl -s $BGP6_URL/ --list-only`;
chomp(@BGP4_DIR);
chomp(@BGP6_DIR);

# Temp
$BGP4_DIR[-1] = "2021.01";
$BGP6_DIR[-1] = "2021.01";

@BGP4_FILE = `curl -s $BGP4_URL/$BGP4_DIR[-1]/RIBS/ --list-only`;
@BGP6_FILE = `curl -s $BGP6_URL/$BGP6_DIR[-1]/RIBS/ --list-only`;
chomp(@BGP4_FILE);
chomp(@BGP6_FILE);

print "Downloading BGPv4 RIB MRT file\n";
system qq(wget -O ribv4.bz2 $BGP4_URL/$BGP4_DIR[-1]/RIBS/$BGP4_FILE[-1]);

print "Downloading BGPv6 RIB MRT file\n";
system qq(wget -O ribv6.bz2 $BGP6_URL/$BGP6_DIR[-1]/RIBS/$BGP6_FILE[-1]);

print "Generating BGPv4 routes file\n";
system qq(bzcat ribv4.bz2 | bgpdump -vm - | cut -d '|' -f '6,7' |grep -v "0.0.0.0/0" > v4.txt);

print "Generating BGPv6 routes file\n";
system qq(bzcat ribv6.bz2 | bgpdump -vm - | cut -d '|' -f '6,7' |grep -v "::/0" > v6.txt);

print "Filtering unique routes and creating text file for asmap\n";

filter_routes("v4.txt");
filter_routes("v6.txt");

print "Creating Bitcoin asmap.map\n";
system qq(cat filtered.txt | bitcoin-asmap encode asmap.map);

print "Done\n";

unlink "ribv4.bz2";
unlink "ribv6.bz2";
unlink "v4.txt";
unlink "v6.txt";
unlink "filtered.txt";

sub filter_routes {
	my $file = shift;

	my %hash;
	open(OUT, ">>", "filtered.txt");
	open(IN, "<", "$file") or die $!;
	while(<IN>) { 
		my $line = $_;
		chomp $line;
		my($prefix,$path) = split(/\|/, $line);
		next if $hash{"$prefix"};
		$path =~ s/\ {.*}//;
		$path =~ /([0-9]+$)/;
		my $origin = $1;
		print OUT $prefix." AS".$origin."\n" if($origin =~ /^\d{1,6}$/);
		$hash{"$prefix"} = 1;
			
	}
	close(IN);
	close(OUT);
}
