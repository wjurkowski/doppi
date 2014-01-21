package DoFireDock;

require Exporter;
use strict;
use warnings;
use File::Copy;
use vars qw(@ISA @EXPORT $VERSION);
our @ISA = qw(Exporter);
our @EXPORT = qw(firedock_prep run_firedock);
$VERSION=1.0;
1;

sub firedock_prep{
  my ($GOUT,$name1,$name2,$zdockin)=@_;
  my $plik=$$GOUT;
  my $pdb1=$$name1.".pdb";
  my $pdb2=$$name2.".pdb";
  my $out=$pdb1."-".$pdb2;
  if($$zdockin==1){
    my @zdoutput=`ls -1 *.out`;
    chomp @zdoutput;
    foreach my $zdockout(@zdoutput){
      my $zdocktrans=$zdockout.".trans";
      my $firedockout=$zdockout.".firedock";
      my $firedock_params=$zdockout.".FireDock_params.txt";
      `perl ZDOCKOut2Trans.pl $zdockout > ! $zdocktrans`;
      `perl buildFireDockParams.pl $pdb1 $pdb2 U U EI $zdocktrans $firedockout 0 50 0.8 0 FireDock_params.txt`;
    }
  }
  else{#can it be done without zdock output?
  my $zdocktrans=" ";
  my $firedockout=" ";
  `perl preparePDBs.pl $pdb1 $pdb2`;
  `perl buildFireDockParams.pl $pdb1 $pdb2 U U EI $zdocktrans $firedockout 0 50 0.8 0 FireDock_params.txt`;
  }
  print $plik "firedock preparation done\n";
}

sub run_firedock{
  my ($GOUT)=@_;
  my $plik=$$GOUT;
  `perl runFireDock.pl FireDock_params.txt`;
  print $plik "firedock run done\n";
}
