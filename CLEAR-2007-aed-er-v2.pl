#!/usr/bin/perl -w
use strict;

#################################
# Author(s): Andriy Temko
#
#################################
# History:
#
# version 2: * fixed the bug with the "speech" and "unknown" classes scored
#
#
# version 1: * first version of the scoring tool for Acoustic Event Detection
#              task for the CLEAR 2007 evaluation campaign http://www.clear-evaluation.org). 
#              It is based on the version 21 of the NIST Speaker Diarization 
#              tool (md-eval-v21.pl) http://www.nist.gov/speech/tests/rt/rt2007/ 
#              and modifications made by Mikel (md-eval-v21_nueva_mikel.pl) 
#              and Ruben San-Segundo Hernandez (md-eval-v21_nueva.pl) for the Albayzin
#              Evaluations 2006 http://jth2006.unizar.es/.
#
#                
#
#################################

#global data
my $epsilon = 1E-8;
my $miss_name = "  MISS";
my $fa_name = "  FALSE ALARM";

my $usage = "\n\nUsage: $0 -r <ref_file> -s <src_file>\n\n".
    "Description:  aed-eval evaluates Acoustic Event Detection performance\n".
    "      by comparing system data output data with reference data\n".
    "INPUT:\n".
    "  -r <ref-file>  A file containing reference data, in specified format\n\n".
    "  -s <sys-file>  A file containin system output data, in specified format\n\n".
    "  input options:\n".
    "    -a <f> Conditional analysis options for Acoustic Event Detection performance:\n".
    "         f for performance versus file,\n".
    "OUTPUT:\n".
    "  Performance statistics are written to STDOUT.\n".
    "\n";

######
# Intro
my ($date, $time) = date_time_stamp();
print "command line (run on $date at $time):  ", $0, " ", join(" ", @ARGV), "\n";

use vars qw ($opt_r $opt_s);
use vars qw ($opt_a);
use Getopt::Std;
getopts ('r:s:a:');
defined $opt_r or die
    "\nCOMMAND LINE ERROR:  no reference data specified$usage";
defined $opt_s or die
    "\nCOMMAND LINE ERROR:  no system output data specified$usage";
$opt_a = "" unless defined $opt_a;


{
    my (%ref, %sys);

    get_rttm_file (\%ref, $opt_r);
    
    get_rttm_file (\%sys, $opt_s);
        
    evaluate (\%ref, \%sys);
}

#################################

