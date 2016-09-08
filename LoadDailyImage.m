function dailyImage = LoadDailyImage(varargin)
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
%       patient XML.  If not provided, LoadDailyImage will load the first
%       *_patient.xml file found in the directory.
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
Event(['Loading daily images from ',varargin{1}]);

% Initialize return variable structure object
dailyImage = struct;

% Execute code block based on type of image provided in varargin{2}
switch varargin{2}
    
% If the type of image to load is from a patient archive    
case 'ARCHIVE'
    
    %% Load all registered datasets
    % If a patient XML was not provided
    if nargin == 2
        
        % Search a patient archive for the patient XML file
        list = dir(fullfile(varargin{1}, '*_patient.xml'));
        
        % If a patient XML file was found
        if size(list,1) > 0
            
            % Parse all registered MVCTs from the archive using
            % FindMVCTScans
            sets = FindMVCTScans(varargin{1}, list(1).name);
        else
            
            % Otherwise, throw an error was a patient XML was not found
            Event(['A patient XML was not found in the directory ', ...
                varargin{1}], 'ERROR');
        end
        
        % Clear temporary variables
        clear list;
        
    % Otherwise, a patient XML file was provided in varargin{3}
    else
        
        % Parse all registered MVCTs from the archive using FindMVCTScans
        sets = FindMVCTScans(varargin{1}, varargin{3});
    end
    
    %% Select which dataset to load
    % If at least one registred image was found 
    if size(sets, 2) > 0
        
        % Initialize a temporary cell array of strings to list each image
        list = cell(1, size(sets, 2));
        
        % Loop through each registered image
        for i = 1:size(sets, 2)
            
            % Create a formatted string of image type, date/time, and
            % accepted registration offsets [pitch yaw roll x y z]
            list{i} = sprintf(['%s   |   %s-%s   |   ', ...
                '[% 2.2f % 2.2f % 2.2f % 2.2f % 2.2f % 2.2f]'], ...
                sets{i}.type, sets{i}.date, sets{i}.time, ...
                sets{i}.registration);
        end
        
        % Open list selection UI to allow user to select a dataset 
        [s,v] = listdlg('PromptString', 'Select a daily image to load:', ...
            'SelectionMode', 'single', 'ListSize', [500 300], ...
            'ListString', list);
        
        % Start timer after user selects image
        tic;
        
        % If the user selected an image and clicked OK
        if v == 1 && s(1) > 0
            
            % Set daily image to selected image
            dailyImage = sets{s(1)};
            
            % Open a read file handle to daily image binary file
            fid = fopen(dailyImage.filename, 'r', 'b');
            
            % Read in unsigned integer binary data based on dimensions
            dailyImage.data = reshape(fread(fid, ...
                prod(dailyImage.dimensions), 'uint16'), ...
                dailyImage.dimensions);
            
            % Close file handle
            fclose(fid);
            
            % Compute field of view from smaller of x/y widths
            dailyImage.FOV = min(dailyImage.width(1) * ...
                dailyImage.dimensions(1), dailyImage.width(2) * ...
                dailyImage.dimensions(2)); % cm
        end
        
        % Clear temporary variables
        clear list s v fid;
    else
        
        % If no registered images were found, warn the user
        Event(['No registered datasets were found in the ', ...
            'patient archive ', varargin{1}], 'WARN');
    end
    
    % Clear temporary image list
    clear sets;
    
% If the type of image to load is a DICOM image
case 'DICOM'
    
    % Start the load timer
    tic;
    
    %% Load files from directory
    % List all files in the directory
    fileList = dir(varargin{1});
    
    % Initialize empty variables for the study, series UID, and z-dimension
    dailyImage.studyUID = '';
    dailyImage.seriesUID = '';
    dailyImage.width(3) = 0;
    
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
        if strcmp(dailyImage.studyUID,'') 
            
            % Store the study UID, series UID, and slice thickness (in cm)
            dailyImage.studyUID = info.StudyInstanceUID;
            dailyImage.seriesUID = info.SeriesInstanceUID;
            dailyImage.width(3) = info.SliceThickness / 10; % cm
            
        % Otherwise, if this file's study UID does not match the others,
        % multiple DICOM studies may be present in the same folder (not
        % currently supported)
        elseif ~strcmp(dailyImage.studyUID,info.StudyInstanceUID)
            Event(['Multiple DICOM Study Instance UIDs were found in ', ...
                'this directory.  Please separate the different studies', ...
                'into their own directories.'], 'ERROR');
            
        % Otherwise, if this file's series UID does not match the others,
        % multiple DICOM series may be present in the same folder (not
        % currently supported)
        elseif ~strcmp(dailyImage.seriesUID,info.SeriesInstanceUID) 
            Event(['Multiple DICOM Series Instance UIDs were found in ', ...
                'this directory.  Please separate the different series', ...
                'into their own directories.'], 'ERROR');
            
        % Otherwise, if this file's slice thickness in cm is different than
        % the others, throw an error (variable slice thickness is not 
        % currently supported)
        elseif dailyImage.width(3) ~= info.SliceThickness / 10
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
    dailyImage.machine = info.StationName;
    
    % Log machine name
    Event(['DICOM treatment system identified as ', dailyImage.machine]);
    
    % Retrieve date/time
    dailyImage.timestamp = [info.AcquisitionDate, ' ', ...
        info.AcquisitionTime];

    % Set image type based on series description (for MVCTs) or DICOM
    % header modality tag (for everything else)
    if strcmp(info.SeriesDescription, 'CTrue Image Set')
        dailyImage.type = 'MVCT';
    else
        dailyImage.type = info.Modality;
    end
    
    % Log image type
    Event(['DICOM image type identified as ', dailyImage.type]);
    
    % Retrieve start voxel coordinates from DICOM header, in cm
    dailyImage.start(1) = info.ImagePositionPatient(1) / 10;
    dailyImage.start(2) = info.ImagePositionPatient(2) / 10;
    dailyImage.start(3) = min(info.ImagePositionPatient(3)) / 10;
    
    % Retrieve x/y voxel widths from DICOM header, in cm
    dailyImage.width(1) = info.PixelSpacing(1) / 10;
    dailyImage.width(2) = info.PixelSpacing(2)  /10;

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
    dailyImage.data = single(zeros(size(images, 3), size(images, 2), ...
        size(images, 1)));
    
    % Re-order images based on sliceLocation sort indices
    Event('Sorting DICOM images');
    
    % Loop through each slice
    for i = 1:size(sliceLocations,2)
        
        % Set the daily image data based on the index value
        dailyImage.data(:, :, i) = ...
            single(rot90(permute(images(indices(i), :, :), [2 3 1])));
    end
    
    % Create dimensions structure field based on the daily image size
    dailyImage.dimensions = size(dailyImage.data);
    
    % Compute field of view from smaller of x/y widths
    dailyImage.FOV = min(dailyImage.width(1) * dailyImage.dimensions(1), ...
        dailyImage.width(2) * dailyImage.dimensions(2)); % cm
    
    % Clear temporary variables
    clear i fileList images info sliceLocations indices;

% Otherwise, an invalid type was passed to LoadDailyImage via varargin{2}
otherwise
    Event('Invalid type passed to LoadDailyImage', 'ERROR');    
end

% If an image was successfully loaded
if isfield(dailyImage, 'dimensions')
    
    % Log completion and image size
    Event(sprintf(['Daily images loaded successfully with dimensions ', ...
        '(%i, %i, %i) in %0.3f seconds'], dailyImage.dimensions, toc));

% Otherwise, warn user
else
    toc;
    Event('A daily image was not selected', 'WARN');
end