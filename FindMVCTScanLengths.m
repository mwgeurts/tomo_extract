function scans = FindMVCTScanLengths(path, name)
% FindMVCTScanLengths searches a TomoTherapy patient archive for patient
% plans with associated MVCT procedures, and returns a list of procedure
% UIDs and start/end scan positions, organized by plan type.
%
% The following variables are required for proper execution: 
%   path: string containing the path to the patient archive XML file
%   name: string containing the name of patient XML file in path
%
% The following variable is returned upon succesful completion:
%   scans: cell array of structures for each plan, with each structure
%       containing the following fields: planUID, planName, scanUIDs, and
%       scanLengths
%
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
   
% Log start of matching and start timer
Event(sprintf('Searching %s for approved plans', name));
tic;

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node
Event('Loading file contents data using xmlread');
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
scans = cell(1, nodeList.getLength);

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
    scans{i}.planUID = char(subnode.getFirstChild.getNodeValue);
    
    % Search for plan label
    subexpression = xpath.compile('planLabel');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database UID was found, continue to next result
    if subnodeList.getLength == 0
        scans{i}.planName = 'UNKNOWN';
        continue
    end
    
    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan label
    scans{i}.planName = char(subnode.getFirstChild.getNodeValue);
    
    % Initialize scanUIDs and scanLengths arrays
    scans{i}.scanUIDs = cell(0);
    scans{i}.scanLengths = [];
end

% Remove empty cells due invalid plans
scans = scans(~cellfun('isempty', scans));

% Log number of delivery plans found
Event(sprintf('%i plan(s) found', length(scans)));

% Log start of matching and start timer
Event(sprintf('Searching %s for MVCT procedures', name));

% Declare a new xpath search expression for all fullProcedureDataArrays
expression = xpath.compile(['//fullProcedureDataArray/', ...
    'fullProcedureDataArray/procedure']);

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Loop through the fullProcedureDataArrays
for i = 1:nodeList.getLength

    % Retrieve a handle to this procedure
    node = nodeList.item(i-1);

    % Search for procedureDataAnalysis
    subexpression = xpath.compile('briefProcedure/procedureDataAnalysis');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);

    % If procedure data analysis is not MVCT Recon, continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), 'MVCT Recon')
        continue
    end
    
    % Search for database parent UID
    subexpression = xpath.compile('briefProcedure/dbInfo/databaseParent');

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
    for j = 1:length(scans)
        
        % If the parent UID matches a plan
        if strcmp(parent, scans{j}.planUID)
            
            % Set plan to index
            plan = j;
            
            % Break for loop
            break;
        end
    end
    
    % If this procedure did not match a plan, continue to next procedure
    if plan == 0; continue; end
    
    % Search for procedure database UID
    subexpression = xpath.compile('briefProcedure/dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);

    % Store procedure UID
    scans{plan}.scanUIDs{length(scans{plan}.scanUIDs)+1} = ...
        char(subnode.getFirstChild.getNodeValue);
    
    % Initialize empty scan length
    scans{plan}.scanLengths(length(scans{plan}.scanLengths)+1, :) = [0 0];
    
    % Search for scanList
    subexpression = ...
        xpath.compile('scheduledProcedure/mvctData/scanList/scanList');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no scanLists were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Initialize temp flag
    prev = 0;
    
    % Loop through the scanLists
    for j = 1:subnodeList.getLength
       
        % If scan goes from 0 to 1, set start index
        if prev == 0 && str2double(...
                subnodeList.item(j-1).getFirstChild.getNodeValue) == 1
            startIndex = j-1;
            prev = 1;
            
        % Otherwise, is scan goes from 1 to 0, set stop index and break
        elseif prev == 1 && str2double(...
                subnodeList.item(j-1).getFirstChild.getNodeValue) == 0
            stopIndex = j-1;
            break;
        end
    end
    
    % Search for scanListZValues
    subexpression = xpath.compile(['scheduledProcedure/mvctData/', ...
        'scanListZValues/scanListZValues']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no scanListZValues were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Update start and stop scan lengths
    scans{plan}.scanLengths(length(scans{plan}.scanLengths), 1) = ...
        str2double(subnodeList.item(startIndex).getFirstChild.getNodeValue);
    scans{plan}.scanLengths(length(scans{plan}.scanLengths), 2) = ...
        str2double(subnodeList.item(stopIndex).getFirstChild.getNodeValue);
end

% Clear temporary variables
clear doc factory xpath i node subnode nodeList subnodeList expression ...
    subexpression j parent plan prev startIndex stopIndex;

% Catch errors, log, and rethrow
catch err  
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end