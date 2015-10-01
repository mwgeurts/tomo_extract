function planData = LoadPlan(path, name, planUID, varargin)
% LoadPlan loads the delivery plan from a specified TomoTherapy patient 
% archive and plan trial UID.  This data can be used to perform dose 
% calculation via CalcDose. This function has currently been validated 
% for version 3.X, 4.X and 5.X archives.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%   planUID: UID of the plan
%   varargin: optional flags, such as 'noerrormsg' 
%
% The following variables are returned upon succesful completion:
%   planData: delivery plan data including scale, tau, lower leaf index,
%       number of projections, number of leaves, sync/unsync actions, 
%       leaf sinogram, isocenter, and planTrialUID
%
% Below is an example of how this function is used:
%
%   path = '/path/to/archive/';
%   name = 'Anon_0001_patient.xml';
%   planUID = '1.2.826.0.1.3680043.2.200.1688035198.217.40463.657';
%   plan = LoadPlan(path, name, planUID);
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2015 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

% Execute in try/catch statement
try  
    
% Log start of plan load and start timer
if exist('Event', 'file') == 2
    Event(sprintf(['Extracting delivery plan from %s for plan ', ...
        'UID %s'], name, planUID));
    tic;
end

% Return input variables in the return variable planData
planData.xmlPath = path;
planData.xmlName = name;
planData.planUID = planUID;

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
if exist('Event', 'file') == 2
    Event('Loading file contents data using xmlread');
end
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

%% Load patient demographics
% Search for patient XML object patientName
expression = ...
    xpath.compile('//FullPatient/patient/briefPatient/patientName');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% If patient name was found
if nodeList.getLength > 0

    % Store the first returned value
    subnode = nodeList.item(0);
    
    % Set patient name
    planData.patientName = char(subnode.getFirstChild.getNodeValue);
else

    % Otherwise, warn the user that patient info wasn't found
    if exist('Event', 'file') == 2
        Event(['Patient demographics could not be found. It is possible ', ...
            'this is not a valid patient archive.'], 'ERROR');
    else
        error(['Patient demographics could not be found. It is possible ', ...
            'this is not a valid patient archive.']);
    end
end

% Search for patient XML object patientID
expression = ...
    xpath.compile('//FullPatient/patient/briefPatient/patientID');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% If a patient ID was found
if nodeList.getLength > 0

    % Store the first returned value
    subnode = nodeList.item(0);
    
    % Set patient ID
    planData.patientID = char(subnode.getFirstChild.getNodeValue);
end

% Search for patient XML object patientBirthDate
expression = ...
    xpath.compile('//FullPatient/patient/briefPatient/patientBirthDate');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% If a birthdate was found
if nodeList.getLength > 0

    % Store the first returned value
    subnode = nodeList.item(0);
    
    % If birthdate is not empty
    if ~isempty(subnode.getFirstChild)
        
        % Set patient birth date
        planData.patientBirthDate = ...
            char(subnode.getFirstChild.getNodeValue);
    end
end

% Search for patient XML object patientGender
expression = ...
    xpath.compile('//FullPatient/patient/briefPatient/patientGender');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% If a gender was found
if nodeList.getLength > 0

    % Store the first returned value
    subnode = nodeList.item(0);
    
    % Set patient sex
    planData.patientSex = char(subnode.getFirstChild.getNodeValue);
end

