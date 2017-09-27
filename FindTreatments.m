function treatments = FindTreatments(path, name)
% FindTreatments searches a TomoTherapy patient archive for patient plans 
% with associated delivered treatments, and returns a list of procedure 
% UIDs and treatment information including the MU delivered, treatment 
% time, and return status.
%
% The following variables are required for proper execution: 
%   path: string containing the path to the patient archive XML file
%   name: string containing the name of patient XML file in path
%
% The following variable is returned upon succesful completion:
%   treatments: cell array of structures for each plan, with each structure
%       containing the following fields: planUID, planName, txUIDs, date,
%       time, dose, status, duration, machineCalibration, and MU
%
% Below is an example of how this function is used:
%
%   path = '/path/to/archive/';
%   name = 'Anon_0001_patient.xml';
%   treatments = FindTreatments(path, name);
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2017 University of Wisconsin Board of Regents
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
   
% Log start of matching and start timer
if exist('Event', 'file') == 2
    Event(sprintf('Searching %s for approved plans', name));
    tic;
end

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node
if exist('Event', 'file') == 2
    Event('Loading file contents data using xmlread');
end
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Declare a new xpath search expression for all fullPlanDataArrays
expression = ...
    xpath.compile('//fullPlanDataArray/fullPlanDataArray/plan/briefPlan');

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Preallocate return cell arrays
treatments = cell(1, nodeList.getLength);

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    
    % Retrieve a handle to this delivery plan
    node = nodeList.item(i-1);

    % Search for approved plan trial UID
    subexpression = xpath.compile('approvedPlanTrialUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Otherwise, if approved plan trial UID is empty, continue
    if strcmp(char(subnode.getFirstChild.getNodeValue), '')
        continue
    end
    
    % Search for plan type
    subexpression = xpath.compile('typeOfPlan');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If plan type was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Otherwise, if plan type is not PATIENT, continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), 'PATIENT')
        continue
    end
    
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
    
    % Store the plan UID
    treatments{i}.planUID = char(subnode.getFirstChild.getNodeValue);
    
    % Search for plan label
    subexpression = xpath.compile('planLabel');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database UID was found, continue to next result
    if subnodeList.getLength == 0
        treatments{i}.planName = 'UNKNOWN';
        continue
    end
    
    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan label
    treatments{i}.planName = char(subnode.getFirstChild.getNodeValue);
    
    % Initialize txUIDs
    treatments{i}.txUIDs = cell(0);
end

% Remove empty cells due invalid plans
treatments = treatments(~cellfun('isempty', treatments));

% Log number of delivery plans found
if exist('Event', 'file') == 2
    Event(sprintf('%i plan(s) found', length(treatments)));
end

% Log start of matching and start timer
if exist('Event', 'file') == 2
    Event(sprintf('Searching %s for treatment procedures', name));
end

% Declare a new xpath search expression for all fullProcedureDataArrays
expression = xpath.compile(['//fullProcedureDataArray/', ...
    'fullProcedureDataArray']);

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Loop through the fullProcedureDataArrays
for i = 1:nodeList.getLength

    % Retrieve a handle to this procedure
    node = nodeList.item(i-1);

    %% Search for procedureType
    subexpression = ...
        xpath.compile('procedure/briefProcedure/procedureType');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved procedure type was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);

    % If procedure type is not Treatment, continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), 'Treatment')
        continue
    end
    
    %% Search for database parent UID
    subexpression = ...
        xpath.compile('procedure/briefProcedure/dbInfo/databaseParent');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);

    % Store parent UID
    parent = char(subnode.getFirstChild.getNodeValue);
    
    % Initialize plan flag
    plan = 0;
    
    % Loop through each patient scan
    for j = 1:length(treatments)
        
        % If the parent UID matches a plan
        if strcmp(parent, treatments{j}.planUID)
            
            % Set plan to index
            plan = j;
            
            % Break for loop
            break;
        end
    end
    
    % If this procedure did not match a plan, continue to next procedure
    if plan == 0; continue; end
    
    %% Search for procedure database UID
    subexpression = ...
        xpath.compile('procedure/briefProcedure/dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);

    % Store procedure UID
    k = length(treatments{plan}.txUIDs)+1;
    treatments{plan}.txUIDs{k} = char(subnode.getFirstChild.getNodeValue);
    
    %% Search for currentProcedureStatus
    subexpression = ...
        xpath.compile('procedure/briefProcedure/currentProcedureStatus');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no currentProcedureStatus was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);

    % Store the status
    treatments{plan}.status{k} = char(subnode.getFirstChild.getNodeValue);
    
    %% Search for deliveryStartDateTime date
    subexpression = xpath.compile(['procedure/briefProcedure/', ...
        'deliveryStartDateTime/date']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If date was found, store result
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store procedure date
        treatments{plan}.date{k} = char(subnode.getFirstChild.getNodeValue);
    end
    
    %% Search for deliveryStartDateTime time
    subexpression = xpath.compile(['procedure/briefProcedure/', ...
        'deliveryStartDateTime/time']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If date was found, store result
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store procedure date
        treatments{plan}.time{k} = char(subnode.getFirstChild.getNodeValue);
    end
    
    %% Search for fraction dose
    subexpression = ...
        xpath.compile('procedure/briefProcedure/fractionDoseInGray');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store dose
    treatments{plan}.dose{k} = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    %% Search for procedure duration
    subexpression = ...
        xpath.compile('procedure/briefProcedure/procedureDurationInSeconds');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store duration
    treatments{plan}.duration{k} = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    %% Search for procedure number
    subexpression = ...
        xpath.compile('procedure/briefProcedure/procedureNumber');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store procedure number
    treatments{plan}.procedure{k} = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    %% Search for machine calibration UID
    subexpression = ...
        xpath.compile('procedure/scheduledProcedure/machineCalibration');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store machine calibration UID
    treatments{plan}.machineCalibration{k} = ...
        char(subnode.getFirstChild.getNodeValue);
    
    %% Search for return status
    subexpression = ...
        xpath.compile(['fullProcedureReturnData/fullProcedureReturnData', ...
        '/procedureReturnData/procedureReturnStatus']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store return status
    treatments{plan}.status{k} = ...
        char(subnode.getFirstChild.getNodeValue);
    
    %% Search for MU1
    subexpression = ...
        xpath.compile(['fullProcedureReturnData/fullProcedureReturnData', ...
        '/procedureReturnData/deliveryResults/deliveryResults/', ...
        'muChamber1Hundredths']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store MU1
    treatments{plan}.MU(k, 1) = ...
        str2double(subnode.getFirstChild.getNodeValue)/100;
    
    %% Search for MU2
    subexpression = ...
        xpath.compile(['fullProcedureReturnData/fullProcedureReturnData', ...
        '/procedureReturnData/deliveryResults/deliveryResults/', ...
        'muChamber2Hundredths']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store MU1
    treatments{plan}.MU(k, 2) = ...
        str2double(subnode.getFirstChild.getNodeValue)/100;
end

% Log completion of search
if exist('Event', 'file') == 2
    Event(sprintf('Treatments parsed successfully in %0.3f seconds', toc));
end

% Clear temporary variables
clear doc factory xpath i j k node subnode nodeList subnodeList expression ...
    subexpression parent plan prev start stop;

% Catch errors, log, and rethrow
catch err  
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end
