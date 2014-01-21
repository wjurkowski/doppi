package DoFtdock;

require Exporter;
use strict;
use warnings;
#use IO::Compress::Gzip qw(gzip $GzipError);
use vars qw(@ISA @EXPORT $VERSION);
our @ISA = qw(Exporter);
our @EXPORT = qw(ftdock_prep run_ftdock check_ftdock ftdock_rpscore build_ftdock);
$VERSION=1.0;
	
sub ftdock_prep{#1st stage:	preprocss pdb file, move to separate directories, spin if required
my ($ARGV,$dbpath,$rspin)=@_;			
my $pairs=$$ARGV[3];
my $pdb1=$$ARGV[1];
my $pdb2=$$ARGV[2];
if($$rspin==1){
  $pdb1=substr($ARGV[1],0,-4).".rspin.pdb";
  $pdb2=substr($ARGV[2],0,-4).".rspin.pdb";
  `randomspin -in $$dbpath/$$ARGV[1] -out $$dbpath/$pdb1`;
  `randomspin -in $$dbpath/$$ARGV[2] -out $$dbpath/$pdb2`;
}				
`preprocess-pdb.perl -pdb $$dbpath/$pdb1` or print "preprocess-pdb.perl exited with value %d\n", $? >> 8;
`preprocess-pdb.perl -pdb $$dbpath/$pdb2` or print "preprocess-pdb.perl exited with value %d\n", $? >> 8;
my $mol1=substr($$ARGV[1],0,-4).".parsed";
my $mol2=substr($$ARGV[2],0,-4).".parsed";
my $fasta1=substr($$ARGV[1],0,-4).".fasta";
my $fasta2=substr($$ARGV[2],0,-4).".fasta";
move("$$dbpath/$mol1", ".");
move("$$dbpath/$mol2", ".") if $mol2 ne $mol1;
move("$$dbpath/$fasta1", ".");
move("$$dbpath/$fasta2", ".") if $fasta1 ne $fasta2;
} 

sub run_ftdock{#2nd stage: run ftdock
  my ($GOUT,$pref2,$ARGV,$ftd,$name1,$name2,$ftdout)=@_;
  my $plik=$$GOUT;
  my $pdb1= "-static ". substr ($$ARGV[1], 0, -4 ).".parsed"  if $$ARGV[1];
  my $pdb2 = "-mobile ". substr ($$ARGV[2], 0, -4 ).".parsed" if $$ARGV[2];	
  my $term=">&".substr($$name1, 3, 6)."-".substr($$name2, 3, 6).".o";	
  printf $plik "$$pref2 $$ftd $pdb1 $pdb2 -out $$ftdout $term\n";
  `$$pref2 $$ftd $pdb1 $pdb2 -out $$ftdout $term`;					
  printf $plik "ftdock exited with value %d\n", $? >> 8;
}

sub check_ftdock {#3rd stage: check docking results
  my ($ARGV,$ftdout,$czas,$mies)=@_;
  my $scratch1="scratch_parameters.dat";
  my $scratch2="scratch_scores.dat";
  if ((!-e $$ftdout) and (-e $scratch1) and (-e $scratch2)) {
    my $restart=$$czas[3]."-".$$mies."-".$$czas[5].".rst";
    open(ROUT, ">>../../$restart");
    print ROUT "$$ARGV[1]\t$$ARGV[2]\n";
    close(ROUT);
  }
  if ((!-e $$ftdout) and ((!-e $scratch1) or (!-e $scratch2))) {
    my $beginn=$$czas[3]."-".$$mies."-".$$czas[5].".rnw";
    open(RNW, ">>../../$beginn");
    print RNW "$$ARGV[1]\t$$ARGV[2]\n";
    close(RNW);
  }
  if (-e $$ftdout){
    my $done=$$czas[3]."-".$$mies."-".$$czas[5].".ok";	
    open(ZRB, ">>../../$done");
    print ZRB "$$ARGV[1]\t$$ARGV[2]\n";
    close(ZRB);
  }
}

sub ftdock_rpscore{#4rd stage: rerank with rpscore
  my ($GOUT,$ftd,$ftdout,$rpscout)=@_;
  my $plik=$$GOUT;
  `$$ftd -in $$ftdout -out $$rpscout`;
  printf $plik "$$ftd -in $$ftdout -out $$rpscout\n";
  printf $plik "rpscore exited with value %d\n", $? >> 8;
}

