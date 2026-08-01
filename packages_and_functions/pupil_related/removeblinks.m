trialn=length(BHV.TrialError);
for k=1:trialn
    BHV.Pupil{k}=BHV.AnalogData{1,k}.General.Gen1;
    for j=1:length(BHV.Pupil{k})
        if BHV.Pupil{k}(j,1)>nanmean(BHV.Pupil{k})+2*nanstd(BHV.Pupil{k})
            if j>2
                if j<length(BHV.Pupil{k})-2
                    BHV.Pupil{k}(j-2:j+2,1)=NaN;
                elseif j<length(BHV.Pupil{k})-1
                        BHV.Pupil{k}(j-2:j+1,1)=NaN;
                elseif j==length(BHV.Pupil{k})
                    BHV.Pupil{k}(j-2:j,1)=NaN;
                end
            elseif j>1
                BHV.Pupil{k}(j-1:j+2,1)=NaN;
            elseif j==1
                BHV.Pupil{k}(j:j+2,1)=NaN;
            end
        elseif BHV.Pupil{k}(j,1)<nanmean(BHV.Pupil{k})-2*nanstd(BHV.Pupil{k})
            if j>2
                if j<length(BHV.Pupil{k})-2
                    BHV.Pupil{k}(j-2:j+2,1)=NaN;
                elseif j<length(BHV.Pupil{k})-1
                        BHV.Pupil{k}(j-2:j+1,1)=NaN;
                elseif j==length(BHV.Pupil{k})
                    BHV.Pupil{k}(j-2:j,1)=NaN;
                end
            elseif j>1
                BHV.Pupil{k}(j-1:j+2,1)=NaN;
            elseif j==1
                BHV.Pupil{k}(j:j+2,1)=NaN;
            end
        end
    end
end