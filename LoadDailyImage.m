function image = LoadDailyImage(varargin)
% LoadDailyImage scans an given directory for images, loading the image 
% into a structure object  If varargin{2} is 'DICOM', it will search for 
% DICOM images.  If multiple DICOM datasets are found in the directory, 
% LoadDailyImage will fail as this feature is not currently implemented.
% If varargin{2} is 'ARCHIVE', it will search the TomoTherapy patient
% archive.  If multiple images exist in the patient archive, a list dialog
% UI will appear allowing the user to select which image to load.  
%
% The following variables are required for proper execution: 
%   varargin{1}: location of the directory to search
%   varargin{2}: 'DICOM' or 'ARCHIVE'
%   varargin{3} (optional): if varargin{2} is 'ARCHIVE', the name of the 
%       patient XML
%   varargin{4} (optional): if varargin{2} is 'ARCHIVE', the UID of the
%       daily image to load
%
% The following variables are returned upon succesful completion:
%   dailyImage: structure containing the machine, image type (MVCT), UID, 
%       date/time, binary data, dimensions, start coordinates, voxel size, 
%       FOV, and (if type is 'ARCHIVE') accepted registration adjustments,
%       plan UID, and machineCalibration (for loading IVDT)
%
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

% Log beginning of LoadDailyImage
Event(['Loading daily image from ',varargin{1}]);

% Initialize return variable structure object
image = struct;

% Execute code block based on type of image provided in varargin{2}
switch varargin{2}
    
% If the type of image to load is from a patient archive    
case 'ARCHIVE'

    % Log start of image load and start timer
    if exist('Event', 'file') == 2
        Event(sprintf('Extracting daily image from %s for plan UID %s', ...
            fullfile(varargin{1}, varargin{3}), varargin{4}));
        tic;
    end

    % The patient XML is parsed using xpath class
    import javax.xml.xpath.*

    % Read in the patient XML and store the Document Object Model node to doc
    doc = xmlread(fullfile(varargin{1}, varargin{3}));

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
        if ~strcmp(char(subnode.getFirstChild.getNodeValue), varargin{4})
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

        %% Load structure set UID
        % Search for procedure XML object planStructureSetUID
        subexpression = xpath.compile('plan/planStructureSetUID');

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

        %% Load couch checksum and insertion position
        % Search for procedure XML object couchChecksum
        subexpression = xpath.compile('plan/couchChecksum');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % If a couch checksum was found
        if subnodeList.getLength > 0

            % Store the first returned value
            subnode = subnodeList.item(0);

            % Save the couch checksum to return structure as char array
            image.couchChecksum = ...
                char(subnode.getFirstChild.getNodeValue);
        end

        % Search for procedure XML object couchInsertionPosition
        subexpression = xpath.compile('plan/couchInsertionPosition');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % If a couch insertion position was found
        if subnodeList.getLength > 0

            % Store the first returned value
            subnode = subnodeList.item(0);

            % Save the couch checksum to return structure as char array
            image.couchInsertionPosition = ...
                char(subnode.getFirstChild.getNodeValue);
        end
    
        %% Load associated plan trial
        % Search for procedure XML object approvedPlanTrialUID
        subexpression = xpath.compile('plan/briefPlan/approvedPlanTrialUID');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % If a couch checksum was found
        if subnodeList.getLength > 0

            % Store the first returned value
            subnode = subnodeList.item(0);

            % Save the plan trial to return structure as char array
            image.planTrialUID = ...
                char(subnode.getFirstChild.getNodeValue);

        % Otherwise, log event warning
        elseif exist('Event', 'file') == 2
            Event(sprintf(['An approved plan trial UID this image set was not', ...
            ' found in %s'], name), 'WARN');
        end

        % Declare a new xpath search expression.  Search for all plan trials
        subexpression = xpath.compile(['fullPlanTrialArray/', ...
            'fullPlanTrialArray/patientPlanTrial']);

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % Loop through the plan trials
        for j = 1:subnodeList.getLength

            % Retrieve handle to this image
            subnode = subnodeList.item(j-1);

            %% Verify plan trial UID
            % Search for procedure XML object databaseUID
            subsubexpression = xpath.compile('dbInfo/databaseUID');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % If a UID was found
            if subsubnodeList.getLength > 0

                % Store the first returned value
                subsubnode = subsubnodeList.item(0);
            else

                % Otherwise, continue to next result
                continue
            end

            % If the plan data array does not match the provided UID, continue to
            % next result
            if ~strcmp(char(subsubnode.getFirstChild.getNodeValue), ...
                    image.planTrialUID)
                continue
            end  

            %% Load reference image isocenter
            % Search for procedure XML object referenceImageIsocenter
            subsubexpression = xpath.compile('referenceImageIsocenter/x');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % If an isocenter X was found
            if subsubnodeList.getLength > 0

                % Store the first returned value
                subsubnode = subsubnodeList.item(0);

                % Save the isocenter X to return structure as char array
                image.isocenter(1) = ...
                    str2double(subsubnode.getFirstChild.getNodeValue);
            end

            % Search for procedure XML object referenceImageIsocenter
            subsubexpression = xpath.compile('referenceImageIsocenter/y');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % If an isocenter Y was found
            if subsubnodeList.getLength > 0

                % Store the first returned value
                subsubnode = subsubnodeList.item(0);

                % Save the isocenter Y to return structure as char array
                image.isocenter(2) = ...
                    str2double(subsubnode.getFirstChild.getNodeValue);
            end

            % Search for procedure XML object referenceImageIsocenter
            subsubexpression = xpath.compile('referenceImageIsocenter/z');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % If an isocenter Z was found
            if subsubnodeList.getLength > 0

                % Store the first returned value
                subsubnode = subsubnodeList.item(0);

                % Save the isocenter Z to return structure as char array
                image.isocenter(3) = ...
                    str2double(subsubnode.getFirstChild.getNodeValue);
            end

            % Reference plan trial was found, so exit loop
            break;
        end
        
        % Reference plan was found, so exit loop
        break;
    end
        
    %% Load MVCT
    % Declare a new xpath search expression for all fullProcedureDataArrays
