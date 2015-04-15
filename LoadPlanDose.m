function dose = LoadPlanDose(path, name, planUID)
% LoadPlanDose loads the optimized dose after EOP (ie, Final Dose) for
% a given reference plan UID and TomoTherapy patient archive.  The dose is 
% returned as a structure. This function has currently been validated for 
% version 3.X, 4.X and 5.X archives.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%   planUID: UID of plan to extract dose image
%
% The following variables are returned upon succesful completion:
%   dose: structure containing the associated plan dose (After
%       EOP) array, start coordinates, width, dimensions, and frame of
%       reference
%
% Below is an example of how this function is used:
%
%   path = '/path/to/archive/';
%   name = 'Anon_0001_patient.xml';
%   planUID = '1.2.826.0.1.3680043.2.200.1688035198.217.40463.657';
%   dose = LoadPlanDose(path, name, planUID);
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

% Run in try-catch to log error via Event.m
try
    
% Log start of plan loading and start timer
if exist('Event', 'file') == 2
    Event(sprintf('Extracting dose from %s for plan UID %s', name, ...
        planUID));
    tic;
end

% Initialize return variable
dose = struct;

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Search for images associated with the plan UID
expression = ...
    xpath.compile('//fullImageDataArray/fullImageDataArray/image');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Loop through the desize(ivdtlist,1)liveryPlanDataArrays
for i = 1:nodeList.getLength
    
    % Set a handle to the current result
    node = nodeList.item(i-1);
    
    %% Verify image type
    % Search for imageType
    subexpression = xpath.compile('imageType');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % If this image is not a KVCT image, continue to next subnode
    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
            'Opt_Dose_After_EOP') == 0
        continue
    end
    
    %% Verify database parent
    % Search for database parent UID
    subexpression = xpath.compile('dbInfo/databaseParent');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % If this parentUID does not equal the plan UID, continue
    if strcmp(char(subnode.getFirstChild.getNodeValue), planUID) == 0
        continue
    end

    % Inform user that the dose image was found
    if exist('Event', 'file') == 2
        Event(sprintf('Opt_Dose_After_EOP data identified for plan UID %s', ...
            planUID));
    end
    
    %% Load FoR
    % Search for frame of reference UID
    subexpression = xpath.compile('frameOfReference');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store frame of reference in return structure as char array
    dose.frameOfReference = ...
        char(subnode.getFirstChild.getNodeValue);
    
    %% Load binary filename
    % Search for binary file name
    subexpression = xpath.compile('arrayHeader/binaryFileName');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store filename in return structure as char array
    dose.filename = fullfile(path, ...
        char(subnode.getFirstChild.getNodeValue));
    
    %% Load image dimensions
    % Search for x dimension
    subexpression = xpath.compile('arrayHeader/dimensions/x');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store x dimension in return structure
    dose.dimensions(1) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for y dimension
    subexpression = xpath.compile('arrayHeader/dimensions/y');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store y dimension in return structure
    dose.dimensions(2) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for z dimension
    subexpression = xpath.compile('arrayHeader/dimensions/z');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store z dimension in return structure
    dose.dimensions(3) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    %% Load start coordinates
    % Search for x start coordinate
    subexpression = xpath.compile('arrayHeader/start/x');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store x start coordinate (in cm) in return structure
    dose.start(1) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for y start coordinate
    subexpression = xpath.compile('arrayHeader/start/y');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store y start coordinate (in cm) in return structure
    dose.start(2) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for z start coordinate
    subexpression = xpath.compile('arrayHeader/start/z');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store z start coordinate (in cm) in return structure
    dose.start(3) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    %% Load voxel widths
    % Search for x width coordinate
    subexpression = xpath.compile('arrayHeader/elementSize/x');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store x voxel width (in cm) in return structure
    dose.width(1) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for y width coordinate
    subexpression = xpath.compile('arrayHeader/elementSize/y');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store y voxel width (in cm) in return structure
    dose.width(2) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % Search for z width coordinate
    subexpression = xpath.compile('arrayHeader/elementSize/z');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store z voxel width (in cm) in return structure
    dose.width(3) = ...
        str2double(subnode.getFirstChild.getNodeValue);
    
    % The plan dose was found, so break for loop
    break;
end

