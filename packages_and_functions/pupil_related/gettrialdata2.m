function [initialbar,finalbar,playedtr,rewsz,rewtyp,actsz,acttyp,chosen,sizePE,typePE,rewsz_options,rewtyp_options]=gettrialdata2(data)

    initialbar=NaN(length(data.NEURO.CodeNumbers2),1);%%
    finalbar=NaN(length(data.NEURO.CodeNumbers2),1);
    playedtr=NaN(length(data.NEURO.CodeNumbers2),1);%%how close monkey is to cashing in reward
    rewsz=NaN(length(data.NEURO.CodeNumbers2),1);
    rewtyp=NaN(length(data.NEURO.CodeNumbers2),1);
    actsz=NaN(length(data.NEURO.CodeNumbers2),1);
    acttyp=NaN(length(data.NEURO.CodeNumbers2),1);
    chosen=NaN(length(data.NEURO.CodeNumbers2),1);
    sizePE=NaN(length(data.NEURO.CodeNumbers2),1);
    typePE=NaN(length(data.NEURO.CodeNumbers2),1);
    rewsz_options=NaN(length(data.NEURO.CodeNumbers2),2);
    rewtyp_options=NaN(length(data.NEURO.CodeNumbers2),2);
    
    for k=1:length(data.NEURO.CodeNumbers2)
        trial_error = data.BHV.UserVars(k).TrialError;  % 0 = correct, 6 = incorrect-but-complete
        trial_complete = (trial_error == 0) || (trial_error == 6);
        

        chosen(k)=data.BHV.UserVars(1,k).Chosen;
        initialbar(k)=data.BHV.UserVars(1,k).InitialBarSz;
        finalbar(k)=data.BHV.UserVars(1,k).FinalBarSz;
        rewsz_options(k,:)=data.BHV.UserVars(1,k).RewardSize;
        rewtyp_options(k,:)=data.BHV.UserVars(1,k).RewardType;
        if ~isempty(data.BHV.UserVars(1,k).ActualOutcomeSize)
        actsz(k)=data.BHV.UserVars(1,k).ActualOutcomeSize;
        acttyp(k)=data.BHV.UserVars(1,k).ActualOutcomeType;
        end
        if ismember(27,data.NEURO.CodeNumbers2{k}) %forced-choice only
            rewtyp(k)=data.BHV.UserVars(1,k).RewardType(1);
            rewsz(k)=data.BHV.UserVars(1,k).RewardSize(1);
        elseif chosen(k)~=0 %free-choice trials
            rewtyp(k)=data.BHV.UserVars(1,k).RewardType(chosen(k));
            rewsz(k)=data.BHV.UserVars(1,k).RewardSize(chosen(k));
        end
        playedtr(k,1)=data.BHV.UserVars(1,k).PlayedTr;
        if playedtr(k)==0
            if k>1
            playedtr(k)=playedtr(k-1);
            end
        end
    end
    sizePE=actsz-rewsz;
    typePE=acttyp-rewtyp;

end