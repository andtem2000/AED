function [err,insert,delet,subst, events_to_detect]=scorescript(trans_file, hyp_file, outfile)
%scorescript calculates the acoustic events error rate (AEER).
% usage: scorescript(trans_file, hyp_file, outfile)
%   input: 
%   trans_file              - annotation file
%   hyp_file                - hypothesis file
%   outfile                 - (optional) file with final results. If not provided the
%                             results are printed to the screen
%   output: 
%   err                     - AEER
%   insert                  - insertion error      
%   delet                   - deletion error
%   subst                   - substitution error
%   events_to_detect        - number of events to detect
%   The transcription files should be AGTK table format (.csv format) with
%   ',' delimiter
%   The output file example is 
%           AEER=0.276 
%           insertions=0  
%           deletions=4  
%           substitutions=4  
%           events_to_detect=29



subst=0;
delet=0;
insert=0;

%define event labels
%events=['kn','ds','st','cm','cl','pw','kj','kt','pr','ap','co','la','un','sp']; 
events=['kn','ds','st','cm','cl','pw','kj','kt','pr','ap','co','la']; % not scoring speech and unknown
% events=['ap'; 'cl'; 'cm'; 'co'; 'ds'; 'kj'; 'kn'; 'kt'; 'la'; 'pr'; 'pw'; 'st'; 'un'];

%initialization
for i=1:size(events,2)/2
    numevents{i,2}(1)=0;%number of all events - 0
    numevents{i,2}(2)=0;%number of correctly detected - 0
end

[time_in,time_out,lable_id]=textread(trans_file,'%f%f%s%*[^\n]','delimiter',',');
for i=1:size(lable_id,1)
    if strcmp(lable_id{i},'do')|| strcmp(lable_id{i},'dc')
       lable_id{i}='ds';
    end
    if strcmp(lable_id{i},'mp')|| strcmp(lable_id{i},'fo')|| strcmp(lable_id{i},'pv')
       lable_id{i}='un';
    end


    z=findstr(events,lable_id{i});
    if ~isempty(z)
        numevents{(z+1)/2,2}(1)=numevents{(z+1)/2,2}(1)+1; % number of events
        numevents{(z+1)/2,1}(1,numevents{(z+1)/2,2}(1))=0; % e.g [0 0 0 0 1 0 2] 1-corr_detected 2-subst
        numevents{(z+1)/2,1}(2,numevents{(z+1)/2,2}(1))=time_in(i); %start time
        numevents{(z+1)/2,1}(3,numevents{(z+1)/2,2}(1))=time_out(i); % end time
    end
end

% work 

[time_inh,time_outh,lable_idh]=textread(hyp_file,'%f%f%s%*[^\n]','delimiter',','); 
for i=1:size(lable_idh,1) % number of events in hyp_file
    dett_fin=0; %flag of being detected
    dett_cor=0; %flag of being correctly detected
    zz=findstr(events,lable_idh{i}); % event identifier
    if ~isempty(zz) % start time searching in reference file
        for j=[(zz+1)/2 setdiff(1:size(events,2)/2,(zz+1)/2 )] % lookfor the same class first and then for others
            for z=1:numevents{j,2}(1) 
                % number of the j class events in reference file 
                % (the timestamps of each of them have to be examined)
                if mean([time_inh(i) time_outh(i)])>numevents{j,1}(2,z)&mean([time_inh(i) time_outh(i)])<numevents{j,1}(3,z) 
                    % if lies inside of one of reference events
                    % it is marked as detected
                    dett_fin=1;
                    if j==(zz+1)/2 % if it is the same event as hypothesis it is marked as correctly detected
%                         if not(numevents{j,1}(1,z))
%                             numevents{j,2}(2)=numevents{j,2}(2)+1;
%                         end
                        dett_cor=1;
                        numevents{j,1}(1,z)=1;
                    else
                        % substitution
                        numevents{j,1}(1,z)=2;
                    end
                end
            end
%             if dett_cor
%                 break;
%             end
        end
        if ~dett_fin
            insert=insert+1;
%         elseif ~dett_cor
%             subst=subst+1;
        end
    else
        fprintf('\nunknown or score-irrelevant lable %s',lable_idh{i});
    end
end
events_to_detect=0;
for i=1:size(events,2)/2
    events_to_detect=events_to_detect+numevents{i,2}(1);
end
for i=1:size(events,2)/2
%     delet=delet+numevents{i,2}(1)-numevents{i,2}(2);%number of deletions
    subst=subst+size(find(numevents{i,1}(1,:)==2),2);
    delet=delet+numevents{i,2}(1)-size(find(numevents{i,1}(1,:)==2),2)-size(find(numevents{i,1}(1,:)==1),2);
end

err=(delet+insert+subst)/events_to_detect;



%file or/and screen output
if nargin<3
    fprintf('\nOutput filename not provided. Results are output to the screen only\n');
    fprintf('AEER=%2.3f \ninsertions=%d  \ndeletions=%d  \nsubstitutions=%d  \nevents_to_detect=%d', err,insert,delet,subst, events_to_detect);
else
    for i=1:2
        fid=1;
        if i~=1
            [fid,mess]=fopen(outfile,'w');
            if fid==-1
                error(mess);
            end
        end
        fprintf(fid, 'AEER=%2.3f \ninsertions=%d  \ndeletions=%d  \nsubstitutions=%d  \nevents_to_detect=%d', err,insert,delet,subst, events_to_detect);
    end
end
fclose('all');
% events_to_detect=size(lable_id,1);
