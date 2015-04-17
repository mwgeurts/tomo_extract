function planData = LoadLegacyPlan(path, name, planUID)
% LoadLegacyPlan loads the delivery plan from a specified TomoTherapy 
% patient archive and plan UID. It is identical in function to LoadPlan but 
% is compatible with version 2.X and earlier archives.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%   planUID: UID of the plan
%
% The following variables are returned upon succesful completion:
%   planData: delivery plan data including sinogram, number of projections,
%       jaw settings, pitch, modulation factor, number of iterations,
%       label, description, laser positions, and machine specific sinogram
%
% Below is an example of how this function is used:
%
%   path = '/path/to/archive/';
%   name = 'Anon_0001_patient.xml';
%   planUID = '1.2.826.0.1.3680043.2.200.1688035198.217.40463.657';
%   plan = LoadLegacyPlan(path, name, planUID);
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
    Event(sprintf(['Extracting plan information from %s for plan ', ...
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

% If a patient name was found
if nodeList.getLength > 0

    % Store the first returned value
    subnode = nodeList.item(0);
    
    % Set patient name
    planData.patientName = char(subnode.getFirstChild.getNodeValue);

% Otherwise, warn the user that patient info wasn't found
else
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
        image.patientBirthDate = ...
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

%% Load plan info
% Declare a new xpath search expression.  Search for all plans
expression = ...
    xpath.compile('//fullPlanDataArray/fullPlanDataArray');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Loop through the results
for i = 1:nodeList.getLength
    
    % Set a handle to the current result
    node = nodeList.item(i-1);

    %% Verify plan UID
    % Search for procedure XML object databaseUID
    subexpression = xpath.compile('plan/briefPlan/dbInfo/databaseUID');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % If a UID was found
    if subnodeList.getLength > 0
        
        % Store the first returned value
        subnode = subnodeList.item(0);
    else
        
        % Otherwise, continue to next result
        continue
    end
    
    % If the plan data array does not match the provided UID, continue to
    % next result
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), planUID)
        continue
    end 
    
    %% Load plan parameters
    % Search for plan label
    subexpression = xpath.compile('plan/briefPlan/planLabel');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan label
    planData.planLabel = char(subnode.getFirstChild.getNodeValue);
    
    % Search for plan description
    subexpression = xpath.compile('plan/briefPlan/planDescription');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a plan description was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the plan description
        planData.planDescription = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for approvingUserName
    subexpression = xpath.compile('plan/briefPlan/approvingUserName');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a result was retrieved
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the approvingUserName
        planData.approver = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for plan modification date
    subexpression = ...
        xpath.compile('plan/briefPlan/modificationTimestamp/date');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan date
    d = char(subnode.getFirstChild.getNodeValue);
    
    % Search for plan modification time
    subexpression = ...
        xpath.compile('plan/briefPlan/modificationTimestamp/time');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan time
    t = char(subnode.getFirstChild.getNodeValue);
    
    % Store the date and time as a timestamp
    planData.timestamp = datetime([d,'-',t], 'InputFormat', ...
        'yyyyMMdd-HHmmss');
    
    % Search for plan delivery type
    subexpression = xpath.compile('plan/intendedTableMotion');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If plan delivery type was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan delivery type
    planData.planType = char(subnode.getFirstChild.getNodeValue);
    
    % Search for approver user name
    subexpression = xpath.compile('plan/briefPlan/approvingUserName');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a user name was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the approver user name
        planData.approvedBy = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for prescribed dose
    subexpression = xpath.compile('plan/prescription/prescribedDose');

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
    subexpression = xpath.compile('plan/prescription/volumePercentage');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a prescribed volume was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the prescribed volume
        planData.rxVolume = str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for front jaw
    subexpression = ...
        xpath.compile('plan/plannedJawFieldSpec/jawWidth/frontJaw');

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
        xpath.compile('plan/plannedJawFieldSpec/jawWidth/backJaw');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a back jaw was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the back jaw
        planData.backJaw = str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for front field
    subexpression = ...
        xpath.compile('plan/plannedJawFieldSpec/fieldSize/frontField');

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
        xpath.compile('plan/plannedJawFieldSpec/fieldSize/backField');

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
    
    % Search for pitch
    subexpression = xpath.compile('plan/pitch');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a pitch was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the pitch
        planData.pitch = str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for projections per rotation
    subexpression = xpath.compile('plan/numProjsPerRotation');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a number of projections per rotation was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the projections per rotation
        planData.numProjsPerRotation = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for planned fractions
    subexpression = ...
        xpath.compile('plan/plannedFractions/scheme/scheme/fractionIndex');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If fractions were found
    if subnodeList.getLength > 0

        % Store the number of fractions
        planData.fractions = subnodeList.getLength;
    end
    
    % Search for setup to ready distance
    subexpression =  xpath.compile('plan/plannedCouchSetupToReadyZ');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a setup to ready was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the setup to ready
        planData.setupToReady = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for X laser position
    subexpression = xpath.compile('plan/movableLaserPosition/x');

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
    subexpression = xpath.compile('plan/movableLaserPosition/y');

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
    subexpression = xpath.compile('plan/movableLaserPosition/z');

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
    
    % Search for dose calculation grid
    subexpression = xpath.compile('plan/doseCalculationGrid');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a calc grid was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the calc grid
        planData.calcGrid = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for modulation factor
    subexpression = xpath.compile('plan/planningModulationFactor');

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
    
    % Search for start angle
    subexpression = xpath.compile('plan/planningStartAngle');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a start angle was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the start angle
        planData.startAngle = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for the number of iterations
    subexpression = xpath.compile('plan/iterationNumber');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If an iteration number was found
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store the iterations
        planData.iterations = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    %% Load fluence sinogram
    % Search for sinograms
    subexpression = xpath.compile(['fullSinogramDataArray/', ...
        'fullSinogramDataArray/sinogram']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If one or more sinograms exist
    if subnodeList.getLength > 0
        
        % Loop through the search results
        for j = 1:subnodeList.getLength
            
            % Retrieve a handle to this result
            subnode = subnodeList.item(j-1);
            
            % Search for the database parent
            subsubexpression = xpath.compile('dbInfo/databaseParent');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % If the database parent does not match the plan UID, continue
            if strcmp(char(subsubnode.getFirstChild.getNodeValue), ...
                    planUID) == 0
                continue;
            end
            
            % Search for the sino type
            subsubexpression = xpath.compile('sinoType');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % If the sino type is not Planned_Fluence_After_EOP, continue
            if strcmp(char(subsubnode.getFirstChild.getNodeValue), ...
                    'Planned_Fluence_After_EOP') == 0
                continue;
            end
            
            % Search for the sinogram filename
            subsubexpression = ...
                xpath.compile('arrayHeader/sinogramDataFile');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the sinogram file name
            planData.fluenceFilename = ...
                fullfile(path, char(subsubnode.getFirstChild.getNodeValue));
                
            % Search for the sinogram filename
            subsubexpression = ...
                xpath.compile('arrayHeader/sinogramDataFile');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the sinogram file name
            planData.fluenceFilename = ...
                fullfile(path, char(subsubnode.getFirstChild.getNodeValue));
            
            % Search for the sinogram dimensions
            subsubexpression = ...
                xpath.compile('arrayHeader/dimensions/dimensions');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);
            
            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store the first dimension as number of leaves
            planData.numberOfLeaves = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Retrieve a handle to the next result
            subsubnode = subsubnodeList.item(1);

            % Store the second dimension as number of projections
            planData.numberOfProjections = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
   
             % Because the EOP sinogram was found, stop searching
            break;
        end
    end
    
    % Because the procedure was found, stop searching
    break;
end

%% Load fluence delivery plan
% Log start of sinogram load
if exist('Event', 'file') == 2
    Event(sprintf('Loading sinogram binary data from %s', ...
        planData.fluenceFilename));
end

% Open a read file handle to the sinogram binary array 
fid = fopen(planData.fluenceFilename, 'r', 'b');

% Read the file in and reshape to a sinogram
sinogram = reshape(fread(fid, planData.numberOfLeaves * ...
    planData.numberOfProjections, 'single'), ...
    planData.numberOfLeaves, planData.numberOfProjections);

% Close the sinogram file handle
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

%% Load machine specific sinogram
% Declare a new xpath search expression.  Search for all procedures
expression = ...
    xpath.compile('//fullProcedureDataArray/fullProcedureDataArray');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Loop through the results
for i = 1:nodeList.getLength
    
    % Set a handle to the current result
    node = nodeList.item(i-1);

    %% Verify plan UID
    % Search for procedure XML object databaseParent
    subexpression = ...
        xpath.compile('procedure/briefProcedure/dbInfo/databaseParent');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % If a parent UID was found
    if subnodeList.getLength > 0
        
        % Store the first returned value
        subnode = subnodeList.item(0);
    else
        
        % Otherwise, continue to next result
        continue
    end
    
    % If the parent ID does not match the provided UID, continue to
    % next result
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), planUID)
        continue
    end 

    %% Verify procedure type
    % Search for procedure XML object procedureType
    subexpression = ...
        xpath.compile('procedure/briefProcedure/procedureType');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % If a procedure type was found
    if subnodeList.getLength > 0
        
        % Store the first returned value
        subnode = subnodeList.item(0);
    else
        
        % Otherwise, continue to next result
        continue
    end
    
    % If the procedure type is not Treatment, continue to next result
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), 'Treatment')
        continue
    end 
    
    %% Verify this is not a completion procedure
    % Search for procedure XML object isResumptionOfIncompleteProcedure
    subexpression = xpath.compile(['procedure/scheduledProcedure/', ...
        'isResumptionOfIncompleteProcedure']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % If a procedure type was found
    if subnodeList.getLength > 0
        
        % Store the first returned value
        subnode = subnodeList.item(0);
    else
        
        % Otherwise, continue to next result
        continue
    end
    
    % If the procedure is a completion, continue to next result
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), 'false')
        continue
    end 
    
    %% Load sinogram information
    % Search for normalized leaf open time sinogram
    subexpression = xpath.compile(['procedure/scheduledProcedure/mlcProce', ...
        'dure/normalizedLeafOpenTimes/arrayHeader/sinogramDataFile']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % Retrieve a handle to the results
    subnode = subnodeList.item(0);

    % Store the sinogram file name
    planData.specificFilename = ...
        fullfile(path, char(subnode.getFirstChild.getNodeValue));
    
    % Search for the sinogram dimensions
    subexpression = xpath.compile(['procedure/scheduledProcedure/mlcProce', ...
        'dure/normalizedLeafOpenTimes/arrayHeader/dimensions/dimensions']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
 
    % Retrieve a handle to the first result
    subnode = subnodeList.item(0);

    % Store the first dimension as number of leaves
    planData.specificNumberOfLeaves = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Retrieve a handle to the next result
    subnode = subnodeList.item(1);

    % Store the second dimension as number of projections
    planData.specificNumberOfProjections = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Because the matching specific sinogram was found, break the for loop 
    % to stop searching
    break;
end

%% Save machine specific sinogram
% Log start of sinogram load
if exist('Event', 'file') == 2
    Event(sprintf('Loading sinogram binary data from %s', ...
        planData.specificFilename));
end

% Open a read file handle to the sinogram binary array 
fid = fopen(planData.specificFilename, 'r', 'b');

% Read the file in and reshape to a sinogram
planData.specific = reshape(fread(fid, planData.specificNumberOfLeaves * ...
    planData.specificNumberOfProjections, 'single'), ...
    planData.specificNumberOfLeaves, planData.specificNumberOfProjections);

% Close the sinogram file handle
fclose(fid);

%% Finish up
% Report success
if exist('Event', 'file') == 2
    Event(sprintf(['Plan data loaded successfully with %i projections ', ...
        'in %0.3f seconds'], planData.numberOfProjections, toc));
end

% Clear temporary variables
clear fid i j node subnode subsubnode nodeList subnodeList subsubnodeList ...
    expression subexpression subsubexpression doc factory xpath;

% Catch errors, log, and rethrow
catch err
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end