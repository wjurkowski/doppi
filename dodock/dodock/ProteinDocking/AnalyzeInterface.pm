package AnalyzeInterface;

require Exporter;
use strict;
use warnings;
use File::Copy;
use vars qw(@ISA @EXPORT $VERSION);
our @ISA = qw(Exporter);
our @EXPORT = qw(get_all_rms get_top_rms get_all_contacts get_top_contacts);
$VERSION=1.0;


sub get_all_rms{
  my ($rms_type)=@_;
  my $rms_t=$$rms_type;
  my @output=`ls -1d full*`;#directories with complete results
  chomp @output;
  foreach my $builddir(@output){
    chdir "$builddir" or die "Can't enter $builddir: $!\n";
    open(RMS,">rms_out.txt");
    my @build=`ls -1 *.pdb.*`;
    chomp @build;
    for my $i (0..$#build-1){
      for my $j ($i+1..$#build){
        my $rms="0";
        my $str=$build[$i];
        my $str2=$build[$j];
        if($rms_t==1){$rms=get_rms(\$str,\$str2);}
        elsif($rms_t==2){$rms=get_fit_rms(\$str,\$str2);}
	print RMS "$rms\n";	
      }
    }
    close (RMS);
    chdir "../";
  }
}

sub get_top_rms{
  my ($rms_type)=@_;
  my $rms_t=$$rms_type;
  my @zdoutput=`ls -1d top*`;#directories with top results
  chomp @zdoutput;
  foreach my $topsel(@zdoutput){
    chdir "$topsel" or die "Can't enter $topsel: $!\n";
    open(RMS,">rms_out.txt");
    my @build=`ls -1 *.pdb.*`;
    chomp @build;
    for my $i (0..$#build-1){
      for my $j ($i+1..$#build){
        my $rms="0";
        my $str=$build[$i];
        my $str2=$build[$j];
        if($rms_t==1){$rms=get_rms(\$str,\$str2);}
        elsif($rms_t==2){$rms=get_fit_rms(\$str,\$str2);}
	print RMS "$rms\n";	
      }
    }
    close (RMS);
    chdir "../";
  }
}

sub get_all_contacts{#takes *pdb.[number] as ligand
  my ($name1,$contact_r,$contact_cutoff)=@_;
  my $re=$$name1;
  my $cutoff=$$contact_cutoff;
  my $radii=$$contact_r;
  my @output=`ls -1d full*`;#directories with complete results
  chomp @output;
  foreach my $builddir(@output){
    chdir "$builddir" or die "Can't enter $builddir: $!\n";
    my $rec=`ls -1 $re*pdb`;
    chomp $rec;
    mkdir("contacts", 0755) if (! -d "contacts");
    my @build=`ls -1 *.pdb.*`;
    chomp @build;
    foreach my $str(@build){
      get_contacts(\$rec,\$str,\$radii,\$cutoff);
    }
    chdir "../";
  }
}

sub get_top_contacts{#takes *pdb.[number] as ligand
  my ($name1,$contact_r,$contact_cutoff)=@_;
  my $re=$$name1;
  my $cutoff=$$contact_cutoff;
  my $radii=$$contact_r;
  my @output=`ls -1d top*`;#directories with top results
  chomp @output;
  foreach my $topsel(@output){#for each docking
    chdir "$topsel" or die "Can't enter $topsel: $!\n";
    my $rec=`ls -1 $re*pdb`;
    chomp $rec;
    mkdir("contacts", 0755) if (! -d "contacts");
    my @build=`ls -1 *.pdb.*`;
    chomp @build;
    foreach my $str(@build){
      get_contacts(\$rec,\$str,\$radii,\$cutoff);
    }
    chdir "../";
  }
}