sub build_ftdock_f {#4th stage: filter results, build pdb, display all results as dots 
  my ($GOUT,$ARGV,$ftdout,$rpscout,$czas,$mies,$build,$centres,$scr_type,$range1,$range2,$configFile)=@_;
  my $plik=$$GOUT;
  my (@filterLines,@filters,$ln);
  my $m1="-b1 ".$$range1;
  my $m2="-b2 ".$$range2;
  my $nazwa='Complex_';
  my @filterData = $$configFile[$filterLines[0] .. $filterLines[1]];	
  my $baseFileName = $$ARGV[1]."_".$$ARGV[2]."_f";
  for ($ln=0;$ln<=$#{$configFile};$ln++){
    if($$configFile[$ln]=~m/filters/){
    push @filterLines,$ln;}
  }
  foreach my $line(@filterData){
    if($line =~ /(\d+) ([^$\+]*)/ ){
      $filters[$1]=$2;
      `filter -constraints $2 -in $$ftdout -out $ARGV[1]."_".$ARGV[2]."_f".$1.".dat"` if $$scr_type==1;
      `filter -constraints $2 -in $$rpscout -out $ARGV[1]."_".$ARGV[2]."_f".$1.".dat"` if $$scr_type==2;
      if ($build==1){
	my $folder="Models-scf".$$scr_type."-f".$1.".".$$czas[3]."-".$mies."-".$$czas[5];	
	mkdir("$folder", 0755) if (! -d "$folder") and $$build==1;
	`build $m1 $m2 -in $$ARGV[1]."_"$$ARGV[2]."_f".$1.".dat"`;
	my @list = <$nazwa*>;
	#gzip $_ => $_.".gz" or die "gzip failed: $GzipError\n" foreach(@list);
	@list = <$nazwa*>;
	move("$_", "$folder/") foreach(@list);
	printf $plik "build done, file:  $$ARGV[1]._$$ARGV[2]._f.$1.dat , models: $$range1 - $$range2\n";
      }					
      if ($centres==1){
	`centres -in $$ARGV[1]."_"$$ARGV[2]."_f".$1.".dat"`;
	my $newcentres=$$ARGV[1]."_".$$ARGV[2]."_f".$1."_centres.pdb";
	move("centres.pdb", $newcentres) or die "Move of centres.pdb failed: $!";
	printf $plik "centers done, file:  $$ARGV[1]._$$ARGV[2]._f.$1.dat \n";
      }
    }
    elsif( $line =~ /((\d\+)+\d)\n?/ ){						
      my @inputs = split(/\+/, $1);
      my $i =0;
      my $prev_suffix;
      while ($#inputs > $i){
	my $suffix = join('_', @inputs[0 .. $i+1]);
	$prev_suffix = join('_', $inputs[$i]) if $i == 0;
	printf $plik "filter -constraints $filters[$inputs[$i+1]] -in $baseFileName$prev_suffix.dat -out $baseFileName$suffix.dat\n";
	`filter -constraints $filters[$inputs[$i]] -in $baseFileName.$prev_suffix.".dat" -out $baseFileName.$suffix.".dat"`;
	if ($build==1){
	  my $folder="Models-scf".$scr_type."-f".$suffix.".".$$czas[3]."-".$$mies."-".$$czas[5];	
	  mkdir("$folder", 0755) if (! -d "$folder") and $build==1;
	  `build $m1 $m2 -in $baseFileName.$suffix.".dat"`;
	  my @list = <$nazwa*>;
	  #gzip $_ => $_.".gz" or die "gzip failed: $GzipError\n" foreach(@list);
	  @list = <$nazwa*>;
	  move("$_", "$folder/") foreach(@list);
	  printf $plik "build done, file: $baseFileName.$suffix.dat , models: $$range1 - $$range2\n";
	}	
	if ($centres==1){
	  `centres -in $baseFileName.$suffix.".dat"`;
	  my $newcentres=$baseFileName.$suffix."_centres.pdb";
	  move ("centres.pdb", $newcentres) or die "Move of centres.pdb failed: $!";
	  printf $plik "centers done, file: $baseFileName.$suffix.dat \n" ;
	}
	$prev_suffix =  $suffix;
	$i++;
    } 
  }
}
}


sub build_ftdock {#4th stage: build pdb, display all
  my ($GOUT,$ARGV,$ftdout,$rpscout,$czas,$mies,$build,$centres,$scr_type,$range1,$range2,$configFile)=@_;
  my $plik=$$GOUT;
  my $m1="-b1 ".$$range1;
  my $m2="-b2 ".$$range2;
  my $nazwa='Complex_';
  if ($$build==1){
    my $folder="Models-scf".$$scr_type.".".$$czas[3]."-".$$mies."-".$$czas[5];
    mkdir("$folder", 0755) if (! -d "$folder") and $$build==1;
    `build $m1 $m2 -in $ftdout` if $$scr_type==1;
    `build $m1 $m2 -in $rpscout` if $$scr_type==2;
    my @list = <$nazwa*>;
    #gzip $_ => $_.".gz" or die "gzip failed: $GzipError\n" foreach(@list);
    @list = <$nazwa*gz>;
    move("$_", "$folder/") foreach(@list);
    @list = <$nazwa*>;
    unlink($_) foreach(@list);
    printf $plik "build done, molecules: $$ftdout, models: $$range1 - $$range2\n" if  $$scr_type==1;
    printf $plik "build done, molecules: $$rpscout, models: $$range1 - $$range2\n" if $$scr_type==2;
  }
  if ($$centres==1){
    `centres -in $$ftdout` if $$scr_type==1;
    `centres -in $$rpscout` if $$scr_type==2;
    printf $plik "centers done, molecules: $$ftdout \n" if $$scr_type==1;
    printf $plik "centers done, molecules: $$rpscout \n" if $$scr_type==2;
  }
}
1;
