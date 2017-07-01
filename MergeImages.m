function merged = MergeImages(reference, daily, v, varargin)
% MergeImages merges a daily image into a reference image by resampling the 
% daily image to the reference image coordinate system, using a supplied 
% registration vector and then using the reference image data outside the 
% daily image field of view to create a merged image of the same size and 
% coordinates as the reference image.
%
% During merging, the reference image is converted to daily-IVDT equivalent 
% Hounsfield Units by first interpolating to density using the reference 
% IVDT and then subsequently interpolating back to HU using the daily IVDT.  
% The final merged image is therefore in daily-equivalent Hounsfield Units.
%
% Masks are created to exclude image data outside the cylindrical Field Of 
% View (FOV) for the reference and daily images.  If not provided, the 
% smaller of the transverse image dimensions are used for determining the 
% FOV.
%
% The rigid transformation matrix adjustments are stored in the return 
% structure field "tform". For more information on the format of this 
% matrix, see S. M. LaVelle, "Planning Algorithms", Cambridge University 
% Press, 2006 at http://planning.cs.uiuc.edu/node104.html.
%
% The following variables are required for proper execution: 
%   reference: structure containing the image data, dimensions, width,
%       start coordinates, and IVDT.  See LoadReferenceImage()
%   daily: structure containing the image data, dimensions, width,
%       start coordinates, FOV, and IVDT.  See LoadDailyImage().
%   v: 6 element registration vector in [pitch yaw roll x y z] IEC
%       coordinates, or a 4x4 tranformation matrix.
%
% The following variables are returned upon succesful completion:
%   merged: structure containing a merged reference/daily image
%       (converted back to the daily IVDT), transformation matrix, 
%       dimensions, width, start coordinates and IVDT
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

% Initialize default options
fill = true;

% Loop through remaining input arguments
for i = 4:2:length(varargin)

    % Store provided options
    if strcmpi(varargin{i}, 'fill')
        fill = varargin{i+1};
    end
end

% Start timer
tic;

%% Determine registration
% If the variable input is a registration vector
if isvector(v) && length(v) == 6
    
    %% Generate transformation matrix
    % Log start of transformation
    if exist('Event', 'file') == 2        
        Event('Generating transformation matrix');
    end
    
    % Generate 4x4 transformation matrix given a 6 element vector of 
    % [pitch yaw roll x y z].  
    tform(1,1) = cosd(v(3)) * cosd(v(1));
    tform(2,1) = cosd(v(3)) * sind(v(1)) * sind(v(2)) - sind(v(3)) * cosd(v(2));
    tform(3,1) = cosd(v(3)) * sind(v(1)) * cosd(v(2)) + sind(v(3)) * sind(v(2));
    tform(4,1) = v(6);
    tform(1,2) = sind(v(3)) * cosd(v(1));
    tform(2,2) = sind(v(3)) * sind(v(1)) * sind(v(2)) + cosd(v(3)) * cosd(v(2));
    tform(3,2) = sind(v(3)) * sind(v(1)) * cosd(v(2)) - cosd(v(3)) * sind(v(2));
    tform(4,2) = v(4);
    tform(1,3) = -sind(v(1));
    tform(2,3) = cosd(v(1)) * sind(v(2));
    tform(3,3) = cosd(v(1)) * cosd(v(2));
    tform(4,3) = -v(5);
    tform(1,4) = 0;
    tform(2,4) = 0;
    tform(3,4) = 0;
    tform(4,4) = 1;
    
% Otherwise, if input is a transformation matrix
elseif ismatrix(v) && isequal(size(v), [4 4])
    
    % Store input
    tform = v;
    
% Otherwise, throw an error
else
    if exist('Event', 'file') == 2
        Event('Incorrect third argument. See documentation for formats', ...
            'ERROR');
    else
        error('Incorrect third argument. See documentation for formats');
    end
end

%% Apply density conversion
% Note conversion in log
if exist('Event', 'file') == 2
    Event(['Converting reference image to daily-equivalent Hounsfield ', ...
        ' Units using IVDT']);
end

% Convert reference image to equivalent daily-IVDT image
reference.data = interp1(daily.ivdt(:,2), daily.ivdt(:,1), ...
    interp1(reference.ivdt(:,1), reference.ivdt(:,2), ...
    reference.data, 'linear', 'extrap'), 'linear', 'extrap');

%% Generate meshgrids for reference image
% Log start of mesh grid computation and dimensions
if exist('Event', 'file') == 2
    Event(sprintf('Generating reference mesh grid with dimensions (%i %i %i 3)', ...
        reference.dimensions));
end

% Generate x, y, and z grids using start and width structure fields (which
% are stored in [x,z,y] format)
[refX, refY, refZ] = meshgrid(reference.start(2) + ...
    reference.width(2) * (size(reference.data, 2) - 1): ...
    -reference.width(2):reference.start(2), ...
    reference.start(1):reference.width(1):reference.start(1) ...
    + reference.width(1) * (size(reference.data, 1) - 1), ...
    reference.start(3):reference.width(3):reference.start(3) ...
    + reference.width(3) * (size(reference.data, 3) - 1));

% Generate unity matrix of same size as reference data to aid in matrix 
% transform
ref1 = ones(reference.dimensions);