% Check if filename field was set
if ~isfield(dose, 'filename')
    
    % If not, throw a warning as a matching dose was not found
    if exist('Event', 'file') == 2
        Event(sprintf('A plan dose was not found for plan UID %s', ...
            planUID), 'WARN');
    end
    
    % This time, search for plan trials
    if exist('Event', 'file') == 2
        Event(sprintf('Searching for plan trials in %s associated with %s', ...
            name, planUID));
    end
    
    % Search forimages associated with the plan UID
    expression = ...
        xpath.compile('//patientPlanTrial');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

    planTrialUID = '';
    
    % Loop through the deliveryPlanDataArrays
    for i = 1:nodeList.getLength
        
        % Set a handle to the current result
        node = nodeList.item(i-1);
    
        %% Verify database parent
        % Search for database parent UID
        subexpression = xpath.compile('dbInfo/databaseParent');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % If this parentUID does not equal the plan UID, continue
        if strcmp(char(subnode.getFirstChild.getNodeValue), planUID) == 0
            continue
        end
        
        %% Retrieve database UID
        % Search for database parent UID
        subexpression = xpath.compile('dbInfo/databaseUID');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Set plan trial UID
        planTrialUID = char(subnode.getFirstChild.getNodeValue);
        
        % Inform user that the plan trial was found
        if exist('Event', 'file') == 2
            Event(sprintf('Plan trial %s identified for plan UID %s', ...
                planTrialUID, planUID));
        end
        
        % Since a matching plan trial was found, exit for loop
        break;
    end
    
    % If a matching plan trial was not found
    if strcmp(planTrialUID, '')
        
        % Throw an error and stop execution
        if exist('Event', 'file') == 2
            Event(sprintf(['A matching plan trial was not found for ', ...
                'plan UID %s'], planUID), 'ERROR');
        else
            error('A matching plan trial was not found for plan UID %s', ...
                planUID);
        end
    end
    
    % Otherwise, search for doseVolumeList associated with the plan trial
    expression = ...
        xpath.compile('//doseVolumeList/doseVolumeList');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

    % Loop through the deliveryPlanDataArrays
    for i = 1:nodeList.getLength
        
        % Set a handle to the current result
        node = nodeList.item(i-1);

        %% Verify image type
        % Search for imageType
        subexpression = xpath.compile('imageType');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % If this image is not a KVCT image, continue to next subnode
        if strcmp(char(subnode.getFirstChild.getNodeValue), ...
                'Opt_Dose_After_EOP') == 0
            continue
        end

        %% Verify database parent
        % Search for database parent UID
        subexpression = xpath.compile('dbInfo/databaseParent');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % If this parentUID does not equal the plan UID, continue
        if strcmp(char(subnode.getFirstChild.getNodeValue), ...
                planTrialUID) == 0
            continue
        end

        % Inform user that the dose image was found
        if exist('Event', 'file') == 2
            Event(sprintf(['Opt_Dose_After_EOP data identified for plan', ...
                ' trial %s'], planUID));
        end

        %% Load FoR
        % Search for frame of reference UID
        subexpression = xpath.compile('frameOfReference');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store frame of reference in return structure as char array
        dose.frameOfReference = ...
            char(subnode.getFirstChild.getNodeValue);

        %% Load binary filename
        % Search for binary file name
        subexpression = xpath.compile('arrayHeader/binaryFileName');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store filename in return structure as char array
        dose.filename = fullfile(path, ...
            char(subnode.getFirstChild.getNodeValue));

        %% Load image dimensions
        % Search for x dimension
        subexpression = xpath.compile('arrayHeader/dimensions/x');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store x dimension in return structure
        dose.dimensions(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for y dimension
        subexpression = xpath.compile('arrayHeader/dimensions/y');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store y dimension in return structure
        dose.dimensions(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for z dimension
        subexpression = xpath.compile('arrayHeader/dimensions/z');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store z dimension in return structure
        dose.dimensions(3) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        %% Load start coordinates
        % Search for x start coordinate
        subexpression = xpath.compile('arrayHeader/start/x');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store x start coordinate (in cm) in return structure
        dose.start(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for y start coordinate
        subexpression = xpath.compile('arrayHeader/start/y');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store y start coordinate (in cm) in return structure
        dose.start(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for z start coordinate
        subexpression = xpath.compile('arrayHeader/start/z');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store z start coordinate (in cm) in return structure
        dose.start(3) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        %% Load voxel widths
        % Search for x width coordinate
        subexpression = xpath.compile('arrayHeader/elementSize/x');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store x voxel width (in cm) in return structure
        dose.width(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for y width coordinate
        subexpression = xpath.compile('arrayHeader/elementSize/y');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store y voxel width (in cm) in return structure
        dose.width(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % Search for z width coordinate
        subexpression = xpath.compile('arrayHeader/elementSize/z');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Store z voxel width (in cm) in return structure
        dose.width(3) = ...
            str2double(subnode.getFirstChild.getNodeValue);

        % The plan dose was found, so break for loop
        break;
    end
end

% Check if filename field was set
if ~isfield(dose, 'filename')
    
    % If not, throw an error as a matching reference dose was not found
    if exist('Event', 'file') == 2
        Event(sprintf(['A dose was not found for plan UID %s or plan', ...
            ' trial UID %s'], planUID, planTrialUID), 'ERROR');
    else
        error('A dose was not found for plan UID %s or plan trial UID %s', ...
            planUID, planTrialUID);
    end
end

%% Load dose image
% Open read file handle to binary dose image
fid = fopen(dose.filename, 'r', 'b');

% Read in and store single binary data, reshaping by image dimensions
dose.data = reshape(fread(fid, dose.dimensions(1) * ...
    dose.dimensions(2) * dose.dimensions(3), 'single'), ...
    dose.dimensions(1), dose.dimensions(2), dose.dimensions(3));

% Close file handle
fclose(fid);

% Clear temporary variables
clear fid i j node subnode subsubnode nodeList subnodeList subsubnodeList ...
    expression subexpression subsubexpression doc factory xpath;

% Log conclusion of image loading
if exist('Event', 'file') == 2
    Event(sprintf(['Plan dose loaded successfully in %0.3f seconds with ', ...
        'dimensions (%i, %i, %i)'], toc, dose.dimensions(1), ...
        dose.dimensions(2), dose.dimensions(3)));
end

% Catch errors, log, and rethrow
catch err
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end