sub get_rttm_file {

    my ($data, $rttm_file, $glm) = @_;
    my ($record, @fields, $data_type, $file, $chnl, $word, @words, $token);

    return unless defined $rttm_file;
    open DATA, $rttm_file or die
	"\nCOMMAND LINE ERROR:  unable to open annotation file '$rttm_file'$usage";
    while ($record = <DATA>) {
	next if $record =~ /^\s*[\#;]|^\s*$/;
	@fields = split /\s+/, $record;
	shift @fields if $fields[0] eq "";
	@fields >= 4 or die
	    ("\n\nFATAL ERROR:  insufficient number of fields in the file '$rttm_file'\n".
	     "    input data record is: '$record'\n\n");
	undef $token;
	$token->{FILE} = $file = shift @fields;
	$token->{TBEG} = lc shift @fields;
	$token->{TBEG} =~ s/\*//;
	$token->{TEND} = lc shift @fields;
	$token->{TEND} =~ s/\*//;
        $token->{TDUR} = $token->{TEND}-$token->{TBEG};
        $token->{TMID} = $token->{TBEG}+$token->{TDUR}/2;
	$token->{TDUR} = 0 if $token->{TDUR} eq "<na>";
	$token->{TDUR} >= -5 or die
	    ("\n\nFATAL ERROR -- negative event duration in file $file,'\n".
	     "    input data record is: '$record'\n\n");
       	$token->{SPKR} = lc shift @fields;
	$token->{SPKR}="" unless defined $token->{SPKR};
        push @{$data->{$file}{SPEAKER}{$token->{SPKR}}}, $token;
        push @{$data->{$file}{RTTM}}, $token;
    }
    close DATA;
}

#################################

sub evaluate {

    my ($ref_data, $sys_data) = @_;
    my ($uem );
    my ($ref_mds, $sys_mds, %scores, $ref_rttm, $sys_rttm);

    foreach my $file (sort keys %$ref_data) {

	    $ref_rttm = $ref_data->{$file}{RTTM};
	    $sys_rttm = $sys_data->{$file}{RTTM};
	    $uem = uem_from_rttm ($ref_rttm) if not defined $uem;
	    $ref_mds = $ref_data->{$file}{SPEAKER};
	    if (defined $ref_mds) {
		$sys_mds = $sys_data->{$file}{SPEAKER};
		$sys_mds = $sys_data->{$file}{SPEAKER} = {} unless defined $sys_mds;
		($scores{SPEAKER}{$file}) = score_speaker_diarization ($file, $ref_mds, $sys_mds, $uem, $ref_rttm);
	    }
    }

#    sd_performance_analysis ($scores{SPEAKER});
    sd_performance_analysis ($scores{SPEAKER});
}


sub score_speaker_diarization {

    my ($file, $ref_spkr_data, $sys_spkr_data, $uem_eval, $rttm_data) = @_;
    my ($uem_score, $ref_eval, $sys_eval, $spkr_overlap, $spkr_map);
    my ($eval_segs, $score_segs, %stats, @ref_wds, $wrd, $ref_spkr, $sys_spkr);
    my ($nref, $nsys, $nmap, $spkr, $seg, $type, $spkr_info, $noscore_nl);

    $eval_segs = create_speaker_segs ($uem_eval, $ref_spkr_data, $sys_spkr_data);
    foreach $seg (@$eval_segs) {
	foreach $ref_spkr (keys %{$seg->{REF}}) {
	    $spkr_info->{REF}{$ref_spkr}{TIME} += $seg->{TDUR};

	}
	foreach $sys_spkr (keys %{$seg->{SYS}}) {
	    $spkr_info->{SYS}{$sys_spkr}{TIME} += $seg->{TDUR};

	}
	next unless keys %{$seg->{REF}} > 0;
	$stats{EVAL_SPEECH} += $seg->{TDUR};
	foreach $ref_spkr (keys %{$seg->{REF}}) {
	    foreach $sys_spkr (keys %{$seg->{SYS}}) {
		$spkr_overlap->{$ref_spkr}{$sys_spkr} += $seg->{TDUR};
	    }
	}
    }

    foreach $seg (@$uem_eval) {
	$stats{EVAL_TIME} += $seg->{TEND}-$seg->{TBEG};
    }


    $score_segs = create_speaker_segs ($uem_eval, $ref_spkr_data, $sys_spkr_data);
    score_speaker_segments (\%stats, $score_segs, $spkr_info);
    return {%stats};
}

#################################

sub score_speaker_segments {

    my ($stats, $score_segs, $spkr_info) = @_;
    my ($ref_spkr, $ref_type, $sys_spkr, $sys_type, %type_stats);
    my (@ref_wds, $wrd, $seg, $seg_dur, $nref, $nsys);

 
    foreach $seg (@$score_segs) {
	$nref = keys %{$seg->{REF}};
	$nsys = keys %{$seg->{SYS}};
        next unless $nref>0 or $nsys>0;
	$seg_dur = $seg->{TDUR};
	$stats->{SCORED_SPEECH} += $nref ? $seg_dur : 0;
	$stats->{SCORED_TIME} += $seg_dur;

        delete $seg->{REF}->{"sp"};
	delete $seg->{SYS}->{"sp"};
	delete $seg->{REF}->{"un"};
	delete $seg->{SYS}->{"un"};
	delete $seg->{REF}->{""};
	delete $seg->{SYS}->{""};
	$nref = keys %{$seg->{REF}};
	$nsys = keys %{$seg->{SYS}};
        next unless $nref>0 or $nsys>0;


	$stats->{MISSED_SPEECH} += ($nref and not $nsys) ? $seg_dur : 0;
	$stats->{FALARM_SPEECH} += ($nsys and not $nref) ? $seg_dur : 0;
	$stats->{SCORED_SPEAKER} += $seg_dur*$nref;
	$stats->{MISSED_SPEAKER} += $seg_dur*max($nref-$nsys,0);
	$stats->{FALARM_SPEAKER} += $seg_dur*max($nsys-$nref,0);


	my $nmap = 0, my %num_types;
	foreach $ref_spkr (keys %{$seg->{REF}}) {

#############################
#	    $sys_spkr = $spkr_map->{$ref_spkr};
#############################

            $sys_spkr = $ref_spkr;
            $nmap++ if defined $sys_spkr and defined $seg->{SYS}{$ref_spkr};
	}

        $stats->{SPEAKER_ERROR} += $seg_dur*(min($nref,$nsys) - $nmap);
    	foreach $sys_spkr (keys %{$seg->{SYS}}) {
	    $sys_type = $spkr_info->{SYS}{$sys_spkr}{TYPE};

	}
	foreach $ref_type (keys %{$num_types{REF}}) {
	    $nref = $num_types{REF}{$ref_type};
	    $type_stats{REF}{$ref_type} += $nref*$seg_dur;
	    foreach $sys_type (keys %{$num_types{SYS}}) {
		$nsys = $num_types{SYS}{$sys_type};
		$type_stats{JOINT}{$ref_type}{$sys_type} += min($nref,$nsys)*$seg_dur;
	    }
	    $type_stats{JOINT}{$ref_type}{$miss_name} += max($nref-$nsys,0)*$seg_dur;
	}
	foreach $sys_type (keys %{$num_types{SYS}}) {
	    $nsys = $num_types{SYS}{$sys_type};
	    $type_stats{SYS}{$sys_type} += $nsys*$seg_dur;
	    $type_stats{JOINT}{$fa_name}{$sys_type} += max($nsys-$nref,0)*$seg_dur;
	}
    }
    $stats->{TYPE}{TIME} = {%type_stats};



}


#################################

sub uem_from_rttm {

    my ($rttm_data) = @_;
    my ($token, $tbeg, $tend);

    ($tbeg, $tend) = (1E30, 0);
    foreach $token (@$rttm_data) {
	($tbeg, $tend) = (min($tbeg,$token->{TBEG}), max($tend,$token->{TEND}))
    }

    return [{TBEG => $tbeg, TEND => $tend}];
}

#################################

sub create_speaker_segs {

    my ($uem_score, $ref_data, $sys_data) = @_;
    my ($spkr, $seg, @events, $event, $uem, $segments, $tbeg, $tend);
    my ($evaluate, %ref_spkrs, %sys_spkrs, $spkrs);

    foreach $uem (@$uem_score) {
	next unless $uem->{TEND} > $uem->{TBEG}+$epsilon;
	push @events, {TYPE => "UEM", EVENT => "BEG", TIME => $uem->{TBEG}};
	push @events, {TYPE => "UEM", EVENT => "END", TIME => $uem->{TEND}};
    }
    foreach $spkr (keys %$ref_data) {
	foreach $seg (@{$ref_data->{$spkr}}) {
	    next unless $seg->{TDUR} > 0;
	    push @events, {TYPE => "REF", SPKR => $spkr, EVENT => "BEG", TIME => $seg->{TBEG}};
	    push @events, {TYPE => "REF", SPKR => $spkr, EVENT => "END", TIME => $seg->{TEND}};
	}
    }
    foreach $spkr (keys %$sys_data) {
	foreach $seg (@{$sys_data->{$spkr}}) {
	    next unless $seg->{TDUR} > 0;
	    push @events, {TYPE => "SYS", SPKR => $spkr, EVENT => "BEG", TIME => $seg->{TBEG}};
	    push @events, {TYPE => "SYS", SPKR => $spkr, EVENT => "END", TIME => $seg->{TEND}};
	}
    }
    @events = sort {($a->{TIME} < $b->{TIME}-$epsilon  ? -1 :
		     ($a->{TIME} > $b->{TIME}+$epsilon ?  1 :
		      ($a->{EVENT} eq "END"        ? -1 : 1)))} @events;
    $evaluate = 0;
    foreach $event (@events) {
	if ($evaluate and $tbeg<$event->{TIME}) {
	    $tend = $event->{TIME};
	    push @$segments, {REF => {%ref_spkrs},
			      SYS => {%sys_spkrs},
			      TBEG => $tbeg,
			      TEND => $tend,
			      TDUR => $tend-$tbeg};
	    $tbeg = $tend;
	}
	if ($event->{TYPE} eq "UEM") {
	    $evaluate = $event->{EVENT} eq "BEG";
	    $tbeg = $event->{TIME} if $evaluate;
	}
	else {
	    $spkrs = $event->{TYPE} eq "REF" ? \%ref_spkrs : \%sys_spkrs;
	    ($event->{EVENT} eq "BEG") ? $spkrs->{$event->{SPKR}}++ : $spkrs->{$event->{SPKR}}--;
#	    $spkrs->{$event->{SPKR}} <= 1 or warn  "WARNING:  the same acoustic event class $event->{SPKR} appears more than once at time $event->{TIME}\n";
	    delete $spkrs->{$event->{SPKR}} unless $spkrs->{$event->{SPKR}};
	}
    }
    return $segments;
}

#################################

sub sd_performance_analysis {

    my ($scores) = @_;
    my ($file, $chnl, $class, $kind, $ref_type, $sys_type);
    my ($xscores, %cum_scores, $count);

#accumulate statistics
    foreach $file (keys %$scores) {
	
	    $xscores = $scores->{$file};
	    foreach $ref_type (keys %$xscores) {
		next if $ref_type eq "TYPE";
		$count = $xscores->{$ref_type};
		$cum_scores{ALL}{$ref_type} += $count;
		$cum_scores{"f=$file"}{$ref_type} += $xscores->{$ref_type} if $opt_a =~ /f/i 
	    }
	    $xscores = $xscores->{TYPE};
	    foreach my $class ("TIME", "NSPK") {
		foreach my $kind ("REF", "SYS") {
		    foreach $ref_type (keys %{$xscores->{$class}{$kind}}) {
			$count = $xscores->{$class}{$kind}{$ref_type};
			$cum_scores{ALL}{TYPE}{$class}{$kind}{$ref_type} += $count;
			$cum_scores{"f=$file"}{TYPE}{$class}{$kind}{$ref_type} += $count if $opt_a =~ /f/i;
		    }
		}
		foreach $ref_type (keys %{$xscores->{$class}{JOINT}}) {
		    foreach $sys_type (keys %{$xscores->{$class}{JOINT}{$ref_type}}) {
			$count = $xscores->{$class}{JOINT}{$ref_type}{$sys_type};
			$cum_scores{ALL}{TYPE}{$class}{JOINT}{$ref_type}{$sys_type} += $count;
			$cum_scores{"f=$file"}{TYPE}{$class}{JOINT}{$ref_type}{$sys_type} += $count if $opt_a =~ /f/i 
		    }
		}
	    }
	
    }

    foreach my $condition (sort keys %cum_scores) {
	print_sd_scores ($condition, $cum_scores{$condition}) if $condition !~ /ALL/;
    }
    print_sd_scores ("ALL", $cum_scores{ALL});
}

#################################

sub print_sd_scores {

    my ($condition, $scores) = @_;

    printf "\n*** Performance analysis for Acoustic Event Detection for $condition ***\n\n";

    printf "    EVAL TIME =%10.2f secs  (total reference time)\n", $scores->{EVAL_TIME};
#    printf "  EVAL SPEECH =%10.2f secs (%5.1f percent of evaluated time) \n", $scores->{EVAL_SPEECH},
#        100*$scores->{EVAL_SPEECH}/$scores->{EVAL_TIME};
    printf "  SCORED TIME =%10.2f secs  (total reference time w/o silence, %5.1f percent of evaluated time)\n",
        $scores->{SCORED_SPEECH}, 100*$scores->{SCORED_SPEECH}/$scores->{EVAL_TIME};
#    printf "SCORED SPEECH =%10.2f secs (%5.1f percent of scored time)\n",
#        $scores->{SCORED_SPEECH}, 100*$scores->{SCORED_SPEECH}/$scores->{SCORED_TIME};
#
    print "---------------------------------------------\n";
#    printf "MISSED SPEECH =%10.2f secs (%5.1f percent of scored time)\n",
#        $scores->{MISSED_SPEECH}, 100*$scores->{MISSED_SPEECH}/$scores->{SCORED_TIME};
#    printf "FALARM SPEECH =%10.2f secs (%5.1f percent of scored time)\n",
#        $scores->{FALARM_SPEECH}, 100*$scores->{FALARM_SPEECH}/$scores->{SCORED_TIME};
#    print "---------------------------------------------\n";
    printf "SCORED ACOUSTIC EVENT TIME =%10.2f secs (%5.1f percent of scored time, may be > 100 due to overlappings)\n",
        $scores->{SCORED_SPEAKER}, 100*$scores->{SCORED_SPEAKER}/$scores->{SCORED_TIME};
    printf "MISSED ACOUSTIC EVENT TIME =%10.2f secs (%5.1f percent of scored acoustic event time)\n",
        $scores->{MISSED_SPEAKER}, 100*$scores->{MISSED_SPEAKER}/$scores->{SCORED_SPEAKER};
    printf "FALARM ACOUSTIC EVENT TIME =%10.2f secs (%5.1f percent of scored acoustic event time)\n",
        $scores->{FALARM_SPEAKER}, 100*$scores->{FALARM_SPEAKER}/$scores->{SCORED_SPEAKER};
    printf "   EVENT SUBSTITUTION TIME =%10.2f secs (%5.1f percent of scored acoustic event time)\n",
        $scores->{SPEAKER_ERROR}, 100*$scores->{SPEAKER_ERROR}/$scores->{SCORED_SPEAKER};
    print "---------------------------------------------\n";
#    if ($condition eq "ALL") {
#      printf " OVERALL SPEAKER DIARIZATION ERROR = %.2f percent of scored speaker time\n",
#         100*($scores->{MISSED_SPEAKER} + $scores->{FALARM_SPEAKER} + $scores->{SPEAKER_ERROR})/
#	    $scores->{SCORED_SPEAKER};
#    } else {
      printf " OVERALL ACOUSTIC EVENT DETECTION ERROR = %.2f percent of scored time  %s\n",
         100*($scores->{MISSED_SPEAKER} + $scores->{FALARM_SPEAKER} + $scores->{SPEAKER_ERROR})/
    	    $scores->{SCORED_SPEAKER}, "`($condition)";
#    }
#    print "---------------------------------------------\n";
#    printf " Speaker type confusion matrix -- speaker weighted\n";
#    summarize_speaker_type_performance ("NSPK", $scores->{TYPE}{NSPK});
#    print "---------------------------------------------\n";
#    printf " Speaker type confusion matrix -- time weighted\n";
#    summarize_speaker_type_performance ("TIME", $scores->{TYPE}{TIME});
#    print "---------------------------------------------\n";
}


#################################

sub date_time_stamp {

    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my ($date, $time);

    $time = sprintf "%2.2d:%2.2d:%2.2d", $hour, $min, $sec;
    $date = sprintf "%4.4s %3.3s %s", 1900+$year, $months[$mon], $mday;
    return ($date, $time);
}

#################################

sub max {

    my ($max, $next);

    return unless defined ($max=pop);
    while (defined ($next=pop)) {
	$max = $next if $next > $max;
    }
    return $max;
}

#################################

sub min {

    my ($min, $next);

    return unless defined ($min=pop);
    while (defined ($next=pop)) {
	$min = $next if $next < $min;
    }
    return $min;
}

#################################