%% Load Plan Trial UID
% Search for treatment plans
expression = ...
    xpath.compile('//fullPlanDataArray/fullPlanDataArray/plan/briefPlan');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    
    % Retrieve a handle to this delivery plan
    node = nodeList.item(i-1);

    %% Verify UID
    % Search for plan database UID
    subexpression = xpath.compile('dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % If the plan database UID does not match the plan's UID, this delivery 
    % plan is associated with a different plan, so continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            planData.planUID) == 0
        continue
    end
    
    %% Store plan trial UID
    % Search for approved plan trial UID
    subexpression = xpath.compile('approvedPlanTrialUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % If plan trial UID is empty, continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            '* * * DO NOT CHANGE THIS STRING VALUE * * *')
        continue
    end
    
    % Store the plan trial UID
    planData.planTrialUID = char(subnode.getFirstChild.getNodeValue);
    
    %% Store plan label
    % Search for plan label
    subexpression = xpath.compile('planLabel');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan label
    planData.planLabel = char(subnode.getFirstChild.getNodeValue);
    
    %% Load patient position
    % Search for procedure XML object patientPosition
    subexpression = xpath.compile('patientPosition');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a patient position was found
    if subnodeList.getLength > 0
        
        % Store the first returned value
        subnode = subnodeList.item(0);

        % Save patient position to return structure as char array
        planData.position = ...
            char(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store plan date/time
    % Search for plan modification date
    subexpression = xpath.compile('modificationTimestamp/date');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan date
    d = char(subnode.getFirstChild.getNodeValue);
    
    % Search for plan modification time
    subexpression = xpath.compile('modificationTimestamp/time');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan time
    t = char(subnode.getFirstChild.getNodeValue);
    
    % Store the date and time as a timestamp
    planData.timestamp = datenum([d,'-',t], 'yyyymmdd-HHMMSS');
    
    %% Store plan type
    % Search for plan delivery type
    subexpression = xpath.compile('planDeliveryType');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan delivery type
    planData.planType = char(subnode.getFirstChild.getNodeValue);
    
    %% Store approver
    % Search for approvingUserName
    subexpression = xpath.compile('approvingUserName');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a result was retrieved
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the approvingUserName
        planData.approver = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Stop searching, as the plan trial UID was found
    break;
end

% If no plan trial UID was found, stop
if ~isfield(planData, 'planTrialUID')
    if ismember('noerrormsg', varargin)
        return
    elseif exist('Event', 'file') == 2 
        Event(sprintf(['An approved plan trial UID for plan UID %s was ', ...
            'not found in %s'], planUID, name), 'ERROR');
    else
        error(['An approved plan trial UID for plan UID %s was ', ...
            'not found in %s'], planUID, name);
    end
end

%% Search for optimization result
if exist('Event', 'file') == 2
    Event('Searching for optimization result');
end

% Search for fluence delivery plan associated with the plan trial
expression = xpath.compile(['//fullPlanTrialArray/fullPlanTrialArray/', ...
    'optimizationResult']);

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the optimizationResults
for i = 1:nodeList.getLength
    
    % Retrieve a handle to this optimization result
    node = nodeList.item(i-1);

    %% Verify parent UID
    % Search for optimization result parent UID
    subexpression = xpath.compile('dbInfo/databaseParent');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database parent was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % If the optimization result databaseParent UID does not match the plan
    % trial's UID, this optimization result is associated with a different
    % plan, so continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            planData.planTrialUID) == 0
        continue
    end
    
    %% Verify optimization result is current
    % Search for current flag
    subexpression = xpath.compile('isFluenceDeliveryPlanCurrent');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no current flag was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % If the optimization result is not current, continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), 'true') == 0
        continue
    end
    
    %% Store fluence UID
    % Search for fluence delivery plan UID
    subexpression = xpath.compile('fluenceDeliveryPlanUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the fluence delivery plan UID
    planData.fluenceUID = char(subnode.getFirstChild.getNodeValue);
    
    % Search for iteration number
    subexpression = xpath.compile('iterationNumber');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no iteration number was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the iteration number
    planData.iterations = char(subnode.getFirstChild.getNodeValue);
    
    % Stop searching, as the fluence plan UID was found
    break;
end

% If not plan trial UID was found, stop
if ~isfield(planData, 'fluenceUID')
    if ismember('noerrormsg', varargin)
        return
    elseif exist('Event', 'file') == 2
        Event(sprintf(['A current fluence delivery plan for plan UID %s ', ...
            'was not found in %s'], planUID, name), 'ERROR');
    else
        error(['A current fluence delivery plan for plan UID %s was ', ...
            'not found in %s'], planUID, name);
    end
end

%% Search for plan section list
if exist('Event', 'file') == 2
    Event('Searching for plan section list');
end

% Search for delivery review associated with the plan
expression = xpath.compile(['//fullPlanTrialArray/fullPlanTrialArray/', ...
    'planSectionList/planSectionList']);

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the planSectionLists
for i = 1:nodeList.getLength
    
    % Retrieve a handle to this planSectionList
    node = nodeList.item(i-1);

    %% Verify plan section parent UID
    % Search for plan section parent UID
    subexpression = xpath.compile('dbInfo/databaseParent');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database parent was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % If the planSectionList databaseParent UID does not match this plan's
    % trial UID, this planSectionList is associated with a different plan,
    % so continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            planData.planTrialUID) == 0
        continue
    end
    
    %% Store jaw positions
    % Search for front jaw
    subexpression = ...
        xpath.compile('intendedJawFieldSpec/jawWidth/frontJaw');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a front jaw was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the front jaw
        planData.frontJaw = str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for back jaw
    subexpression = ...
        xpath.compile('intendedJawFieldSpec/jawWidth/backJaw');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a back jaw was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the back jaw
        planData.backJaw = str2double(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store field positions
    % Search for front field
    subexpression = ...
        xpath.compile('intendedJawFieldSpec/fieldSize/frontField');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a front field was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the front field
        planData.frontField = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for back field
    subexpression = ...
        xpath.compile('intendedJawFieldSpec/fieldSize/backField');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a back field was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the back field
        planData.backField = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store pitch
    % Search for pitch
    subexpression = ...
        xpath.compile('planSectionDetail/helicalSection/pitch');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a pitch was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the pitch
        planData.pitch = str2double(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store TomoDirect angles
    % Search for beam angles
    subexpression = xpath.compile(['planSectionDetail/fixedAngleSection/', ...
        'beamAngleList/beamAngleList']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If beam angles were found
    if subnodeList.getLength > 0
        
        % Initialize beam angles cell array
        planData.beamAngles = cell(subnodeList.getLength, 1);
        
        % Loop through beam angles
        for j = 1:subnodeList.getLength
            
            % Retrieve a handle to this result
            subnode = subnodeList.item(j-1);

            % Search for the name of this beam angle
            subsubexpression = xpath.compile('name');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the name value to the beam angles cell array
            planData.beamAngles{j}.name = ...
                char(subsubnode.getFirstChild.getNodeValue);
            
            % Search for the angle of this beam angle
            subsubexpression = xpath.compile('angle');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the angle value to the beam angles cell array
            planData.beamAngles{j}.angle = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
            
            % Search for the positive flash of this beam angle
            subsubexpression = xpath.compile('positiveFlash');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the positive flash value to the beam angles cell array
            planData.beamAngles{j}.positiveFlash = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
            
            % Search for the negative flash of this beam angle
            subsubexpression = xpath.compile('negativeFlash');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the negative flash value to the beam angles cell array
            planData.beamAngles{j}.negativeFlash = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
            
        end
    end
    
    % Stop searching, as the plan section was found
    break;
end

%% Search for patient plan trial
if exist('Event', 'file') == 2
    Event('Searching for patient plan trial');
end

% Search for fluence delivery plan associated with the plan trial
expression = xpath.compile(['//fullPlanTrialArray/fullPlanTrialArray/', ...
    'patientPlanTrial']);

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the patientPlanTrials
for i = 1:nodeList.getLength
    
    % Retrieve a handle to this patientPlanTrial
    node = nodeList.item(i-1);

    %% Verify optimization result UID
    % Search for optimization result parent UID
    subexpression = xpath.compile('dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % If the patientPlanTrial database UID does not match the plan
    % trial's UID, this patientPlanTrial is associated with a different
    % plan, so continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            planData.planTrialUID) == 0
        continue
    end
    
    %% Store number of fractions
    % Search for desiredFractionCount
    subexpression = xpath.compile('desiredFractionCount');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If the desiredFractionCount was found
    if subnodeList.getLength > 0

        % Retrieve a handle to the results
        subnode = subnodeList.item(0);
    
        % Store the desiredFractionCount
        planData.fractions = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store laser positions
    % Search for X laser position
    subexpression = xpath.compile('movableLaserPosition/x');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a laser position was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the laser position
        planData.movableLaser(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for Y laser position
    subexpression = xpath.compile('movableLaserPosition/y');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a laser position was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the laser position
        planData.movableLaser(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for X laser position
    subexpression = xpath.compile('movableLaserPosition/z');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a laser position was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the laser position
        planData.movableLaser(3) = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store calc grids
    % Search for optimization dose calculation grid
    subexpression = xpath.compile('optimizationDoseGrid');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a calc grid was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the calc grid
        planData.optimizationCalcGrid = ...
            char(subnode.getFirstChild.getNodeValue);
    end
   
    % Search for final dose calculation grid
    subexpression = xpath.compile('finalDoseCalculationGrid');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a calc grid was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the calc grid
        planData.calcGrid = ...
            char(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store prescription
    % Search for prescription type
    subexpression = xpath.compile('prescription/prescriptionType');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a prescribed dose was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the prescribed type
        planData.rxType = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for prescribed dose
    subexpression = xpath.compile('prescription/prescribedDose');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a prescribed dose was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the prescribed dose
        planData.rxDose = str2double(subnode.getFirstChild.getNodeValue);
    end
    
     % Search for prescribed volume
    subexpression = xpath.compile('prescription/volumePercentage');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a prescribed volume was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the prescribed volume
        planData.rxVolume = str2double(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store modulation factor
    % Search for modulation factor
    subexpression = xpath.compile('planningModulationFactor');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a modulation factor was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the modulation factor
        planData.modFactor = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    
    % Stop searching, as the plan trial was found
    break;
end

%% Search for delivery review
if exist('Event', 'file') == 2
    Event('Searching for delivery review');
end

% Search for delivery review associated with the plan
expression = xpath.compile(['//fullDeliveryReviewDataArray/', ...
    'fullDeliveryReviewDataArray']);

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the fullDeliveryReviewDataArrays
for i = 1:nodeList.getLength
    
    % Retrieve a handle to this delivery review
    node = nodeList.item(i-1);

    %% Verify delivery review parent UID
    % Search for delivery review parent UID
    subexpression = xpath.compile('deliveryReview/dbInfo/databaseParent');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database parent was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % If the delivery review databaseParent UID does not match the plan
    % UID, this delivery review is associated with a different plan, so 
    % continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), planUID) == 0
        continue
    end
    
    %% Store machine name
    % Search for machine name
    subexpression = xpath.compile('deliveryReview/machineName');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If the machine name was found
    if subnodeList.getLength > 0

        % Retrieve a handle to the results
        subnode = subnodeList.item(0);
    
        % Store the machine name
        planData.machine = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for machine UID
    subexpression = xpath.compile('deliveryReview/machineUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If the machine UID was found
    if subnodeList.getLength > 0

        % Retrieve a handle to the results
        subnode = subnodeList.item(0);
    
        % Store the machine UID
        planData.machineUID = char(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store JAM/AOM/Cal UIDs
    % Search for JAM UID
    subexpression = xpath.compile('deliveryReview/jamUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If the JAM was found
    if subnodeList.getLength > 0

        % Retrieve a handle to the results
        subnode = subnodeList.item(0);
    
        % Store the JAM
        planData.jamUID = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for AOM UID
    subexpression = xpath.compile('deliveryReview/aomUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If the AOM was found
    if subnodeList.getLength > 0

        % Retrieve a handle to the results
        subnode = subnodeList.item(0);
    
        % Store the AOM
        planData.aomUID = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for calibration UID
    subexpression = xpath.compile('deliveryReview/calibrationUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If the calibration was found
    if subnodeList.getLength > 0

        % Retrieve a handle to the results
        subnode = subnodeList.item(0);
    
        % Store the calibration
        planData.calibrationUID = char(subnode.getFirstChild.getNodeValue);
    end
    
    %% Store machine specific delivery plan UID
    % Search for number of machine specific procedure UID
    subexpression = xpath.compile(['fullFractionApprovalDataArray/fullFra', ...
        'ctionApprovalDataArray/fractionApproval/procDeliveryPlanUID']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If the procedure was found
    if subnodeList.getLength > 0

        % Retrieve a handle to the results
        subnode = subnodeList.item(0);
    
        % Store first specific delivery plan UID (note, this assumes that
        % all delivery plans are identical)
        planData.specificUID = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Stop searching, as the fluence plan UID was found
    break;
end

%% Load Fluence Delivery Plan
if exist('Event', 'file') == 2
    Event('Searching for fluence delivery plan');
end

% Search for fluence delivery plan associated with the plan trial
expression = ...
    xpath.compile('//fullDeliveryPlanDataArray/fullDeliveryPlanDataArray');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    
    % Retrieve a handle to this delivery plan
    node = nodeList.item(i-1);

    %% Verify delivery plan UID
    % Search for delivery plan UID
    subexpression = xpath.compile('deliveryPlan/dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end

    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);

    % If the delivery database UID does not match the current optimization 
    % result plan UID, this delivery plan is associated with a different
    % plan, so continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            planData.fluenceUID) == 0
        continue
    end

    %% Verify this is a fluence delivery plan
    % Search for delivery plan purpose
    subexpression = xpath.compile('deliveryPlan/purpose');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no purpose was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end

    % Otherwise, retrieve a handle to the purpose search result
    subnode = subnodeList.item(0);

    % If the delivery plan purpose is not Fluence, continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), 'Fluence') == 0
        continue
    end

    %% Load delivery plan scale
    % At this point, this delivery plan is the Fluence delivery plan
    % for this plan trial, so continue to search for information about
    % the fluence/optimized plan

    % Search for delivery plan scale
    subexpression = xpath.compile('deliveryPlan/scale');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the plan scale value to the planData structure
    planData.scale = str2double(subnode.getFirstChild.getNodeValue);

    %% Load delivery plan total tau
    % Search for delivery plan total tau
    subexpression = xpath.compile('deliveryPlan/totalTau');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the total tau value
    planData.totalTau = str2double(subnode.getFirstChild.getNodeValue);

    %% Load lower lead index
    % Search for delivery plan lower leaf index
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/lowerLeafIndex');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the lower leaf index value
    planData.lowerLeafIndex = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load number of projections
    % Search for delivery plan number of projections
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfProjections');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the number of projections value
    planData.numberOfProjections = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load number of leaves
    % Search for delivery plan number of leaves
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfLeaves');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the number of leaves value
    planData.numberOfLeaves = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load gantry angle
    % Search for delivery plan gantry start angle
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/gantryPosition', ...
        '/angleDegrees']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a gantryPosition unsync action exists
    if subnodeList.getLength > 0
        
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the gantry start angle to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'gantryAngle';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    %% Load jaw front positions
    % Search for delivery plan front position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/jawPosition/', ...
        'frontPosition']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a jaw front unsync action exists
    if subnodeList.getLength > 0
        
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the jaw front position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'jawFront';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    %% Load jaw back positions
    % Search for delivery plan back position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/jawPosition/', ...
        'backPosition']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a jaw back unsync action exists
    if subnodeList.getLength > 0
        
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the jaw back position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'jawBack';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    %% Load x positions
    % Search for delivery plan isocenter x position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/', ...
        'isocenterPosition/xPosition']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If an isocenter x position unsync action exists
    if subnodeList.getLength > 0
        
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the isocenter x position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'isoX';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
        
        % Store isocenter as array as well
        planData.isocenter(1) = planData.events{k,3};
    end

    %% Load isocenter y positions
    % Search for delivery plan isocenter y position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/', ...
        'isocenterPosition/yPosition']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If an isocenter y position unsync action exists
    if subnodeList.getLength > 0
        
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the isocenter y position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'isoY';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
        
        % Store isocenter as array as well
        planData.isocenter(2) = planData.events{k,3};
    end

    %% Load isocenter z positions
    % Search for delivery plan isocenter z position
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'unsynchronizeActions/unsynchronizeActions/', ...
        'isocenterPosition/zPosition']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If an isocenter z position unsync action exists
    if subnodeList.getLength > 0
        
        % Retreieve a handle to the search result
        subnode = subnodeList.item(0);

        % If the planData structure events cell array already exists
        if isfield(planData, 'events')
            
            % Set k to the next index
            k = size(planData.events, 1) + 1;
        else
            % Otherwise events does not yet exist, so start with 1
            k = 1;
        end

        % Store the isocenter z position to the events cell array.  The
        % first cell is tau, the second is type, and the third is the
        % value.
        planData.events{k,1} = 0;
        planData.events{k,2} = 'isoZ';
        planData.events{k,3} = ...
            str2double(subnode.getFirstChild.getNodeValue);
        
        % Store isocenter as array as well
        planData.isocenter(3) = planData.events{k,3};
    end

    %% Load delivery plan gantry velocity
    % Search for delivery plan gantry velocity
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'synchronizeActions/synchronizeActions/gantryVelocity']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If one or more gantry velocity sync actions exist
    if subnodeList.getLength > 0
        
        % Loop through the search results
        for j = 1:subnodeList.getLength
            
            % Retrieve a handle to this result
            subnode = subnodeList.item(j-1);

             % If the planData structure events cell array already exists
            if isfield(planData, 'events')
                
                % Set k to the next index
                k = size(planData.events, 1) + 1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end

            % Search for the tau of this sync event
            subsubexpression = xpath.compile('tau');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the tau value to the events cell array
            planData.events{k,1} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Store the type to gantryRate
            planData.events{k,2} = 'gantryRate';

            % Search for the value of this sync event
            subsubexpression = xpath.compile('velocity');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the value of this sync event
            planData.events{k,3} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
        end
    end

    %% Load jaw velocities
    % Search for delivery plan jaw velocities
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'synchronizeActions/synchronizeActions/jawVelocity']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If one or more jaw velocity sync actions exist
    if subnodeList.getLength > 0
        
        % Loop through the search results
        for j = 1:subnodeList.getLength
            
            % Retrieve a handle to this result
            subnode = subnodeList.item(j-1);

             % If the planData structure events cell array already exists
            if isfield(planData, 'events')
                
                % Set k to the next index
                k = size(planData.events, 1) + 1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end

            % Search for the tau of this sync event
            subsubexpression = xpath.compile('tau');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the next and subsequent event cell array tau values
            planData.events{k,1} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
            planData.events{k+1,1} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Store the next and subsequent types to jaw front and back 
            % rates, respectively
            planData.events{k,2} = 'jawFrontRate';
            planData.events{k+1,2} = 'jawBackRate';

            % Search for the front velocity value
            subsubexpression = xpath.compile('frontVelocity');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the front velocity value
            planData.events{k,3} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for the back velocity value
            subsubexpression = xpath.compile('backVelocity');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the back velocity value
            planData.events{k+1,3} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
        end
    end

    %% Load couch velocities
    % Search for delivery plan isocenter velocities (i.e. couch velocity)
    subexpression = xpath.compile(['deliveryPlan/states/states/', ...
        'synchronizeActions/synchronizeActions/isocenterVelocity']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If one or more couch velocity sync actions exist
    if subnodeList.getLength > 0
        
        % Loop through the search results
        for j = 1:subnodeList.getLength
            
            % Retrieve a handle to this result
            subnode = subnodeList.item(j-1);

            % If the planData structure events cell array already exists
            if isfield(planData, 'events')
                
                % Set k to the next index
                k = size(planData.events, 1) + 1;
            else
                % Otherwise events does not yet exist, so start with 1
                k = 1;
            end

            % Search for the tau of this sync event
            subsubexpression = xpath.compile('tau');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the next event cell array tau value
            planData.events{k,1} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Store the type value as isoZRate (couch velocity)
            planData.events{k,2} = 'isoZRate';

            % Search for the zVelocity value
            subsubexpression = xpath.compile('zVelocity');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the z velocity value
            planData.events{k,3} = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
        end
    end

    %% Store delivery plan image file reference
    % Search for delivery plan parent UID
    subexpression = ...
        xpath.compile('binaryFileNameArray/binaryFileNameArray');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the binary image file archive path
    planData.fluenceFilename = ...
        fullfile(path, char(subnode.getFirstChild.getNodeValue));

    % Because the matching fluence delivery plan was found, break the
    % for loop to stop searching
    break;
end

%% Finalize Events array
% Add a sync event at tau = 0.   Events that do not have a value
% are given the placeholder value 1.7976931348623157E308 
k = size(planData.events,1)+1;
planData.events{k,1} = 0;
planData.events{k,2} = 'sync';
planData.events{k,3} = 1.7976931348623157E308;

% Add a projection width event at tau = 0
k = size(planData.events,1)+1;
planData.events{k,1} = 0;
planData.events{k,2} = 'projWidth';
planData.events{k,3} = 1;

% Add an eop event at the final tau value (stored in fluence.totalTau).
%  Again, this event does not have a value, so use the placeholder
k = size(planData.events,1)+1;
planData.events{k,1} = planData.totalTau;
planData.events{k,2} = 'eop';
planData.events{k,3} = 1.7976931348623157E308;

% Sort events by tau
planData.events = sortrows(planData.events);

%% Load fluence sinogram
% Log start of sinogram load
if exist('Event', 'file') == 2
    Event(sprintf('Loading delivery plan binary data from %s', ...
        planData.fluenceFilename));
end

% Open a read file handle to the delivery plan binary array 
fid = fopen(planData.fluenceFilename, 'r', 'b');

% Initalize the return variable sinogram to store the delivery 
% plan in sinogram notation
sinogram = zeros(64, planData.numberOfProjections);

% Loop through the number of projections in the delivery plan
for i = 1:planData.numberOfProjections
    
    % Read 2 double events for every leaf in numberOfLeaves.  Note that
    % the XML delivery plan stores each all the leaves for the first
    % projection, then the second, etc, as opposed to the dose
    % calculator plan.img, which stores all events for the first leaf,
    % then all events for the second leaf, etc.  The first event is the
    % "open" tau value, while the second is the "close" value
    leaves = fread(fid, planData.numberOfLeaves * 2, 'double');

    % Loop through each projection (2 events)
    for j = 1:2:size(leaves)
        
       % The projection number is the mean of the "open" and "close"
       % events.  This assumes that the open time was centered on the 
       % projection.  1 is added as MATLAB uses one based indices.
       index = floor((leaves(j) + leaves(j+1)) / 2) + 1;

       % Store the difference between the "open" and "close" tau values
       % as the fractional leaf open time (remember one tau = one
       % projection) in the sinogram array under the correct
       % leaf (numbered 1:64)
       sinogram(planData.lowerLeafIndex+(j+1)/2, index) = ...
           leaves(j+1) - leaves(j);
    end
end

% Close the delivery plan file handle
fclose(fid);

% Determine first and last "active" projection
% Loop through each projection in temporary sinogram array
for i = 1:size(sinogram, 2)

    % If the maximum value for all leaves is greater than 1%, assume
    % the projection is active
    if max(sinogram(:,i)) > 0.01

        % Set startTrim to the current projection
        planData.startTrim = i;

        % Stop looking for the first active projection
        break;
    end
end

% Loop backwards through each projection in temporary sinogram array
for i = size(sinogram,2):-1:1

    % If the maximum value for all leaves is greater than 1%, assume
    % the projection is active
    if max(sinogram(:,i)) > 0.01

        % Set stopTrim to the current projection
        planData.stopTrim = i;

        % Stop looking for the last active projection
        break;
    end
end

% Set the sinogram return variable to the start and stop trimmed
% binary array
planData.sinogram = sinogram(:, planData.startTrim:planData.stopTrim);

%% Load machine agnostic delivery plan
if exist('Event', 'file') == 2
    Event('Searching for machine agnostic plan');
end

% Search for fluence delivery plan associated with the plan trial
expression = ...
    xpath.compile('//fullDeliveryPlanDataArray/fullDeliveryPlanDataArray');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    
    % Retrieve a handle to this delivery plan
    node = nodeList.item(i-1);

    %% Verify delivery plan UID
    % Search for delivery plan parent UID
    subexpression = xpath.compile('deliveryPlan/dbInfo/databaseParent');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database parent was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end

    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);

    % If the delivery databaseParent UID does not match the plan
    % trial's UID, this delivery plan is associated with a different
    % plan, so continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            planData.planTrialUID) == 0
        continue
    end

    %% Verify delivery plan is machine agnostic
    % Search for delivery plan purpose
    subexpression = xpath.compile('deliveryPlan/purpose');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no purpose was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end

    % Otherwise, retrieve a handle to the purpose search result
    subnode = subnodeList.item(0);

    % If the delivery plan purpose is not Fluence, continue to next result
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Machine_Agnostic') == 0
        continue
    end
    
    %% Load lower leaf index
    % Search for delivery plan lower leaf index
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/lowerLeafIndex');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the lower leaf index value
    planData.agnosticLowerLeafIndex = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load number of projections
    % Search for delivery plan number of projections
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfProjections');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the number of projections value
    planData.agnosticNumberOfProjections = ...
        str2double(subnode.getFirstChild.getNodeValue);

    %% Load number of leaves
    % Search for delivery plan number of leaves
    subexpression = ...
        xpath.compile('deliveryPlan/states/states/numberOfLeaves');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the number of leaves value
    planData.agnosticNumberOfLeaves = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    %% Store delivery plan image file reference
    % Search for delivery plan parent UID
    subexpression = ...
        xpath.compile('binaryFileNameArray/binaryFileNameArray');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % Store the binary image file archive path
    planData.agnosticFilename = ...
        fullfile(path, char(subnode.getFirstChild.getNodeValue));

    % Because the matching agnostic delivery plan was found, break the
    % for loop to stop searching
    break;
