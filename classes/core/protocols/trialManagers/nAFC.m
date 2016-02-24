classdef nAFC
    
    properties
    end
    
    methods
        function t=nAFC(varargin)
            % NAFC  class constructor.
            % t=nAFC(soundManager,percentCorrectionTrials,rewardManager,
            %         [eyeController],[frameDropCorner],[dropFrames],[displayMethod],[requestPorts],[saveDetailedFramedrops],
            %		  [delayManager],[responseWindowMs],[showText])

            switch nargin
                case 0
                    % if no input arguments, create a default object
                    a=trialManager();
                    t.percentCorrectionTrials=0;
                    t = class(t,'nAFC',a);

                case 1
                    % if single argument of this class type, return it
                    if (isa(varargin{1},'nAFC'))
                        t = varargin{1};
                    else
                        error('Input argument is not a nAFC object')
                    end
                case {3 4 5 6 7 8 9 10 11 12}

                    % percentCorrectionTrials
                    if varargin{2}>=0 && varargin{2}<=1
                        t.percentCorrectionTrials=varargin{2};
                    else
                        error('1 >= percentCorrectionTrials >= 0')
                    end

                    d=sprintf(['n alternative forced choice' ...
                        '\n\t\t\tpercentCorrectionTrials:\t%g'], ...
                        t.percentCorrectionTrials);

                    for i=4:12
                        if i <= nargin
                            args{i}=varargin{i};
                        else
                            args{i}=[];
                        end
                    end

                    % requestPorts
                    if isempty(args{8})
                        args{8}='center'; % default nAFC requestPorts should be 'center'
                    end

                    a=trialManager(varargin{1},varargin{3},args{4},d,args{5},args{6},args{7},args{8},args{9},args{10},args{11},args{12});

                    t = class(t,'nAFC',a);

                otherwise
                    nargin
                    error('Wrong number of input arguments')
            end
        end
        
        function out = checkPorts(tm,targetPorts,distractorPorts)

            if isempty(targetPorts) && isempty(distractorPorts)
                error('targetPorts and distractorPorts cannot both be empty in nAFC');
            end

            out=true;

        end % end function
        
        function out = getPercentCorrectionTrials(tm)
            out = tm.percentCorrectionTrials;
        end

        function out=getRequestRewardSizeULorMS(trialManager)

            out=trialManager.requestRewardSizeULorMS;
        end
        
        function out=getResponsePorts(trialManager,totalPorts)

            out=setdiff(1:totalPorts,getRequestPorts(trialManager,totalPorts)); % old: response ports are all non-request ports
            % 5/4/09 - what if we want nAFC L/R target/distractor, but no request port (using delayManager instead)
            % responsePorts then still needs to only be L/R, not all ports (since request ports is empty)

            enableCenterPortResponseWhenNoRequestPort=false; %nAFC removes the center port
            if ~enableCenterPortResponseWhenNoRequestPort
                if isempty(getRequestPorts(trialManager,totalPorts)) % removes center port if no requestPort defined
                    out(ceil(length(out)/2))=[];
                end
            end
        end
        
        function out=stationOKForTrialManager(t,s)
            if isa(s,'station')
                out = getNumPorts(s)>=3;
            else
                error('need a station object')
            end
        end
        
        function [tm, trialDetails, result, spec, rewardSizeULorMS, requestRewardSizeULorMS, ...
    msPuff, msRewardSound, msPenalty, msPenaltySound, floatprecision, textures, destRect,updateRM] = ...
    updateTrialState(tm, sm, result, spec, ports, lastPorts, ...
    targetPorts, requestPorts, lastRequestPorts, framesInPhase, trialRecords, window, station, ifi, ...
    floatprecision, textures, destRect, ...
    requestRewardDone, punishResponses,compiledRecords,subject)
            % This function is a tm-specific method to update trial state before every flip.
            % Things done here include:
            %   - set trialRecords.correct and trialRecords.result as necessary
            %   - call RM's calcReinforcement as necessary
            %   - update the stimSpec as necessary (with correctStim() and errorStim())
            %   - update the TM's RM if neceesary
            rewardSizeULorMS=0;
            msPuff=0;
            msRewardSound=0;
            msPenalty=0;
            msPenaltySound=0;
            updateRM = false;

            if isfield(trialRecords(end),'trialDetails') && isfield(trialRecords(end).trialDetails,'correct')
                correct=trialRecords(end).trialDetails.correct;
            else
                correct=[];
            end

            % ========================================================
            % if the result is a port vector, and we have not yet assigned correct, then the current result must be the trial response
            % because phased trial logic returns the 'result' from previous phase only if it matches a target/distractor
            % 3/13/09 - we rely on nAFC's phaseify to correctly assign stimSpec.phaseLabel to identify where to check for correctness
            % call parent's updateTrialState() to do the request reward handling and check for 'timeout' flag
            [tm.trialManager, possibleTimeout, result, ~, ~, requestRewardSizeULorMS,updateRM1] = ...
                updateTrialState(tm.trialManager, sm, result, spec, ports, lastPorts, ...
                targetPorts, requestPorts, lastRequestPorts, framesInPhase, trialRecords, window, station, ifi, ...
                floatprecision, textures, destRect, ...
                requestRewardDone, punishResponses,compiledRecords,subject);

            if isempty(possibleTimeout)		
                if ~isempty(result) && ~ischar(result) && isempty(correct) && strcmp(getPhaseLabel(spec),'reinforcement')
                    resp=find(result);
                    if length(resp)==1
                        correct = ismember(resp,targetPorts);
                        if punishResponses % this means we got a response, but we want to punish, not reward
                            correct=0; % we could only get here if we got a response (not by request or anything else), so it should always be correct=0
                        end
                        result = 'nominal';
                    else
                        correct = 0;
                        result = 'multiple ports';
                    end
                end
            else
                correct=possibleTimeout.correct;
            end

            % ========================================================
            phaseType = getPhaseType(spec);
            framesUntilTransition=getFramesUntilTransition(spec);
            % now, if phaseType is 'reinforced', use correct and call updateRewards(tm,correct)
            % this trialManager-specific method should do the following:
            % - call calcReinforcement(RM)
            % - update msRewardOwed/msAirpuffOwed as necessary (depending on correctness and TM class)
            % - call errorStim(SM), correctStim(SM) as necessary and fill in the stimSpec's stimulus field
            updateRM2 = false;
            if ~isempty(phaseType) && strcmp(phaseType,'reinforced') && ~isempty(correct) && framesInPhase==0

                % we only check to do rewards on the first frame of the 'reinforced' phase

                [rm, rewardSizeULorMS, ~, msPenalty, ~, msRewardSound, msPenaltySound, updateRM2] =...
                    calcReinforcement(getReinforcementManager(tm),trialRecords,compiledRecords, []);
                if updateRM2
                    tm=setReinforcementManager(tm,rm);
                end

                if correct
                    msPuff=0;
                    msPenalty=0;
                    msPenaltySound=0;

                    if window>0
                        if isempty(framesUntilTransition)
                            framesUntilTransition = ceil((rewardSizeULorMS/1000)/ifi);
                        end
                        numCorrectFrames=ceil((rewardSizeULorMS/1000)/ifi);

                    elseif strcmp(getDisplayMethod(tm),'LED')
                        if isempty(framesUntilTransition)
                            framesUntilTransition=ceil(getHz(spec)*rewardSizeULorMS/1000);
                        else
                            framesUntilTransition
                            error('LED needs framesUntilTransition empty for reward')
                        end
                        numCorrectFrames=ceil(getHz(spec)*rewardSizeULorMS/1000);
                    else
                        error('huh?')
                    end
                    spec=setFramesUntilTransition(spec,framesUntilTransition);
                    [cStim, correctScale] = correctStim(sm,numCorrectFrames);
                    spec=setScaleFactor(spec,correctScale);
                    strategy='noCache';
                    if window>0
                        [floatprecision, cStim] = determineColorPrecision(tm, cStim, strategy);
                        textures = cacheTextures(tm,strategy,cStim,window,floatprecision);
                        destRect = determineDestRect(tm, window, station, correctScale, cStim, strategy);
                    elseif strcmp(getDisplayMethod(tm),'LED')
                        floatprecision=[];
                    else
                        error('huh?')
                    end
                    spec=setStim(spec,cStim);
                else
                    rewardSizeULorMS=0;
                    msRewardSound=0;
                    msPuff=0; % for now, we don't want airpuffs to be automatic punishment, right?

                    if window>0
                        if isempty(framesUntilTransition)
                            framesUntilTransition = ceil((msPenalty/1000)/ifi);
                        end
                        numErrorFrames=ceil((msPenalty/1000)/ifi);

                    elseif strcmp(getDisplayMethod(tm),'LED')
                        if isempty(framesUntilTransition)
                            framesUntilTransition=ceil(getHz(spec)*msPenalty/1000);
                        else
                            framesUntilTransition
                            error('LED needs framesUntilTransition empty for reward')
                        end
                        numErrorFrames=ceil(getHz(spec)*msPenalty/1000);
                    else
                        error('huh?')
                    end
                    spec=setFramesUntilTransition(spec,framesUntilTransition);
                    [eStim, errorScale] = errorStim(sm,numErrorFrames);
                    spec=setScaleFactor(spec,errorScale);
                    strategy='noCache';
                    if window>0
                        [floatprecision, eStim] = determineColorPrecision(tm, eStim, strategy);
                        textures = cacheTextures(tm,strategy,eStim,window,floatprecision);
                        destRect=Screen('Rect',window);
                    elseif strcmp(getDisplayMethod(tm),'LED')
                        floatprecision=[];
                    else
                        error('huh?')
                    end
                    spec=setStim(spec,eStim);
                end

            end % end reward handling

            trialDetails.correct=correct;
            updateRM = updateRM1 || updateRM2;

        end  % end function
        
    end
    
end
