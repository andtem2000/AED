function AedAcc(fnameListRef, fnameListHyp)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Author(s): Andriy Temko
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%    History:
%
% Version 2     * Significantly increase the speed of scoring 
% (15/03/07)       
%
% Version 1     * first version of the scoring tool for Acoustic Event 
% (20/01/07)      Detection task within the CLEAR 2007 evaluation campaign 
%                 http://www.clear-evaluation.org). 
% 
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   List of reference files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%fnameListRef = 'aed_iso_ref.lst' ;         % reference input isolated DBs
%fnameListRef = 'aed_dev06_ref.lst' ;       % reference input seminars
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   List of hypothesis files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%fnameListHyp = 'aed_iso_hyp_upc_2006.lst' ;         % reference input isolated DBs
%fnameListHyp = 'aed_iso_hyp_itc_2006.lst' ;         % reference input isolated DBs
%fnameListHyp = 'aed_iso_hyp_cmu_2006.lst' ;         % reference input isolated DBs
%fnameListHyp = 'aed_dev06_hyp.lst' ;            % reference input seminars 2006
%fnameListHyp = 'aed_sem06_hyp_cmu.lst' ;            % reference input seminars 2006
%fnameListHyp = 'aed_sem06_hyp_itc.lst' ;            % reference input seminars 2006
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Hypothesis and reference files in lists must correspond to each other.
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

inDirHyp = 'CLEAR2007\sys1' ; 	% hypothesis directory
inDirRef = 'CLEAR2007\GT\' ;         % reference directory
ListsDir = '' ;% filelists directory

fl_ref   = fopen (strcat(ListsDir, fnameListRef), 'r') ;
fl_hyp   = fopen (strcat(ListsDir, fnameListHyp), 'r') ;

fname_ref    = fgetl(fl_ref) ;
fname_hyp    = fgetl(fl_hyp) ;



fileCount=1 ;
while all((fname_hyp ~= -1)) && all((fname_ref ~= -1))
    fnameDataHyp = strcat(inDirHyp, fname_hyp) ;
    fnameDataRef = strcat(inDirRef, fname_ref) ;
    fprintf(1, '\nScoring hypothesis file (%li) %s\n', fileCount, fnameDataHyp) ;
    [cor_sys(fileCount),cor_ref(fileCount),num_sys(fileCount),num_ref(fileCount)]=aed_acc(fnameDataRef, fnameDataHyp);

    fname_ref    = fgetl(fl_ref) ;
    fname_hyp    = fgetl(fl_hyp) ;
    fileCount    = fileCount + 1 ;
end

fprintf(1,'\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

if all(fname_hyp == -1) && all(fname_ref == -1)
    fprintf(1,'\n!!!!!!!! Scored all %d files !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!', fileCount-1);
else
    fprintf(1,'\n!!!!!!!! Scored just %d files. Check the filelists !!!!!!!!', fileCount-1);
end

fclose all;
% calculate F score
beta      = 1;
precision = sum(cor_sys)/sum(num_sys);
recall    = sum(cor_ref)/sum(num_ref);
f_score   = (1+beta*beta)*precision*recall/(beta*beta*precision+recall);

fprintf(1,'\nAccuracy=%2.3f', f_score);
fprintf(1,'\nPrecision=%2.3f \t(correct system AEs = %d; number system AEs = %d)', precision, sum(cor_sys), sum(num_sys));
fprintf(1,'\nRecall=%2.3f \t(correct reference AEs = %d; number reference AEs = %d)', recall, sum(cor_ref), sum(num_ref));

fprintf(1,'\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
fclose('all');


function [cor_sys,cor_ref,num_sys,num_ref]=aed_acc(fnameDataRef, fnameDataHyp);
%scorescript calculates the AED Accuracy.

cor_sys =  0;
cor_ref =  0;
num_sys =  0;
num_ref =  0;

%define event labels
events=['ap'; 'cl'; 'cm'; 'co'; 'ds'; 'kj'; 'kn'; 'kt'; 'la'; 'pr'; 'pw'; 'st'];


[time_in_r,time_out_r,lable_id_r]=textread(fnameDataRef,'%f%f%s%*[^\n]','delimiter',',');
[time_in_s,time_out_s,lable_id_s]=textread(fnameDataHyp,'%f%f%s%*[^\n]','delimiter',',');
[time_in_s,tmpidx]=sort(time_in_s); time_out_s=time_out_s(tmpidx);lable_id_s=lable_id_s(tmpidx,:);
[time_in_r,tmpidx]=sort(time_in_r); time_out_r=time_out_r(tmpidx);lable_id_r=lable_id_r(tmpidx,:);
flag_sys=zeros(2,size(time_in_s,1)); % if correct - if need to be scored
flag_ref=zeros(2,size(time_in_r,1)); % if correct - if need to be scored

% calculating recall
for i=1:size(lable_id_r,1)
    flag2score=0;
    for j=1:size(events,1)
        if strcmp(events(j,:),lable_id_r{i})
            flag2score=1;
            break;
        end;
    end
    if not(flag2score)
        continue;
    end;
    flag_ref(2,i)=1;
    
    for ii=1:size(lable_id_s,1)
         if time_out_r(i)<time_in_s(ii)
             break;
         end
        if time_in_r(i)>time_out_s(ii)
            continue;
        end
        if (mean([time_in_r(i) time_out_r(i)])> time_in_s(ii) && mean([time_in_r(i) time_out_r(i)])<time_out_s(ii)) ...
                || (mean([time_in_s(ii) time_out_s(ii)])> time_in_r(i) && mean([time_in_s(ii) time_out_s(ii)])<time_out_r(i))
            if strcmp(lable_id_r{i},lable_id_s{ii})
                flag_ref(1,i)=1;
                flag_sys(2,ii)=1;
                flag_sys(1,ii)=1;
            end
        end;
            
    end
end

% calculating precision
for i=1:size(lable_id_s,1)
    flag2score=0;
    for j=1:size(events,1)
        if strcmp(events(j,:),lable_id_s{i})
            flag2score=1;
            break;
        end;
    end
    if not(flag2score) || flag_sys(1,i)
        continue;
    end;
    flag_sys(2,i)=1;
    
    for ii=1:size(lable_id_r,1)
        if time_out_s(i)<time_in_r(ii)
            break;
        end
        if time_in_s(i)>time_out_r(ii)
            continue;
        end
        if (mean([time_in_r(ii) time_out_r(ii)])> time_in_s(i) && mean([time_in_r(ii) time_out_r(ii)])<time_out_s(i)) ...
                || (mean([time_in_s(i) time_out_s(i)])> time_in_r(ii) && mean([time_in_s(i) time_out_s(i)])<time_out_r(ii))
            if strcmp(lable_id_r{ii},lable_id_s{i})
                flag_sys(1,i)=1;
                break;
            end
        end;
            
    end
end

cor_sys=sum(flag_sys(1,:));
cor_ref=sum(flag_ref(1,:));
num_sys=sum(flag_sys(2,:));
num_ref=sum(flag_ref(2,:));
