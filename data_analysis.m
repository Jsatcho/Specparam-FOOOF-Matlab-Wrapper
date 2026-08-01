data = load('M0101.mat');
data = data.data;

picon = NaN(data.NEURO.NumTrials,1);
%% 
for k = 1:length(data.NEURO.CodeNumbers2)
    if ismember(27,data.NEURO.CodeNumbers2{k})
        picon(k) = data.NEURO.CodeTimes2{k}(find(data.NEURO.CodeNumbers2{k}==27));
    end
end
%%
trials = NaN(length(picon),4000);
for k = 1:length(picon)
    if ~isnan(picon(k))
        trials(k,:) = data.NEURO.LFP.AD03(picon(k)-999:picon(k)+3000);
    end
end
plot(trials(100,:))

%%
rewsz = NaN(length(picon),2);
for k = 1:length(picon)
    rewsz(k,:) = data.BHV.UserVars(k).RewardSize;
end
%%
choicetrial = NaN(length(picon),1);
for k = 1:length(picon)
    choicetrial(k) = data.BHV.UserVars(k).ChoiceTrial;
end
%%
chosen = NaN(length(picon),1);
for k = 1:length(picon)
    chosen(k) = data.BHV.UserVars(k).Chosen;
end
%%
errors = NaN(size(picon));
for k = 1:length(picon)
    errors(k) = data.BHV.UserVars(k).TrialError;
end

%%
chosenrewsz = NaN(length(picon), 1);
for k = 1:length(picon)
    if choicetrial(k)==0 & errors(k)==0 %not choice trial just assign rewsize k
        chosenrewsz(k) = rewsz(k,1);
    elseif choicetrial(k)==1 & errors(k)==0
        chosenrewsz(k) = rewsz(k,chosen(k)); %gives exact choice
    end
end
%% LFP grouped by reward size
rewardsz1 = trials(chosenrewsz == 1,:);
rewardsz2 = trials(chosenrewsz == 2,:);
rewardsz3 = trials(chosenrewsz == 3,:);
rewardsz4 = trials(chosenrewsz == 4,:);