end

%% Save machine agnostic sinogram
% Log start of sinogram load
if exist('Event', 'file') == 2
    Event(sprintf('Loading delivery plan binary data from %s', ...
        planData.agnosticFilename));
end

% Open a read file handle to the delivery plan binary array 
fid = fopen(planData.agnosticFilename, 'r', 'b');

% Initalize the return variable sinogram to store the delivery 
% plan in sinogram notation
sinogram = zeros(64, planData.agnosticNumberOfProjections);

% Loop through the number of projections in the delivery plan
for i = 1:planData.agnosticNumberOfProjections
    
    % Read 2 double events for every leaf in numberOfLeaves.  Note that
    % the XML delivery plan stores each all the leaves for the first
    % projection, then the second, etc, as opposed to the dose
    % calculator plan.img, which stores all events for the first leaf,
    % then all events for the second leaf, etc.  The first event is the
    % "open" tau value, while the second is the "close" value
    leaves = fread(fid, planData.agnosticNumberOfLeaves * 2, 'double');

    % Loop through each projection (2 events)
    for j = 1:2:size(leaves)
        
       % The projection number is the mean of the "open" and "close"
       % events.  This assumes that the open time was centered on the 
       % projection.  1 is added as MATLAB uses one based indices.
       index = floor((leaves(j) + leaves(j+1)) / 2) + 1;

       % Store the difference between the "open" and "close" tau values
       % as the fractional leaf open time (remember one tau = one
       % projection) in the sinogram array under the correct
       % leaf (numbered 1:64)
       sinogram(planData.agnosticLowerLeafIndex+(j+1)/2, index) = ...
           leaves(j+1) - leaves(j);
    end
end

% Close the delivery plan file handle
fclose(fid);

% Set the agnostic return variable to the start and stop trimmed
% binary array
planData.agnostic = sinogram(:, planData.startTrim:planData.stopTrim);

%% Finish up
% Report success
if exist('Event', 'file') == 2
    Event(sprintf(['Plan data loaded successfully with %i events and %i', ...
        ' projections in %0.3f seconds'], size(planData.events, 1), ...
        planData.numberOfProjections, toc));
end

% Clear temporary variables
clear fid i j node subnode subsubnode nodeList subnodeList subsubnodeList ...
    expression subexpression subsubexpression doc factory xpath d t;

% Catch errors, log, and rethrow
catch err
    if ismember('noerrormsg', varargin)
        return
    elseif exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end
