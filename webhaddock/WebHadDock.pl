#!/usr/bin/perl
use strict;
use LWP;
use URI;
use LWP::Simple;

my $browser = LWP::UserAgent->new;

if ($#ARGV != 7) {die "Program requires parameters! [pdbid1] [chid1] [acti1] [pdbid2] [chid2] [acti2] [user name] [password] or \n";}
  
my $pdbid1 = $ARGV[0];
my $chid1 = $ARGV[1];
my $actives1 = $ARGV[2];
my $pdbid2 = $ARGV[3];
my $chid2 = $ARGV[4];
my $actives2 = $ARGV[5];
my $name = $ARGV[6];
my $pass = $ARGV[7];

#open(INP,"<$list") or die "can't open ", $list;
#@files=<INP>;
#close(INP);
my $file = "webhaddock.out";
open(OUT,">$file") or die "can't open ", $file;
#my $dir= getcwd();

#unless (-e $pdb){
#	die "File: $pdb not found\n";
#}
my $URL = "http://haddock.science.uu.nl/cgi/services/HADDOCK/haddockserver-prediction.cgi";
my $response = $browser->post( $URL,
#[ 'p1_pdb_mode' => 'download',
[ 'p1_pdb_mode' => 'submit',
  'p1_pdb_chain' => $chid1,	 
#  'p1_pdb_code' => $pdbid1,
  'p1_pdb_pdbfile' => $pdbid1,
  'p1_r_activereslist' => $actives1,
  'p1_r_auto_passive' => 'on',	
  'p1_moleculetype' => 'Protein', 
 # 'p2_pdb_mode' => 'download',
  'p2_pdb_mode' => 'submit',
  'p2_pdb_chain' => $chid2,	 
  #'p2_pdb_code' => $pdbid2,
  'p2_pdb_pdbfile' => $pdbid2,
  'p2_r_activereslist' => $actives2,
  'p2_r_auto_passive' => 'on',	
  'p2_moleculetype' => 'Protein', 
  'username' => $name,
  'password' => $pass,
  'submit' => 'Submit Query'
],
'Content_Type' => 'form-data',
);
	
die "$URL error: ", $response->status_line
unless $response->is_success;
#unless( $response->content =~ m{"7076268343/run"\d}) {
#	die "Couldn't find the match-string in the response\n";
#}
print $response->content;

#my $wynurl="http://metapocket.eml.org/upload/".$1."/output.html";
#print OUT "$wynurl\n";
#sleep 120;	
#getprint($wynurl);
	
#echo 1 | perl grabit.pl lista`

