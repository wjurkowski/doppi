#!/usr/bin/perl -w
use strict;
use warnings;
use File::Copy;

use DoZdock;
use DoFtdock;
use DoRosetta;
use FindSites;
use DoFireDock;
use AnalyzeInterface;

if ($#ARGV < 2) {die "Program requires command line parameters [config file] [pdb1] [pdb2] \n";}

my ($program,$dbpath,%params,$pref2,$wexe,$zd,$ftd,$mark1,$mark2);
open(CONF, "<$ARGV[0]") if $ARGV[0];
my @configFile = <CONF>;
chomp @configFile;
close(CONF);

foreach my $line(@configFile){
  unless (($line=~ /^\#/) or ($line=~ /^$/)) {
    my @para=split(/\s+/,$line);
    $params{$para[0]}=$para[1];
  }
}
my $home=`pwd`;
chomp $home;

my @czas=localtime(time());
my $starttime=time();
$czas[5] += 1900;
my @abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
my $mies=$abbr[$czas[4]];
my $name1=$ARGV[1];
my $name2=$ARGV[2];
if($name1!~m/^pdb/i){
  $name1="pdb".$name1;
  $name2="pdb".$name2;
}
#grab installation dir
my $file = `which dodock.pl`;
my $ddpath=substr($file,0,rindex($file,"/"));

my $goutput="PP-docking.".$czas[3]."-".$mies."-".$czas[5].".out";
open my $GOUT, '>>', "$goutput" or die "...$!";
#open my $ZDOUT, '>>', $zdockout or die "...$!";
print $GOUT "dodock started at: @czas\n";
unless (-s $goutput){
	printf $GOUT "Produced by dodock.pl (by Wiktor Jurkowski)\n";
	printf $GOUT "Currently set parameters (please refer to README):\n";
	while (my ($key, $value)=each(%params)){  
	  printf $GOUT "$key = $value\n";
	}
}

if($params{'dbpath'}){
  $dbpath=$params{'dbpath'};
  if ($dbpath eq "."){print $GOUT "Data Base: local\n";}
}

if($params{'easy'}==1){
  printf $GOUT "System: easy batch\n";
  my $pre="esubmit -n 1 "; 
  my $t2="-t $params{'time2'}" if $params{'time2'};
  my $Tstart=" -T $params{'startt'}" if $params{'startt'};
  $pref2=$pre.$t2.$Tstart;
}
else{
  printf $GOUT "System: local\n";
  $pref2='';
}

#search for similar proteins
if($params{'find_templ'}==1){
  my $bialko;
  for my $i (0..1){
    if($i==0){$bialko=$ARGV[0];}
    if($i==1){$bialko=$ARGV[1];}
    my ($templ_name,$templ_ev,$templ_bit,$templ_ident,$templ_length,$n_templ);
    my ($sel_templ_name,$sel_templ_chid,$n_sel_templ);
    ($templ_name,$templ_ev,$templ_bit,$templ_ident,$templ_length,$n_templ)=get_templates(\$bialko);#retrieve templates from pdb
    ($sel_templ_name,$sel_templ_chid,$n_sel_templ)=select_template(\$templ_name,\$templ_ident,\$templ_length,\$n_templ);#selection of top10 single templates
  }
}

#run zdock
if($params{'zdock'}==1){	
  print "pair processed: $name1 $name2\n";
  print $GOUT "zdock in run\n";
  my $name1=substr($ARGV[1],0,index($ARGV[1],"."));
  my $name2=substr($ARGV[2],0,index($ARGV[2],"."));
  my $zdockdir="zdock-docking";
  my $pair= "DP_".$name1."-".$name2;
  mkdir("$zdockdir", 0755) if (! -d "$zdockdir");
  mkdir("$zdockdir/$pair", 0755) if (! -d "$zdockdir/$pair");
  copy("$dbpath/$ARGV[1]","$zdockdir/$pair/$ARGV[1]") if (! -e "$zdockdir/$pair/$ARGV[1]");
  copy("$dbpath/$ARGV[2]","$zdockdir/$pair/$ARGV[2]") if (! -e "$zdockdir/$pair/$ARGV[2]");
  my $zd_poses=$params{'zd_poses'};
  my $zd_seed=$params{'zd_seed'};
  my $zd_grid=$params{'zd_grid'};
  my $range=1000;
  my $random=int(rand($range));
  #my $zdout=$name1."_".$name2."-".$random.".out";
  my $zdout="zdock.out";	
  my $block=$params{'block'};
  my $range1=$params{'zd_r1'};
  my $range2=$params{'zd_r2'};
  my $zr_cutoff=$params{'zr_cutoff'};
  if($params{'zdock_bin'}){
    $wexe=$params{'zdock_bin'};
    printf $GOUT "Program version in use: $wexe\n";	
  }

  if($params{'zdock1'}==1){#1st stage: prepare files, define restraints
    copy("$ddpath/lib/uniCHARMM","$zdockdir/$pair/uniCHARMM");
    chdir "$zdockdir/$pair" or die "Can't enter $zdockdir/$pair: $!\n";
    zdock_prep(\$GOUT,\$block,\$name1,\$name2);
    chdir "../../";
  }

  if($params{'zdock2'}==1){#2nd stage: run zdock
    if($wexe){$zd=$wexe."zdock";}
    else{$zd="zdock";}
    chdir "$zdockdir/$pair" or die "Can't enter $zdockdir/$pair: $!\n";
    if ($params{'zdock1'}==1){
      $mark1=$name1."_m.pdb";
      $mark2=$name2."_m.pdb";
      run_zdock(\$GOUT,\$pref2,\$zd,\$zdout,\$mark1,\$mark2,\$zd_poses,\$zd_seed,\$zd_grid);
    }  
    else{
      $mark1=$name1.".pdb";
      $mark2=$name2.".pdb";
      run_zdock(\$GOUT,\$pref2,\$zd,\$zdout,\$mark1,\$mark2,\$zd_poses,\$zd_seed,\$zd_grid);	
    }
    chdir "../../";
  }

  if($params{'zdock3'}==1){#3rd stage: check files 
    chdir "$zdockdir/$pair" or die "Can't enter $zdockdir/$pair: $!\n";
    check_zdock(\$zdout,\@czas,\$mies,\@ARGV);
    chdir "../../";
  }

  if($params{'zdock5'}==1){#5th stage: build files
    chdir "$zdockdir/$pair" or die "Can't enter $zdockdir/$pair: $!\n";
    build_zdock(\$GOUT,\$name1,\$name2);
    chdir "../../";
  }

  if($params{'zdock4'}==1){#4th stage rerank
    chdir "$zdockdir/$pair" or die "Can't enter $zdockdir/$pair: $!\n";
    make_zrank(\$GOUT,\$name1,\$name2,\$range1,\$range2);
    sort_zrank(\$GOUT);
    build_zrank(\$GOUT,\$zr_cutoff,\$name1,\$name2);
    chdir "../../";
  }
  print $GOUT "zdock done\n";
}

#runs ftdock
if($params{'ftdock'}==1){
  print "pair processed: $name1 $name2\n";
  print $GOUT "ftdock in run:\n";
  my $name1=substr($$ARGV[1],0,index($$ARGV[1],"."));
  my $name2=substr($$ARGV[2],0,index($$ARGV[2],"."));
  my $ftdockdir="ftdock-docking";
  my $pair= "DP_".$name1."-".$name2;
  mkdir("$ftdockdir", 0755) if (! -d "$ftdockdir");
  mkdir("$ftdockdir/$pair", 0755) if (! -d "$ftdockdir/$pair");
  my $ftdout="ftdock_".$name1."-".$name2."-glob.dat";
  my $rpscout="ftdock_".$name1."-".$name2."-rpsc.dat";
  my $rspin=$params{'rspin'};
  if($params{'ftdock_bin'}){
    $wexe=$params{'ftdock_bin'};
    printf $GOUT "Program version in use: $wexe\n";	
  }

  if($params{'ftdock1'}==1){#1st stage: prepare files, define restraints
    copy("best.matrix","$ftdockdir/$pair") or die "Copy of best.matrix failed: $!";
    chdir "$ftdockdir/$pair" or die "Can't enter $ftdockdir/$pair: $!\n";
    ftdock_prep(\@ARGV,\$dbpath,\$rspin);
    chdir "../../";
  }
  if($params{'ftdock2'}==1){#2nd stage: run ftdock
    if($wexe){$ftd=$wexe."ftdock";}
    else{$ftd="ftdock";}
    chdir "$ftdockdir/$pair" or die "Can't enter $ftdockdir/$pair: $!\n";
    if($params{'rerun'}==1){
      printf $GOUT "ftdock -rescue\n";
      `ftdock -rescue`;
    }
    else{ 
      run_ftdock(\$GOUT,\$pref2,\@ARGV,\$ftd,\$name1,\$name2,\$ftdout);
    }
    chdir "../../";
  }
  if($params{'ftdock3'}==1){#3rd stage: check files 
    chdir "$ftdockdir/$pair" or die "Can't enter $ftdockdir/$pair: $!\n";
    check_ftdock(\@ARGV,\$ftdout,\@czas,\$mies);
    chdir "../../";
  }
  if($params{'ftdock4'}==1){#4th stage rerank
    if($wexe){$ftd=$wexe."rpscore";}
    else{$ftd="rpscore";}
    chdir "$ftdockdir/$pair" or die "Can't enter $ftdockdir/$pair: $!\n";
    ftdock_rpscore(\$GOUT,\$ftd,\$ftdout,\$rpscout);
    chdir "../../";
  }
  if($params{'ftdock5'}==1){#5th stage: build files
    my $build=$params{'build'};
    my $centres=$params{'centres'};
    my $scr_type=$params{'scoret'};
    my $range1=$params{'ftd_r1'};
    my $range2=$params{'ftd_r2'};
    chdir "$ftdockdir/$pair" or die "Can't enter $ftdockdir/$pair: $!\n";
    if($params{'filtruj'}==1){
      build_ftdock_f(\$GOUT,\@ARGV,\$ftdout,\$rpscout,\@czas,\$mies,\$build,\$centres,\$scr_type,\$range1,\$range2,\@configFile);
    }
    else{
      build_ftdock(\$GOUT,\@ARGV,\$ftdout,\$rpscout,\@czas,\$mies,\$build,\$centres,\$scr_type,\$range1,\$range2,\@configFile);
    }
    chdir "../../";
  }
  print $GOUT "ftdock done\n";
}

#runs firedock
if ($params{'firedock'}==1){
  print "pair processed: $name1 $name2\n";
  print $GOUT "firedock in run\n";
  my $zdockin=$params{'zdockin'};
  if($params{'ftdock_bin'}){
    $wexe=$params{'ftdock_bin'};
    printf $GOUT "Program version in use: $wexe\n";
  }
  my $name1=substr($ARGV[1],0,index($ARGV[1],"."));
  my $name2=substr($ARGV[2],0,index($ARGV[2],"."));
  firedock_prep(\$name1,\$name2,\$zdockin);
  run_firedock();
  print $GOUT "firedock done\n";
}

#runs rosetta
if($params{'rosetta'}==1){
  print "pair processed: $name1 $name2\n";
  print $GOUT "rosetta in run\n";
  my $name1=substr($$ARGV[1],0,index($$ARGV[1],"."));
  my $name2=substr($$ARGV[2],0,index($$ARGV[2],"."));
  my $rosettadir="rosetta-docking";
  my $pair= "DP_".$name1."-".$name2;
  mkdir("$rosettadir", 0755) if (! -d "$rosettadir");
  mkdir("$rosettadir/$pair", 0755) if (! -d "$rosettadir/$pair");
  if($params{'rosetta_bin'}){
    $wexe=$params{'rosetta_bin'};
    printf $GOUT "Program version in use: $wexe\n";	
  }

  if($params{'rosetta1'}==1){#1st stage: prepare files, define restraints
    chdir "$rosettadir/$pair" or die "Can't enter $rosettadir/$pair: $!\n";
    rosetta_prep(\$dbpath,\@ARGV);
    chdir "../../";
  }
  if($params{'rosetta2'}==1){#2nd stage: run zdock
    chdir "$rosettadir/$pair" or die "Can't enter $rosettadir/$pair: $!\n";
    run_rosetta();
    chdir "../../";
  }
  if($params{'rosetta3'}==1){#3rd stage: check files 
    check_rosetta(\$rosettadir,\@czas,\$mies,\@ARGV);
  }
  if($params{'rosetta4'}==1){#4th stage: refine
    refine_rosetta(\@ARGV);
  }
  if($params{'rosetta5'}==1){#5th stage: score files	
    make_score(\@ARGV);
  }
  print $GOUT "rosetta done\n";
}

#calculate rms of all results saved in output folders
if(($params{'get_all_rms'}==1) or ($params{'get_top_rms'}==1)){
  my ($dockdir,$rms_type);
  my $name1=substr($ARGV[1],0,index($ARGV[1],"."));
  my $name2=substr($ARGV[2],0,index($ARGV[2],"."));
  my $pair= "DP_".$name1."-".$name2;
  if($params{'rms_type'}==1){$rms_type=1;}
  elsif($params{'rms_type'}==2){$rms_type=2;}
  if($params{'run'} eq "zdock"){
    $dockdir="zdock-docking";
  }
  chdir "$dockdir/$pair" or die "Can't enter $dockdir/$pair: $!\n";
  if($params{'get_all_rms'}==1){get_all_rms(\$rms_type);}
  elsif($params{'get_top_rms'}==1){get_top_rms(\$rms_type);}
  print $GOUT "runs RMS calculation of ligand after receptor molecular fit (pr_alchem):\n";
  chdir "../../";
}

#calculate receptor-ligand contacts 
if(($params{'get_all_contacts'}==1) or ($params{'get_top_contacts'}==1)) {
  my ($dockdir);
  my $contact_r=$params{'contact_radii'};
  my $contact_cutoff=$params{'contact_cutoff'};
  my $name1=substr($ARGV[1],0,index($ARGV[1],"."));
  my $name2=substr($ARGV[2],0,index($ARGV[2],"."));
  my $pair= "DP_".$name1."-".$name2;
  if($params{'run'} eq "zdock"){
    $dockdir="zdock-docking";
  }
  chdir "$dockdir/$pair" or die "Can't enter $dockdir/$pair: $!\n";
  if($params{'get_all_contacts'}==1){get_all_contacts(\$name1,\$contact_r,\$contact_cutoff);}
  elsif($params{'get_top_contacts'}==1){get_top_contacts(\$name1,\$contact_r,\$contact_cutoff);}
  print $GOUT "calculates contacts between receptor and ligand (cmapper):\n";
  chdir "../../";
}

my $endtime=time();
my $runt=$endtime-$starttime;
my $minutes=$runt/60;
@czas=localtime(time());
print $GOUT "dodock finished at: @czas\n";
print $GOUT "run time in minutes: $minutes\n";
close ($GOUT);
