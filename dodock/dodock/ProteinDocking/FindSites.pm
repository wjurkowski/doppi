package FindSites;

require Exporter;
use strict;
use warnings;
use File::Copy;
use vars qw(@ISA @EXPORT $VERSION);
our @ISA = qw(Exporter);
our @EXPORT = qw(get_similar select_template);
$VERSION=1.0;

sub get_fasta{
my ($name1,$name2)=@_;
my $rec=$$name1.".pdb";
my $lig=$$name2.".pdb";
`pr_alchem lib/prm-fasta $rec`;  
`pr_alchem lib/prm-fasta $lig`;  
}


sub get_similar{
my ($bialko)=@_;
my (@templ_name,@templ_ev,@templ_bit,@templ_ident,@templ_length);
my $bial=$$bialko;
my @res=`blastp -task blastp -query $$bialko -db pdbaa -outfmt '6 sacc evalue bitscore pident length'`;
my $n=0;
foreach my $lin(@res){
  my @linia=split(/\s+/,$lin);
  if($linia[1] <= 1e-05){
        $n++;
        $templ_name[$n]=$linia[0];
        $templ_ev[$n]=$linia[1];
        $templ_bit[$n]=$linia[2];
        $templ_ident[$n]=$linia[3];
        $templ_length[$n]=$linia[4];
  }
}
if ($n > 0){
 return (\@templ_name,\@templ_ev,\@templ_bit,\@templ_ident,\@templ_length,\$n);
}
}

sub select_template{
my ($templ_name,$templ_ident,$templ_length,$n_templ)=@_;
my (@best,@second,@sel_templ,@sel_templ2,@sel_templ_name,@sel_templ_chid);
$best[0]=0;
my $m=0;
my $k=0;
for my $i(1..$n_templ){
 if($$templ_ident[$i] >=$$templ_ident[0]-10){
  $m++;
  $best[$m]=$i;
 }
 else{
  $second[$k]=$i;
  $k++;
 }
}
my $najdl=0;
for my $i(1..$#best){
 if($$templ_length[$best[$i]] >$najdl+$najdl*0.1){
  $najdl=$best[$i];
  unshift (@sel_templ,$best[$i]);
 }
}
$najdl=0;
for my $i(1..$#second){
 if($$templ_length[$second[$i]] >$najdl+$najdl*0.1){
  $najdl=$second[$i];
  unshift (@sel_templ2,$second[$i]);
 }
}
push (@sel_templ,@sel_templ2);
my $n=10;
if ($#sel_templ < 10) {$n=$#sel_templ;}
for my $i (0..$n) {
 ($sel_templ_name[$i],$sel_templ_chid[$i])=split(/-/,$$templ_name[$sel_templ[$i]]);
}
return (\@sel_templ_name,\@sel_templ_chid,\$n);
}