expression = xpath.compile(['//fullProcedureDataArray/', ...
    'fullProcedureDataArray']);

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Loop through the fullProcedureDataArrays
for i = 1:nodeList.getLength

    % Retrieve a handle to this procedure
    node = nodeList.item(i-1);
    
    % Search for procedure database UID
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

    % Verify procedure UID matches provided, otherwise continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), varargin{3})
        continue;
    end
    
    % Search for scheduledStartDateTime date
    subexpression = xpath.compile(['procedure/briefProcedure/', ...
        'scheduledStartDateTime/date']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If date was found, store result
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store procedure date
        d = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Search for scheduledStartDateTime time
    subexpression = xpath.compile(['procedure/briefProcedure/', ...
        'scheduledStartDateTime/time']);

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If date was found, store result
    if subnodeList.getLength > 0
        
        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Store procedure date
        t = char(subnode.getFirstChild.getNodeValue);
    end
    
    % Store the date and time as a timestamp
    image.timestamp = datenum([d,'-',t], 'yyyymmdd-HHMMSS');
    
    % Search for machine calibration UID
    subexpression = ...
        xpath.compile('procedure/scheduledProcedure/machineCalibration');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);
    
    % Store machine calibration UID
    image.machineCalibration = ...
        char(subnode.getFirstChild.getNodeValue);
    
    % Search for scanList
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
    image.scanLength(1) = ...
        str2double(subnodeList.item(start).getFirstChild.getNodeValue);
    image.scanLength(2) = ...
        str2double(subnodeList.item(stop).getFirstChild.getNodeValue);
    
    % Search for image data
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
    image.filename = fullfile(varargin{1}, ...
        char(subnode.getFirstChild.getNodeValue));
    
    % Search for image X dimension
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/dimensions/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image dimensions
    image.dimensions(1) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for image Y dimension
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/dimensions/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image dimensions
    image.dimensions(2) = ...
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
    image.dimensions(3) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for image X start
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/start/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image start
    image.start(1) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for image Y start
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/start/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image start
    image.start(2) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for image Z start
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/start/z']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image start
    image.start(3) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for image X size
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/elementSize/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image size
    image.width(1) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for image Y size
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/elementSize/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image size
    image.width(2) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for image Z size
    subexpression = xpath.compile(['fullImageDataArray/fullImageDataArray/', ...
        'image/arrayHeader/elementSize/z']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the image size
    image.width(3) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for registration X
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/displacement/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    image.registration(1) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for registration Y
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/displacement/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    image.registration(2) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for registration Z
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/displacement/z']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    image.registration(3) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for registration pitch
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/rotation/x']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    image.registration(4) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for registration yaw
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/rotation/y']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    image.registration(5) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Search for registration roll
    subexpression = xpath.compile(['fullCorrelationDataArray/', ...
        'fullCorrelationDataArray/correlation/rotation/z']);
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no values were found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Store the registration
    image.registration(6) = ...
        str2double(subnodeList.item(0).getFirstChild.getNodeValue);
    
    % Break the loop, as the MVCT was found
    break;
end

% If a machine calibration UID does not exist
if ~isfield(image, 'machineCalibration')
    
    % Load the IVDT information using MVCT mode
    image.ivdt = FindIVDT(varargin{1}, image.machineCalibration, 'MVCT');
    
else
    
    % Throw a warning
    if exist('Event', 'file') == 2
        Event(sprintf(['An associated machine calibration was not found ', ...
            'for UID %s; an IVDT was therefore not loaded'], varargin{4}), 'WARN');
    else
        warning(['An associated machine calibration was not found ', ...
            'for UID %s; an IVDT was therefore not loaded'], varargin{4});
    end
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

% If the type of image to load is a DICOM image
case 'DICOM'
    
    % Start the load timer
    tic;
    
    %% Load files from directory
    % List all files in the directory
    fileList = dir(varargin{1});
    
    % Initialize empty variables for the study, series UID, and z-dimension
    image.studyUID = '';
    image.seriesUID = '';
    image.width(3) = 0;
    
    % Initialize empty 3D array for images and vector of slice locations
    % (the data may not be loaded in correct order; these will be used to
    % re-sort the slices later)
    images = [];
    sliceLocations = [];
    
    % Loop through each file in the directory
    for i = 1:size(fileList,1)
        
        % Attempt to load each file using dicominfo
        try
            
            % If dicominfo is successful, store the header information
            info = dicominfo(fullfile(varargin{1},fileList(i).name));
        catch
            
            % Otherwise, the file is either corrupt or not a real DICOM
            % file, so warn user
            Event(['File ', fileList(i).name, ' is not a valid DICOM ', ...
                'image and was skipped']);
            
            % Then, automatically skip to next file in directory 
            continue
        end
        
        % If this is the first DICOM image (and the study and series IDs
        % have not yet been set
        if strcmp(image.studyUID,'') 
            
            % Store the study UID, series UID, and slice thickness (in cm)
            image.studyUID = info.StudyInstanceUID;
            image.seriesUID = info.SeriesInstanceUID;
            image.width(3) = info.SliceThickness / 10; % cm
            
        % Otherwise, if this file's study UID does not match the others,
        % multiple DICOM studies may be present in the same folder (not
        % currently supported)
        elseif ~strcmp(image.studyUID,info.StudyInstanceUID)
            Event(['Multiple DICOM Study Instance UIDs were found in ', ...
                'this directory.  Please separate the different studies', ...
                'into their own directories.'], 'ERROR');
            
        % Otherwise, if this file's series UID does not match the others,
        % multiple DICOM series may be present in the same folder (not
        % currently supported)
        elseif ~strcmp(image.seriesUID,info.SeriesInstanceUID) 
            Event(['Multiple DICOM Series Instance UIDs were found in ', ...
                'this directory.  Please separate the different series', ...
                'into their own directories.'], 'ERROR');
            
        % Otherwise, if this file's slice thickness in cm is different than
        % the others, throw an error (variable slice thickness is not 
        % currently supported)
        elseif image.width(3) ~= info.SliceThickness / 10
            Event('Variable slice thickness daily image found', 'ERROR');
        end
        
        % Append this slice's location to the sliceLocations vector
        sliceLocations(size(sliceLocations,2)+1) = ...
            info.SliceLocation; %#ok<*AGROW>
        
        % Append this slice's image data to the images array
        images(size(images,1)+1,:,:) = dicomread(info); %#ok<*AGROW>
 
    end
    
    %% Set related tags
    % Retrieve machine name
    image.machine = info.StationName;
    
    % Log machine name
    Event(['DICOM treatment system identified as ', image.machine]);
    
    % Retrieve date/time
    image.timestamp = [info.AcquisitionDate, ' ', ...
        info.AcquisitionTime];

    % Set image type based on series description (for MVCTs) or DICOM
    % header modality tag (for everything else)
    if strcmp(info.SeriesDescription, 'CTrue Image Set')
        image.type = 'MVCT';
    else
        image.type = info.Modality;
    end
    
    % Log image type
    Event(['DICOM image type identified as ', image.type]);
    
    % Retrieve start voxel coordinates from DICOM header, in cm
    image.start(1) = info.ImagePositionPatient(1) / 10;
    image.start(2) = info.ImagePositionPatient(2) / 10;
    image.start(3) = min(info.ImagePositionPatient(3)) / 10;
    
    % Retrieve x/y voxel widths from DICOM header, in cm
    image.width(1) = info.PixelSpacing(1) / 10;
    image.width(2) = info.PixelSpacing(2)  /10;

    % If patient is Head First
    if info.ImageOrientationPatient(1) == 1
        
        % Log orientation
        Event('Patient position identified as Head First');
        
        % Sort sliceLocations vector in ascending order
        [~, indices] = sort(sliceLocations, 'ascend');
        
    % Otherwise, if the patient is Feet First (currently not supported)
    elseif info.ImageOrientationPatient(1) == -1
        
        Event('Patient position identified as Feet First');
        [~,indices] = sort(sliceLocations,'descend');
    
    % Otherwise, error as the image orientation is neither
    else
        Event(['The DICOM images do not have a standard', ...
            'orientation'], 'ERROR');
    end

    % Initialize daily image data array as single type
    image.data = single(zeros(size(images, 3), size(images, 2), ...
        size(images, 1)));
    
    % Re-order images based on sliceLocation sort indices
    Event('Sorting DICOM images');
    
    % Loop through each slice
    for i = 1:size(sliceLocations,2)
        
        % Set the daily image data based on the index value
        image.data(:, :, i) = ...
            single(rot90(permute(images(indices(i), :, :), [2 3 1])));
    end
    
    % Create dimensions structure field based on the daily image size
    image.dimensions = size(image.data);
    
    % Compute field of view from smaller of x/y widths
    image.FOV = min(image.width(1) * image.dimensions(1), ...
        image.width(2) * image.dimensions(2)); % cm
    
    % Clear temporary variables
    clear i fileList images info sliceLocations indices;

% Otherwise, an invalid type was passed to LoadDailyImage via varargin{2}
otherwise
    Event('Invalid type passed to LoadDailyImage', 'ERROR');    
end

% If an image was successfully loaded
if isfield(image, 'dimensions')
    
    % Log completion and image size
    Event(sprintf(['Daily images loaded successfully with dimensions ', ...
        '(%i, %i, %i) in %0.3f seconds'], image.dimensions, toc));

% Otherwise, warn user
else
    toc;
    Event('A daily image was not selected', 'WARN');
end