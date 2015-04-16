function image = LoadLegacyImage(path, name, planUID)
% LoadLegacyImage loads the reference CT from a specified TomoTherapy 
% patient archive and plan UID. It is identical in function to LoadImage 
% but is compatible with version 2.X and earlier archives.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%   planUID: UID of plan to extract reference image from
%
% The following variables are returned upon succesful completion:
%   image: structure containing the image data, dimensions, width,
%       start coordinates, and structure set UID
%
% Below is an example of how this function is used:
%
%   path = '/path/to/archive/';
%   name = 'Anon_0001_patient.xml';
%   planUID = '1.2.826.0.1.3680043.2.200.1688035198.217.40463.657';
%   image = LoadLegacyImage(path, name, planUID);
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
    
% Log start of image load and start timer
if exist('Event', 'file') == 2
    Event(sprintf('Extracting reference image from %s for plan UID %s', ...
        name, planUID));
    tic;
end

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Store class UID
image.classUID = '1.2.840.10008.5.1.4.1.1.2';

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
    image.patientName = char(subnode.getFirstChild.getNodeValue);

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
    image.patientID = char(subnode.getFirstChild.getNodeValue);
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
    image.patientSex = char(subnode.getFirstChild.getNodeValue);
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
    
    %% Load patient position
    % Search for procedure XML object patientPosition
    subexpression = xpath.compile('plan/patientPosition');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a patient position was found
    if subnodeList.getLength > 0
        
        % Store the first returned value
        subnode = subnodeList.item(0);

        % Save patient position to return structure as char array
        image.position = ...
            char(subnode.getFirstChild.getNodeValue);
    
        % Log position
        if exist('Event', 'file') == 2
            Event(['The patient position was identified as ', ...
                image.position]);
        end
        
    % Otherwise, warn the user
    elseif exist('Event', 'file') == 2
        Event(sprintf('The patient position was not found in %s', name), ...
            'WARN');
    end
    
    %% Load plan date/time
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
    image.timestamp = datetime([d,'-',t], 'InputFormat', ...
        'yyyyMMdd-HHmmss');
    
    %% Load structure set UID
    % Search for procedure XML object planStructureSet databaseUID
    subexpression = ...
        xpath.compile('plan/planStructureSet/dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a structure set UID was found
    if subnodeList.getLength > 0
        
        % Store the first returned value
        subnode = subnodeList.item(0);

        % Save structure set UID to return structure as char array
        image.structureSetUID = ...
            char(subnode.getFirstChild.getNodeValue);
    end
    
    %% Load reference image isocenter
    % Search for procedure XML object referenceImageIsocenter
    subexpression = xpath.compile('plan/referenceImageIsocenter/x');

    % Evaluate xpath expression and retrieve the results
    subnodeList = ...
        subexpression.evaluate(subnode, XPathConstants.NODESET);

    % If an isocenter X was found
    if subnodeList.getLength > 0

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Save the isocenter X to return structure as char array
        image.isocenter(1) = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    % Search for procedure XML object referenceImageIsocenter
    subexpression = xpath.compile('plan/referenceImageIsocenter/y');

    % Evaluate xpath expression and retrieve the results
    subnodeList = ...
        subexpression.evaluate(subnode, XPathConstants.NODESET);

    % If an isocenter Y was found
    if subnodeList.getLength > 0

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Save the isocenter Y to return structure as char array
        image.isocenter(2) = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end

    % Search for procedure XML object referenceImageIsocenter
    subexpression = xpath.compile('plan/referenceImageIsocenter/z');

    % Evaluate xpath expression and retrieve the results
    subnodeList = ...
        subexpression.evaluate(subnode, XPathConstants.NODESET);

    % If an isocenter Z was found
    if subnodeList.getLength > 0

        % Store the first returned value
        subnode = subnodeList.item(0);

        % Save the isocenter Z to return structure as char array
        image.isocenter(3) = ...
            str2double(subnode.getFirstChild.getNodeValue);
    end
    
    %% Load associated image UID
    % Search for procedure XML object planStructureSet modified associated
    % image UID
    subexpression = ...
        xpath.compile('plan/planStructureSet/modifiedAssociatedImage');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If a image UID was found
    if subnodeList.getLength > 0
        
        % Store the first returned value
        subnode = subnodeList.item(0);

        % Save image UID to return structure as char array
        image.modifiedImageUID = ...
            char(subnode.getFirstChild.getNodeValue);
    end
    
    %% Load associated image
    % Search for associated images
    subexpression = ...
        xpath.compile('fullImageDataArray/fullImageDataArray/image');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Loop through the images
    for j = 1:subnodeList.getLength
        
        % Retrieve handle to this image
        subnode = subnodeList.item(j-1);

        % Check if image UID matches associated image, otherwise continue
        subsubexpression = xpath.compile('dbInfo/databaseUID');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % If this image UID does not match, continue to next subnode
        if strcmp(char(subsubnode.getFirstChild.getNodeValue), ...
                image.modifiedImageUID) == 0
            continue
        end
        
        % Check if image type is KVCT, otherwise continue
        subsubexpression = xpath.compile('imageType');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % If this image is not a KVCT image, continue to next subnode
        if strcmp(char(subsubnode.getFirstChild.getNodeValue), ...
                'KVCT') == 0
            continue
        end

        % Inform user that image data was found
        if exist('Event', 'file') == 2
            Event(sprintf('Image data identified for plan UID %s', ...
                planUID));
        end
       
        %% Load CT filename
        % Search for path to ct image
        subsubexpression = xpath.compile('arrayHeader/binaryFileName');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store filename with a path to the binary KVCT data
        image.filename = fullfile(path, ...
            char(subsubnode.getFirstChild.getNodeValue));
        
        %% Load frame of reference UID
        % Search for path to ct image
        subsubexpression = xpath.compile('frameOfReference');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store frameRefUID
        image.frameRefUID = ...
            char(subsubnode.getFirstChild.getNodeValue);
        
        %% Load image dimensions
        % Search for x dimensions of image
        subsubexpression = xpath.compile('arrayHeader/dimensions/x');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store x dimensions to return structure
        image.dimensions(1) = ...
            str2double(subsubnode.getFirstChild.getNodeValue);

        % Search for y dimensions of image
        subsubexpression = xpath.compile('arrayHeader/dimensions/y');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store y dimensions to return structure
        image.dimensions(2) = ...
            str2double(subsubnode.getFirstChild.getNodeValue);

        % Search for z dimensions of image
        subsubexpression = xpath.compile('arrayHeader/dimensions/z');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store z dimensions to return structure
        image.dimensions(3) = ...
            str2double(subsubnode.getFirstChild.getNodeValue);

        %% Load start coordinates
        % Search for the x coordinate of the first voxel
        subsubexpression = xpath.compile('arrayHeader/start/x');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store x start coordinate (in cm) to return structure
        image.start(1) = ...
            str2double(subsubnode.getFirstChild.getNodeValue);

        % Search for the y coordinate of the first voxel
        subsubexpression = xpath.compile('arrayHeader/start/y');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store y start coordinate (in cm) to return structure
        image.start(2) = ...
            str2double(subsubnode.getFirstChild.getNodeValue);

        % Search for the z coordinate of the first voxel
        subsubexpression = xpath.compile('arrayHeader/start/z');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store z start coordinate (in cm) to return structure
        image.start(3) = ...
            str2double(subsubnode.getFirstChild.getNodeValue);

        %% Load voxel widths
        % Search for the voxel size in the x direction
        subsubexpression = xpath.compile('arrayHeader/elementSize/x');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store x voxel width (in cm) to return structure
        image.width(1) = ...
            str2double(subsubnode.getFirstChild.getNodeValue);

        % Search for the voxel size in the y direction
        subsubexpression = xpath.compile('arrayHeader/elementSize/y');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store y voxel width (in cm) to return structure
        image.width(2) = ...
            str2double(subsubnode.getFirstChild.getNodeValue);

        % Search for the voxel size in the z dimension
        subsubexpression = xpath.compile('arrayHeader/elementSize/z');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store z voxel width (in cm) to return structure
        image.width(3) = ...
            str2double(subsubnode.getFirstChild.getNodeValue);

        % Reference image was found, so exit loop
        break;
    end
    
    % Plan has been found, so exit loop
    break;
end

% If a filename does not exist
if ~isfield(image, 'filename')
    
    % Throw an error
    if exist('Event', 'file') == 2
        Event(sprintf(['An associated image filename was not found ', ...
            'for UID %s'], planUID), 'ERROR');
    else
        error('An associated image filename was not found for UID %s', ...
            planUID);
    end
end

%% Load the planned image array
% Open read file handle to binary image
fid = fopen(image.filename, 'r', 'b');

% Read in and store unsigned int binary data, reshaping by image dimensions
image.data = single(reshape(fread(fid, image.dimensions(1) * ...
    image.dimensions(2) * image.dimensions(3), 'uint16'), ...
    image.dimensions(1), image.dimensions(2), ...
    image.dimensions(3)));

% Close file handle
fclose(fid);

% Clear temporary variables
clear fid i j node subnode subsubnode nodeList subnodeList subsubnodeList ...
    expression subexpression subsubexpression doc factory xpath d t;

% Log conclusion of image loading
if exist('Event', 'file') == 2
    Event(sprintf(['Reference binary image loaded successfully in %0.3f ', ...
        'seconds with dimensions (%i, %i, %i) '], toc, ...
        image.dimensions(1), image.dimensions(2), image.dimensions(3)));
end

% Catch errors, log, and rethrow
catch err
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end