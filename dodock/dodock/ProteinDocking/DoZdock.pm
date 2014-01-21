package DoZdock;

require Exporter;
use strict;
use warnings;
use File::Copy;
use vars qw(@ISA @EXPORT $VERSION);
our @ISA = qw(Exporter);
our @EXPORT = qw(zdock_prep run_zdock check_zdock make_zrank sort_zrank build_zdock build_zrank);
$VERSION=1.0;

sub zdock_prep{
  my ($GOUT,$block,$name1,$name2)=@_;
  my $mark1=$$name1."_m.pdb" and my $mark2=$$name2."_m.pdb";
  my $plik=$$GOUT;
  print $plik "mark_sur $$name1.pdb $mark1\n";
  my $rec= $$name1.".pdb";
  my $lig= $$name2.".pdb";
  `mark_sur $rec $mark1` if $mark1;
  print $plik "mark_sur $$name2.pdb $mark2\n";
  `mark_sur $lig $mark2` if $mark2;
  if($$block==1){
    my $blockFile1 = substr `grep '^block1.*' config`, 7;
    my $blockFile2 = substr `grep '^block2.*' config`, 7;
    `block.pl $mark1 $blockFile1` if $mark1 and $blockFile1;
    `block.pl $mark2 $blockFile2` if $mark2 and $blockFile2;
  }
}

sub run_zdock{
  my ($GOUT,$pref2,$zdc,$zdout,$mark1,$mark2,$zd_poses,$zd_seed,$zd_grid)=@_;
  my $plik=$$GOUT;
  my $prefix=$$pref2;
  my $zdock=$$zdc;
  my $rec=$$mark1;
  my $lig=$$mark2;
  my $output=$$zdout;
  my $poses=$$zd_poses;
  my $seed=$$zd_seed;
  my $grid=$$zd_grid;
  print $plik "command executed: $prefix $zdock -N $poses -S $seed -D $grid -o $output -R $rec -L $lig\n";		
  `$prefix $zdock -N $poses -S $seed -D $grid -o $output -R $rec -L $lig`;		
}

sub check_zdock{
  my ($zdock,$czas,$mies,$ARGV)=@_;
  #my $jest="nima";
  #$jest=<zdock*.out>;
  unless (-e <*.out>){
    my $beginn=$$czas[3]."-".$$mies."-".$$czas[5].".rnw";
    open(RNW, ">>../../$beginn");
    print RNW "$$ARGV[1]\t$$ARGV[2]\n";
    close(RNW);
  }
  else{
    my $done=$$czas[3]."-".$$mies."-".$$czas[5].".ok";	
    open(ZRB, ">>../../$done");
    print ZRB "$$ARGV[1]\t$$ARGV[2]\n";
    close(ZRB);
  }
}

sub make_zrank{
  my ($GOUT,$name1,$name2,$range1,$range2)=@_;
  my $plik=$$GOUT;
  my @zdoutput=`ls -1 *.out`;
  chomp @zdoutput;
  my $r1=$$range1;
  my $r2=$$range2;
  my $mark1=$$name1."_m.pdb" and my $mark2=$$name2."_m.pdb";
  my $bak1=substr($mark1,0,-4)."_bak.pdb";
  my $bak2=substr($mark2,0,-4)."_bak.pdb";
  my $new1=substr($mark1,0,-4)."_H.pdb";
  my $new2=substr($mark2,0,-4)."_H.pdb";
  copy("$mark1","$bak1");
  copy("$mark2","$bak2");
  `babel -h -ipdb $mark1 -opdb $new1`;
  `babel -h -ipdb $mark2 -opdb $new2`;
  move("$new1","$mark1");
  move("$new2","$mark2");
  foreach my $file(@zdoutput){
    `zrank $file $r1 $r2`;
    printf $plik "rescoring done; molecule: $file, models: $r1 - $r2\n";
  }
  my @zranks=`ls -1 *.zr.out`;
  chomp @zranks;
  foreach my $file(@zranks){
    my $nowy=substr($file,0,rindex($file,"."));
    move("$file","$nowy");
  }
}

sub sort_zrank{
  my ($GOUT)=@_;
  my $plik=$$GOUT;
  my @zranks=`ls -1 *.zr`;
  chomp @zranks;
  foreach my $file(@zranks){
    my $out=$file.".sort";
    `sort -n -k2,2 $file>$out`;
    printf $plik "zrank sorted; molecule: $file\n";
  }
}
		
sub build_zdock{
  my ($GOUT,$name1,$name2)=@_;
  my $plik=$$GOUT;
  my $mark1=$$name1."_m.pdb";
  my $mark2=$$name2."_m.pdb";
  my @zdoutput=`ls -1 *.out`;
  chomp @zdoutput;
  foreach my $file(@zdoutput){
    my $builddir="full".substr($file,rindex($file,"_"),rindex($file,".")-rindex($file,"_"));
    mkdir("$builddir", 0755) if (! -d "$builddir");
    copy("$file","$builddir/$file");
    copy("$mark1","$builddir/$mark1");
    copy("$mark2","$builddir/$mark2");
    chdir "$builddir" or die "Can't enter $builddir: $!\n";
    `create.pl $file`;
    print $plik "build done, complex: $file\n";
    chdir "../";
  }
}

sub build_zrank{
  my ($GOUT,$zr_cutoff,$name1,$name2)=@_;
  my $plik=$$GOUT;
  my $mark1=$$name1."_m.pdb";
  my $mark2=$$name2."_m.pdb";
  my $cutoff=$$zr_cutoff;
  my @zdoutput=`ls -1 *.out`;
  unless(-e $mark1){$mark1=$$name1.".pdb";}
  chomp @zdoutput;
  foreach my $file(@zdoutput){
    my $builddir="full".substr($file,rindex($file,"_"),rindex($file,".")-rindex($file,"_"));
    if (-d $builddir){
      my $topsel="top".$cutoff.substr($file,rindex($file,"_"),rindex($file,".")-rindex($file,"_"));
      mkdir("$topsel", 0755) if (! -d "$topsel");
      copy("$mark1","$topsel/$mark1");
      my $zrout=$file.".zr.sort";
      open (ZRANK, "<$zrout");
      my @posort=<ZRANK>;
      chomp @posort;
      close (ZRANK);
      for my $lin (0..$cutoff-1){
        my @val=split(/\s+/,$posort[$lin]);
        my $ind=$val[0];
        my $pdbsel=$mark2.".".$ind;
        my $pdbout=$lin."-".$mark2.".".$ind;
        print $plik "$builddir/$pdbsel\n";
        copy("$builddir/$pdbsel","$topsel/$pdbout");
      }
    }
  }
}