sub get_rms{
  my ($f1,$f2)=@_;
  my $pdb1=$$f1.".pdb";
  my $pdb2=$$f2.".pdb";
  open(OPT, ">prm-RMSD") or die "Can not open an input file: $!";
  print OPT "&basics\n";
  print OPT "filetp=1,minres=5,stranal=1,num_mol=2\n";
  print OPT "/\n";
  print OPT "&geomet\n";
  print OPT "AAoverlay=0,bbaln=1,overlay=1,fit=0\n";
  print OPT "/\n";
  print OPT "&inpout\n";
  print OPT "pdbsave=0,outpdb=0\n";
  print OPT "/\n";
  close (OPT);
  my $wyn=`pr_alchem prm-RMSD $pdb1 $pdb2`;
  if ($? == -1) {print "failed to execute: $!\n";}
  elsif ($? & 127) {printf "child died with signal %d, %s coredump\n",
   ($? & 127),  ($? & 128) ? 'with' : 'without';}
  my @vyn=split(/\s+/,$wyn);
  return $vyn[2];
}

sub get_fit_rms{
  my ($f1,$f2)=@_;
  my $pdb1=$$f1.".pdb";
  my $pdb2=$$f2.".pdb";
  open(OPT, ">prm-RMSD") or die "Can not open an input file: $!";
  print OPT "&basics\n";
  print OPT "filetp=1,minres=5,stranal=1,num_mol=2\n";
  print OPT "/\n";
  print OPT "&geomet\n";
  print OPT "AAoverlay=0,bbaln=1,overlay=1,fit=1\n";
  print OPT "/\n";
  print OPT "&inpout\n";
  print OPT "pdbsave=0,outpdb=0\n";
  print OPT "/\n";
  close (OPT);
  my $wyn=`pr_alchem prm-RMSD $pdb1 $pdb2`;
  if ($? == -1) {print "failed to execute: $!\n";}
  elsif ($? & 127) {printf "child died with signal %d, %s coredump\n",
   ($? & 127),  ($? & 128) ? 'with' : 'without';}
  my @vyn=split(/\s+/,$wyn);
  return $vyn[2];
}

sub get_L_rms{
  my ($f1,$f2,$rec1,$rec2,$lig1,$lig2)=@_;
  my $pdb1=$$f1.".pdb";
  my $pdb2=$$f2.".pdb";
  my $recs=$$rec1;
  my $rece=$$rec2;
  my $ligs=$$lig1;
  my $lige=$$lig2;
  open(OPT, ">prm-L_RMS") or die "Can not open an input file: $!";
  print OPT "&basics\n";
  print OPT "filetp=1,minres=5,stranal=1,num_mol=2\n";
  print OPT "/\n";
  print OPT "&geomet\n";
  print OPT "bbaln=1,capri=1,recs=$recs,rece=$rece,ligs=$ligs,lige=$lige\n";
  print OPT "/\n";
  print OPT "&inpout\n";
  print OPT "pdbsave=0,outpdb=0\n";
  print OPT "/\n";
  close (OPT);
  my $wyn=`pr_alchem prm-L_RMS $pdb1 $pdb2`;
  if ($? == -1) {
  print "failed to execute: $!\n";
  }
  elsif ($? & 127) {
    printf "child died with signal %d, %s coredump\n",
    ($? & 127),  ($? & 128) ? 'with' : 'without';
  }
  my @vyn=split(/\s+/,$wyn);
  return $vyn[2];
} 

sub get_contacts{
  my ($f1,$f2,$contact_r,$contact_cutoff)=@_;
  my $rec=$$f1;
  my $lig=$$f2;
  my $radii=$$contact_r;
  my $cutoff=$$contact_cutoff;
  my $cnt_out=$lig.".out";
  my $result=`cmapper $rec $radii $cutoff $lig`;
  if ($? == -1) {print "failed to execute: $!\n";}
  elsif ($? & 127) {printf "child died with signal %d, %s coredump\n",
   ($? & 127),  ($? & 128) ? 'with' : 'without';}
  move("$cnt_out","contacts/$cnt_out");
}
