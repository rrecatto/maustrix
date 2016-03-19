classdef parameterThresholdCriterion<criterion
    %UNTITLED4 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        parameterLocation='';
        operator='';
        threshold=0;
    end
    
    methods
        function s=parameterThresholdCriterion(parameterLocation,operator,threshold)
            % RATECRITERION  class constructor.  
            % s=parameterThresholdCriterion(parameterLocation,operator,threshold)
            % s=parameterThresholdCriterion('.stimDetails.targetContrast','<',0.1)
            % s=parameterThresholdCriterion('.stimDetails.flankerContrast','==',1)
            s=s@criterion();

            if strcmp(class(parameterLocation),'char')
                s.parameterLocation=parameterLocation;
            else
                error('parameterLocation must be a char that is the path to the parameter in the trialrecords')
            end

            if any(strcmp(operator,{'<','>','>=','<=','=='}))
                s.operator=operator;
            else
                error('threshold must be ''<'' ''>'' ''>='' ''<='' or ''=='' ')
            end

            if isnumeric(threshold) & all(size(threshold==1))
                s.threshold=threshold;
            else
                error('threshold must a single number')
            end

        end
        
        function [graduate, details] = checkCriterion(c,subject,trainingStep,trialRecords, compiledRecords)

            %determine what type trialRecord are
            recordType='largeData'; %circularBuffer

            graduate=0;
            if ~isempty(trialRecords)
                %get the correct vector
                switch recordType
                    case 'largeData'
                        command=sprintf('parameterValue=trialRecords(end)%s',c.parameterLocation);
                    case 'circularBuffer'
                        error('not written yet');
                    otherwise
                        error('unknown trialRecords type')
                end

                %eval the comand that gets the parameter value
                try
                    eval(command);
                catch ex
                    disp(['CAUGHT ERROR: ' getReport(ex,'extended')])
                    disp(command);
                    error('bad command in check criterion')
                end

                %check the parameter based on thresh and operator
                switch c.operator
                    case '>'
                        if parameterValue > c.threshold
                            graduate=1;
                        end
                    case '>='
                        if parameterValue >= c.threshold
                            graduate=1;
                        end
                    case '<'
                        if parameterValue < c.threshold
                            graduate=1;
                        end
                    case '<='
                        if parameterValue <= c.threshold
                            graduate=1;
                        end
                    case '=='
                        error('pmm doesn''t trust the equality, as one seems to find what you think is equal is not, don''t know why, not debugged')%080207
                        if parameterValue == c.threshold
                            graduate=1;
                        end
                    otherwise
                        error('what the?')
                end
            end


            %play graduation tone

            if graduate
                beep;
                pause(.2);
                beep;
                pause(.2);
                beep;
                pause(1);
                [junk stepNum]=getProtocolAndStep(subject);
                for i=1:stepNum+1
                    beep;
                    pause(.4);
                end
                if (nargout > 1)
                    details.date = now;
                    details.criteria = c;
                    details.graduatedFrom = stepNum;
                    details.allowedGraduationTo = stepNum + 1;
                    details.parameterValue = parameterValue;
                end
            end
        end
        
        function d=display(s)
            d=[];
            %['rate criterion (trialsPerMin: ' num2str(s.trialsPerMin) ' consecutiveMins: ' num2str(s.consecutiveMins) ')'];
        end
        
        
        function s=rateCriterion(varargin)
            % RATECRITERION  class constructor.  
            % s=rateCriterion(trialsPerMin,consecutiveMins)

            switch nargin
                case 0
                    % if no input arguments, create a default object
                    s.trialsPerMin=0;
                    s.consecutiveMins=0;
                    
                case 1
                    % if single argument of this class type, return it
                    if (isa(parameterLocation,'rateCriterion'))
                        s = parameterLocation;
                    else
                        error('Input argument is not a rateCriterion object')
                    end
                case 2
                    if parameterLocation>=0 && operator>=0
                        s.trialsPerMin=parameterLocation;
                        s.consecutiveMins=operator;
                    else
                        error('trialsPerMin and consecutiveMins must be >= 0')
                    end
                    
                otherwise
                    error('Wrong number of input arguments')
            end
        end
  
        
    end
    
end

