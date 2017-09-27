function scans = FindMVCTScans(path, name)
% FindMVCTScans searches a TomoTherapy patient archive for patient plans 
% with associated MVCT procedures, and returns a list of procedure UIDs 
% and MVCT information, including registration values and start/end scan 
% positions, organized by plan type.
%
% The following variables are required for proper execution: 
%   path: string containing the path to the patient archive XML file
%   name: string containing the name of patient XML file in path
%
% The following variable is returned upon succesful completion:
%   scans: cell array of structures for each plan, with each structure
%       containing the following fields: planUID, planName, scanUIDs, date,
%       time, scanLengths, imageFiles, imageDim, imageStart, imageSize, 
%       machineCalibration, and registration
%
% Below is an example of how this function is used:
%
%   path = '/path/to/archive/';
%   name = 'Anon_0001_patient.xml';
%   scans = FindMVCTScans(path, name);
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2016 University of Wisconsin Board of Regents
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
if exist('Event', 'file') == 2
    Event(sprintf('%i plan(s) found', length(scans)));
end

% Log start of matching and start timer
if exist('Event', 'file') == 2
    Event(sprintf('Searching %s for MVCT procedures', name));
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

    %% Search for procedureDataAnalysis
    subexpression = ...
        xpath.compile('procedure/briefProcedure/procedureDataAnalysis');

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
    
    %% Search for currentProcedureStatus
    subexpression = ...
        xpath.compile('procedure/briefProcedure/currentProcedureStatus');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);

    % If procedure was not Performed, continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), 'Performed')
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
    k = length(scans{plan}.scanUIDs)+1;
    scans{plan}.scanUIDs{k} = char(subnode.getFirstChild.getNodeValue);
    
    % Initialize empty scan length and date/time
    scans{plan}.scanLengths(k, :) = [0 0];
    scans{plan}.date{k} = '';
    scans{plan}.time{k} = '';
    
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
        scans{plan}.date{k} = char(subnode.getFirstChild.getNodeValue);
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
        scans{plan}.time{k} = char(subnode.getFirstChild.getNodeValue);
    end
    
    %% Search for machine calibration UID
    subexpression = ...
        xpath.compile('procedure/scheduledProcedure/machineCalibration');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store machine calibration UID
    scans{plan}.machineCalibration{k} = ...
        char(subnode.getFirstChild.getNodeValue);
    
    %% Search for scanList
    subexpression = xpath.compile(['procedure/scheduledProcedure/', ...
        'mvctData/scanList/scanList']);

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
            start = j-1;
            prev = 1;
            
        % Otherwise, is scan goes from 1 to 0, set stop index and break
        elseif prev == 1 && str2double(...
                subnodeList.item(j-1).getFirstChild.getNodeValue) == 0
            stop = j-1;
            break;
        end
    end
    
    % Search for scanListZValues
    subexpression = xpath.compile(['procedure/scheduledProcedure/', ...
        'mvctData/scanListZValues/scanListZValues']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no scanListZValues were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Update start and stop scan lengths
    scans{plan}.scanLengths(k, 1) = ...
        str2double(subnodeList.item(start).getFirstChild.getNodeValue);
    scans{plan}.scanLengths(k, 2) = ...
        str2double(subnodeList.item(stop).getFirstChild.getNodeValue);
    
    %% Search for image data
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/binaryFileName']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the binary file name
    scans{plan}.imageFiles{k} = char(subnode.getFirstChild.getNodeValue);
    
    %% Search for image X dimension
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/dimensions/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image dimensions
    scans{plan}.imageDim(k, 1) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for image Y dimension
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/dimensions/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    %% Store the image dimensions
    scans{plan}.imageDim(k, 2) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for image Z dimension
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/dimensions/z']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image dimensions
    scans{plan}.imageDim(k, 3) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for image X start
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/start/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image start
    scans{plan}.imageStart(k, 1) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for image Y start
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/start/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image start
    scans{plan}.imageStart(k, 2) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for image Z start
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/start/z']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image start
    scans{plan}.imageStart(k, 3) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for image X size
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/elementSize/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image size
    scans{plan}.imageSize(k, 1) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for image Y size
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/elementSize/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image size
    scans{plan}.imageSize(k, 2) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for image Z size
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/elementSize/z']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image size
    scans{plan}.imageSize(k, 3) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for registration X
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/displacement/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    scans{plan}.registration(k, 4) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for registration Y
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/displacement/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    scans{plan}.registration(k, 5) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for registration Z
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/displacement/z']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    scans{plan}.registration(k, 6) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for registration pitch
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/rotation/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    scans{plan}.registration(k, 1) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for registration yaw
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/rotation/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    scans{plan}.registration(k, 2) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    %% Search for registration roll
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/rotation/z']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    scans{plan}.registration(k, 3) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
end

% Log completion of search
if exist('Event', 'file') == 2
    Event(sprintf('MVCT scans parsed successfully in %0.3f seconds', toc));
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
