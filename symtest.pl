#!/usr/bin/perl

 use SNMP::Info;
 use Net::Appliance::Session;
 use Getopt::Long;
 use CGI qw(:standard);

	my ($session_obj,$traceips) =();
	print "Content-type: text/plain", "\n\n" if $traceips;
	$traceips = param('traceips');
	GetOptions (
		'traceips=s'     => \$traceips,
	);

	#Set Username and password here
	my $snmp = 'snmp_read';

	my $ios_username        = 'ios_username';
	my $ios_password        = 'ios_password';
	my $ios_enable_password = 'enable_password';

	if ($traceips){
		my @splitips = split(/,/,$traceips);
		foreach my $splitip (@splitips){
			my (@array1,$device1,$ip1,@array2,$device2,$ip2,@wayone,@waytwo,@waytwo_rev)= ();
			@ipsplit = split(/:/,$splitip);	
			$ip1 = $ipsplit[0];
			$ip2 = $ipsplit[1];

			if ($ip1 =~ /(.+);(.+)/){
				$device1 = $1;
				$ip1 = $2;
			}
			else{
				$device1 = "$ip1";
			}
			if ($ip2 =~ /(.+);(.+)/){
				$device2 = $1;
				$ip2 = $2;
			}
			else{
				$device2 = "$ip2";
			}
			if ($comment){
				print "$comment\n";
			}
			else{
				print "\nChecking from $ip1 -> $ip2\n";
			}
		        $session_obj = &netConnect($device1,$ios_username,$ios_password);
			@array1 = &traceSrc("$ip1","$ip2");
			$device1 = &getName($ip1);
			push @wayone,  $device1;
			foreach my $line (@array1){
				push @wayone,  &getName($line);
			}

		        $session_obj = &netConnect($device2,$ios_username,$ios_password);
			@array2 = &traceSrc("$ip2","$ip1");
			$device2 = &getName($ip2);
			push @waytwo,  $device2;
			foreach my $line (@array2){
				push @waytwo,  &getName($line);
			}
			@waytwo_rev = reverse(@waytwo);
			$device1 =~ s/\n|\r//g;
			$device2 =~ s/\n|\r//g;
			my $issym = &extraConf(\@wayone,\@waytwo_rev);
			if ($issym eq "compliant"){
				print "\nIs symmetrical \n";
				print @wayone;
				print "\nReverse Route\n";
				print @waytwo;
			}
			else {
				print "$device1 $ip1 => $device2 $ip2\n";
				print "\nIs NOT symmetrical \n";
				print @wayone;
				print "\nReverse Route\n";
				print @waytwo;
			}
			print "\n\n";
		}
	}
	else {
		print "No IPs inputed";
	}


sub extraConf {
        my($stripconf , $scrub) = @_;
        my @stripconf = @{$stripconf};
        my @scrub = @{$scrub};
        my @returnarray =();

        my ($index,$strip,$test,@stripconfout)="";

        foreach $strip (@stripconf){
                $index=0;
                foreach $test (@scrub){
                        $test =~ s/\r|\n//g;;
                        if ($strip =~ /^$test/i){
                                $index=1;
                        }
                }
                if ($index ==0){
                        push @stripconfout,$strip;
                }
        }
        if (@stripconfout) {
                return "noncompliant";
        }
        else {
                return "compliant";
        }
}

sub getName{
        my $host = shift;
        my $snmp = new SNMP::Info (
                AutoSpecify => 1,
                Debug       => 0,
                DestHost    => "$host",
                Community   => '$snmp',
                Version     => 2
        );

        my $class = $snmp->class();
        my $name = $snmp->name();
	if ($name ){
	        return "$name\n";
	}
	else {
		return "$host\n";
	}
}

sub netConnect {
        my $device1 = shift;
        my $ios_username = shift;
        my $ios_password = shift;
        # give verbose output whilst we run this script
        eval {
                $session_obj = Net::Appliance::Session->new(
                        Host      => $device1,
                        Transport => 'SSH',
                );
               #  try to login to the ios device, ignoring host check
               #$session_obj->input_log(*STDOUT);
		sleep(2);
                $session_obj->connect(
                        Name => $ios_username,
                        Password => $ios_password,
                        SHKC => 0,
                        Timeout  => 360,
			Opts  => ['-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null'],
                );
        };
        #if ($session) {}
        if ($@)  {
                eval {
			sleep(3);
                        $session_obj = Net::Appliance::Session->new(
                                Host      => $device1,
                                Transport => 'Telnet',
                        );
               #         $session_obj->input_log(*STDOUT);
                        $session_obj =  $session_obj->connect(
                                Name => $ios_username,
                                Password => $ios_password,
                                SHKC => 0,
                                Timeout  => 360,
                        );
                };
                if ($@)  {
                        eval {
				sleep(3);
                                $session_obj = Net::Appliance::Session->new(
                                        Host      => $device1,
                                        Transport => 'Telnet',
                                );
                                $session_obj =  $session_obj->connect(
#                                Name => $ios_username,
                                        Password => $ios_password,
                                        SHKC => 0,
                                        Timeout  => 360,
                                );
                        };
                        if ($@)  {
                                eval {
                                        $session_obj = Net::Appliance::Session->new(
                                                Host      => $device1,
                                                Transport => 'Telnet',
                                        );
                                        $session_obj =  $session_obj->connect(
#                                Name => $ios_username,
                                                Password => $ios_password,
                                                SHKC => 0,
                                                Timeout  => 360,
                                        );
                                };
                                if ($@)  {
                                        print "<br><font size=\"+2\"> Error connecting to $device1, script failed. Please check credentials and reachability.</font><br>";
                                        exit 0;
                                }
                        }
                }
        }
        return $session_obj
}


sub cmdSend {
        my $cmd = shift;
        my (@return,$controllercheck,$start) = ();


                print "--Run Command $cmd<br>\n" if $debug;
                eval {@return = $session_obj->cmd(String => $cmd, Timeout => 420);};

                if (@return){
                        print "--$cmd success<br>\n" if $debug;
                }
                else {
                        print "--$cmd Failed<br>\n" if $debug;
                }

        return @return;
}

sub traceSrc {
	my $srcip = shift;
	my $dstip = shift;
	my (@outarray)=();

	$session_obj->cmd(
	        String => 'traceroute ip',
	        Match => ['/IP address:/'],
	);
	$session_obj->cmd(
	        String => "$dstip",
	        Match => ['/address:/'],
	);
	$session_obj->cmd(
	        String => "$srcip",
	        Match => ['/:/'],
	);
	$session_obj->cmd(
	        String => '',
	        Match => ['/:/'],
	);
	$session_obj->cmd(
	        String => '',
	        Match => ['/:/'],
	);
	$session_obj->cmd(
	        String => '',
	        Match => ['/:/'],
	);
	$session_obj->cmd(
	        String => '',
	        Match => ['/:/'],
	);
	$session_obj->cmd(
	        String => '',
	        Match => ['/:/'],
	);
	$session_obj->cmd(
	        String => '',
	        Match => ['/:/'],
	);
	sleep(1);
	my @out = $session_obj->cmd(
	        Timeout => 60,
	        String => '',
	);
	foreach my $line(@out){
		if ($line =~ / (\d+\.\d+\.\d+\.\d+) /){
			push @outarray, $1;
		} 
	}
	return @outarray;
}



