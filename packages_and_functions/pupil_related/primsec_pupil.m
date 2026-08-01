
[initialbar,finalbar,playedtr,rewsz,rewtyp,actsz,acttyp,chosen,sizePE,typePE,rewsz_options,rewtyp_options]=gettrialdata2(data);

%get node for feedback on  
node=NaN(size(chosen));
response = NaN(size(chosen));
cashin = zeros(size(chosen));
for k=1:length(data.NEURO.CodeNumbers2)
                
picon = NaN(data.NEURO.NumTrials,1);
    for k = 1:length(data.NEURO.CodeNumbers2)
        trial_error = data.BHV.UserVars(k).TrialError;  % 0 = correct, 6 = incorrect-but-complete
        trial_complete = (trial_error == 0) || (trial_error == 6);

        if ismember(27, data.NEURO.CodeNumbers2{k}) && trial_complete
            idx = find(data.NEURO.CodeNumbers2{k} == 27);
            if length(idx) > 1
                warning('%s, trial %d: code 27 found %d times even after TrialError filter (error=%d). Using first occurrence - flag for Erin.', ...
                    filename, k, length(idx), trial_error);
            end
            picon(k) = data.NEURO.CodeTimes2{k}(idx(1));
        end
    end
end

pupil=NaN(length(node),1000);
for k=1:length(data.NEURO.CodeNumbers2);
    if ~isnan(node(k))
        eyedata = data.BHV.AnalogData{1,k}.General.Gen1;
        clear time;
        for j=1:length(eyedata);
               time(j,1)=2*j;  %for 500Hz acquisition
        end
       %remove blinks
       removeblinks=[];
       x = find(eyedata<=0);
       if ~isempty(x)
           removeblinks(1:10) = [x(1)-10:x(1)-1];
           for j=2:length(x)
               if x(j)==x(j-1)+1
                   removeblinks=[removeblinks x(j)];
               else
                   addon = [x(j-1)+1:x(j-1)+9];
                   removeblinks=[removeblinks addon];
                   addon = [x(j)-10:x(j)-1];
                   removeblinks = [removeblinks addon];
                   removeblinks=[removeblinks x(j)];
               end
           end
           addon =[ x(length(x))+1:x(length(x))+9];
           removeblinks = [removeblinks addon];
           removeblinks(find(removeblinks<=0))=[];
           eyedata(removeblinks) = NaN;
       end
        if ismember(node(k),time)
            ind=find(time==node(k));
        else
            ind=find(time==node(k)+1);
        end
        pupil(k,:) = mean(eyedata(ind-499:ind)); %we are choosing to go 1 second back (-499 bc its in 2ms)
    end
end
    ts = (-999:2:1000);
    
    