%% Generate meshgrids for daily image
% Log start of mesh grid computation and dimensions
if exist('Event', 'file') == 2
    Event(sprintf('Generating daily mesh grid with dimensions (%i %i %i 3)', ...
        daily.dimensions));
end

% Generate x, y, and z grids using start and width structure fields (which
% are stored in [x,z,y] format)
[secX, secY, secZ] = meshgrid(daily.start(2) + ...
    daily.width(2) * (size(daily.data, 2) - 1): ...
    -daily.width(2):daily.start(2), ...
    daily.start(1):daily.width(1):daily.start(1) ...
    + daily.width(1) * (size(daily.data, 1) - 1), ...
    daily.start(3):daily.width(3):daily.start(3) ...
    + daily.width(3) * (size(daily.data, 3) - 1));

%% Transform reference image meshgrids
% Log start of transformation
if exist('Event', 'file') == 2
    Event('Applying transformation matrix to reference mesh grid');
end

% Separately transform each reference x, y, z point by shaping all to 
% vector form and dividing by transformation matrix
result = [reshape(refX,[],1) reshape(refY,[],1) reshape(refZ,[],1) ...
    reshape(ref1,[],1)] / tform;

% Reshape transformed x, y, and z coordinates back to 3D arrays
refX = reshape(result(:,1), reference.dimensions);
refY = reshape(result(:,2), reference.dimensions);
refZ = reshape(result(:,3), reference.dimensions);

% Clear temporary variables
clear result ref1;

%% Generate FOV mask
% Log task
if exist('Event', 'file') == 2
    Event('Generating FOV mask');
end

% If an FOV field does not exist
if ~isfield(daily, 'FOV')
   
    % Calculate FOV from minimum image dimension
    daily.FOV = min([daily.dimensions(1) * daily.width(1) ...
        daily.dimensions(2) * daily.width(2)]);
    
    % Warn user
    if exist('Event', 'file') == 2
        Event(sprintf(['FOV not specific, using minimum image dimention of ', ...
            '%0.1f cm'], daily.FOV, 'WARN'));
    else
        warning(['FOV not specific, using minimum image dimention of ', ...
            '%0.1f cm'], daily.FOV);
    end
end

% Create meshgrid the same size as one daily image for mask generation
[x,y] = meshgrid(((1:daily.dimensions(1)) - daily.dimensions(1)/2) ...
    * daily.width(1), ((1:daily.dimensions(2)) - ...
    daily.dimensions(2)/2) ...
    * daily.width(2));

% Set the mask to 1 within the daily image FOV
mask = single(sqrt(x.^2+y.^2) < daily.FOV/2 - 0.1)';

% Clear temporary variables
clear x y;

% Loop through each slice
for i = 1:daily.dimensions(3)
    
    % Multiple daily image data by mask to remove values outside of FOV
    daily.data(:,:,i) = mask .* (daily.data(:,:,i) + 1E-6);
end

% Log completion of masking
if exist('Event', 'file') == 2
    Event('FOV mask applied to daily image');
end

%% Resample daily image
% Log start of interpolation
if exist('Event', 'file') == 2
    Event('Attempting GPU interpolation of daily image');
end

% Use try-catch statement to attempt to perform interpolation using GPU.  
% If a GPU compatible device is not available (or fails due to memory), 
% automatically revert to CPU based technique
try
    % Initialize and clear GPU memory
    gpuDevice(1);
    
    % Interpolate the daily image dataset to the reference dataset's
    % transformed coordinates using GPU linear interpolation, and store to 
    % varargout{1}
    merged.data = gather(interp3(gpuArray(secX), gpuArray(secY), ...
        gpuArray(secZ), gpuArray(daily.data), gpuArray(refX), ...
        gpuArray(refY), gpuArray(refZ), 'linear', 0));
    
    % Clear memory
    gpuDevice(1);
    
    % Log success of GPU method
    if exist('Event', 'file') == 2
        Event('GPU interpolation completed');
    end
catch
    
    % Otherwise, GPU failed, so notify user that CPU will be used
    if exist('Event', 'file') == 2
        Event('GPU interpolation failed, reverting to CPU interpolation', ...
            'WARN');
    end
    
    % Interpolate the daily image dataset to the reference dataset's
    % transformed coordinates using CPU linear interpolation, and store to 
    % varargout{1}
    merged.data = interp3(secX, secY, secZ, daily.data, refX, ...
        refY, refZ, '*linear', 0);
    
    % Log completion of CPU method
    if exist('Event', 'file') == 2
        Event('CPU interpolation completed');
    end
end

% Clear temporary variables
clear refX refY refZ secX secY secZ;

% Create (resampled) daily image mask using ceil()
merged.mask = ceil(single(merged.data) / 65535);

%% Add surrounding reference data
if fill

    % Add reference data multiplied by inverse of daily mask
    merged.data = merged.data + reference.data .* ...
        single(abs(merged.mask - 1));
end

%% Finish merge
% Set merged image supporting parameters
merged.dimensions = reference.dimensions;
merged.width = reference.width;
merged.start = reference.start;
merged.ivdt = daily.ivdt;

% Store tranformation vector
merged.tform = tform;

% Clear temporary variables
clear tform;

% Log completion of merge
if exist('Event', 'file') == 2
    Event(sprintf(['Reference image merged into transformed daily image ', ...
        'in %0.3f seconds'], toc));
end
