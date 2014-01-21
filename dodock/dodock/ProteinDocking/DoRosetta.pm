package DoRosetta;

use warnings;
use strict;
require Exporter;
use vars qw(@ISA @EXPORT $VERSION);
our @ISA = qw(Exporter);
our @EXPORT = qw(rosetta_prep run_rosetta check_rosetta refine_rosetta make_score);
$VERSION=1.0;

sub rosetta_prep{
  my ($dbpath,$ARGV)=@_;
  `cat $$dbpath/$$ARGV[1] $$dbpath/$$ARGV[2] >target.pdb`;
  `rosetta.gcc aa capri _ -s target.pdb -dock -prepack_full -prepack_rtmin -ex1 -ex2&`;
}

sub run_rosetta{
  `rosetta.gcc ab capri _ -s target.ppk -dock -dock_min -dock_pert 5 15 25 -randomize2 -randomize1 -nstruct 5000`;
  `sort -n -k2,2 capri.fasc>sorted.fasc`;
  open(CUT, "<sorted.fasc");
  my @scores=<CUT>;
  chomp @scores;
  close (CUT);
  my $ln=0.01*$#scores;	
  my @line=split(/\s+/,$scores[$ln]);
  my $cutoff=$line[1]; #define cutoff as 1% of top results
  `rosetta.gcc ab capri _ -s target.ppk -dock -dock_min -dock_pert 5 15 25 -randomize2 -randomize1 -scorefilter $cutoff -nstruct 1000`;
}

sub check_rosetta{
my ($rosettadir,$czas,$mies,$ARGV)=@_;
my $rdout="capriab.fasc";
if (!-e $rdout) {
  my $beginn=$$czas[3]."-".$$mies."-".$$czas[5].".rnw";
  open(RNW, ">>$$rosettadir/$beginn");
  print RNW "$$ARGV[1]\t$$ARGV[2]\n";
  close(RNW);
}
else{
  my $done=$$czas[3]."-".$$mies."-".$$czas[5].".ok";	
  open(ZRB, ">>$$rosettadir/$done");
  print ZRB "$$ARGV[1]\t$$ARGV[2]\n";
  close(ZRB);
}
}

sub refine_rosetta{
  my ($ARGV)=@_;
  my $surowy=$$ARGV[1];
  `rosetta.gcc aa capri _ -s $surowy -dock -dock_min -docking_local_refine -nstruct 10`;
}

sub make_score {
  my ($ARGV)=@_;
  my $surowy=$$ARGV[1];
  `rosetta.gcc aa capri _ -s $surowy -dock –score -dockFA -dock_score_norepack`;
}

1;
