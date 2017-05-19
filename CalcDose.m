function dose = CalcDose(varargin)
% CalcDose reads in a patient CT and delivery plan, generate a set of 
% inputs that can be passed to the TomoTherapy Standalone Dose Calculator, 
% and executes the dose calculation either locally or remotely.  
%
% This function will first attempt to calculate dose locally, if available
% (the system must support the which command).  If not found, the dose 
% calculator inputs will be copied to a remote computation server via
% SCP and sadose/gpusadose executed via an initiated SSH connection (See
% the README for more infomation). 
%
% To change the connection information for the remote computation server,
% create a file named config.txt in the working directory with the 
% following content (one is provided as an example in this repository): 
%
%   REMOTE_CALC_SERVER = tomo-research
%   REMOTE_CALC_USER = username
%   REMOTE_CALC_PASS = password
%
% The first argument is the server DNS name (or IP address), while the 
% second and third are the username and password, respectively.  This user 
% account must have SSH access rights, rights to execute sadose/gpusadose, 
% and finally read/write access to the temp directory. Note, this function 
% assumes that the remote computation server is unix-based. If a config
% file is not found, or does not contain the above content, and local 
% executables are not present, this function will not be able to compute 
% dose.
%
% Following execution, the CT image, folder, and SSH connection variables
% are persisted, such that CalcDose may be executed again with only a new
% plan input argument.
%
% Dose calculation will natively compute the dose at the CT resolution.
% However, if the number of image data elements is greater than 4e7, the
% dose will be downsampled by a factor of two.  The calculated dose will be 
% downsampled (from the CT image resolution) by this factor in the IECX and 
% IECY directions, then upsampled (using nearest neighbor interpolation) 
% back to the original CT resolution following calculation.  To speed up 
% calculation, the dose can be further downsampled by adjusting the 
% downsample input arguument (see below for input options).
%
% Contact Accuray Incorporated to see if your research workstation includes 
% the TomoTherapy Standalone Dose Calculator.
%
% The following variables are required for proper execution. If called with
% zero elements, CalcDose will check for the presence of a calculation
% engine and return a flag indicating whether one was found. Note that all
% input options are stored persistently, so do not need to be passed with
% each execution.
%   image (optional): cell array containing the CT image to be calculated 
%       on. The following fields are required, data (3D array), width (in 
%       cm), start (in cm), dimensions (3 element vector), and ivdt (2 x n 
%       array of CT and density value)
%   plan: delivery plan structure including scale, tau, lower 
%       leaf index, number of projections, number of leaves, sync/unsync 
%       actions, and leaf sinogram. May optionally include a 6-element 
%       registration vector.
%   varargin{3:n}: name/value pairs of input options. Names may include 
%       'modelfolder', 'sadose', 'downsample', 'azimuths', 'raysteps', or 
%       'supersample'. The value
%       for 'modelfolder' is a string containing the path to the beam model 
%       files (dcom.header, fat.img, kernel.img, etc.). The value for 
%       'sadose' is a flag indicating whether to call sadose or gpusadose.
%       If not provided, defaults to 0 (gpusadose). CPU calculation should 
%       only be used if non-analytic scatter kernels are necessary, as it 
%       will significantly slow down dose calculation. The value for
%       'downsample' should be an integer that is an even divisor of the CT
%       resolution. The value for 'supersample' should be a logical (0 or
%       1) indicating whether to downsample.
%
% The following variables are returned upon succesful completion:
%   dose: If inputs are provided, a cell array contaning the dose volume.  
%       dose.data will be the same size as image.data, and the start, 
%       width, and dimensions fields will be identical.  If no inputs are
%       provided, CalcDose will simply test for local and remote dose
%       calculation and return a flag indicating whether or not a suitable
%       dose calculator is found.
%
% Below are examples of how this function is used:
%
%   % Test if dose calculation is available (returns 0 or 1)
%   flag = CalcDose();
%
%   % Calculate dose, passing image, plan, and model folder inputs
%   dose = CalcDose(image, plan, 'modelfolder', './GPU');
%
%   % Calculate dose on same image as above, using modified plan modplan
%   dose = CalcDose(modplan);
%
%   % Calculate dose again, but using sadose rather than gpusadose
%   dose = CalcDose(image, modplan, 'sadose', 1);
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

% Store calcdose flag, temporary folder, image array, plan array, and ssh2 
% connection for subsequent calculations
persistent calcdose folder remotefolder modelfolder image sadose ssh2 ...
    azimuths raysteps downsample supersample;

% If dose calculation capability has not yet been determined, or CalcDose
% has been executed without any input arguments
if ~exist('calcdose', 'var') || isempty(calcdose) || nargin == 0
    
    % If the local system is unix-based
    if isunix
    
        % Check for gpusadose locally
        [status, cmdout] = system('which gpusadose');

    % Otherwise, if Windows
    elseif ispc
        
        % Execute where command (will only work on Windows Server 2003 and
        % later systems)
        [status, cmdout] = system('where gpusadose.exe');
    end
        
    % If gpusadose exists
    if status == 0 && ~strcmp(cmdout,'')

        % Log gpusadose version
        [~, str] = system('gpusadose -V');
        cellarr = textscan(str, '%s', 'delimiter', '\n');
        if exist('Event', 'file') == 2
            Event(sprintf('Found %s at %s', char(cellarr{1}(1)), cmdout));
        end
        
        % Set calcdose variable
        calcdose = 1;

        % Clear temporary variables
        clear str cellarr;
        
    % Otherwise local dose calculation does not exist
    else

        % Inform the user that remote server will be searched
        if exist('Event', 'file') == 2
            Event(['Checking for remote computation server']);
        end
        
        % Load configuration settings
        % Open file handle to config.txt file
        fid = fopen('config.txt', 'r');
        
        % Verify that file handle is valid
        if fid < 3
            
            % If not, throw an error
            if exist('Event', 'file') == 2
                Event(['The config.txt file could not be opened. Verify that this ', ...
                    'file exists in the working directory. See documentation for ', ...
                    'more information'], 'WARN');
            end
            
            % Set calcdose flag
            calcdose = 0;
        else
        
            % Scan config file contents
            c = textscan(fid, '%s', 'Delimiter', '=');

            % Close file handle
            fclose(fid);

            % Initialize config structure
            config = struct;

            % Loop through textscan array, separating key/value pairs into array
            for i = 1:2:length(c{1})
                config.(strtrim(c{1}{i})) = strtrim(c{1}{i+1});
            end

            % Clear temporary variables
            clear c i fid;

            % Log completion
            if exist('Event', 'file') == 2
                Event('Loaded config.txt parameters');
            end

            % If remote calc server settings were provided
            if isfield(config, 'REMOTE_CALC_SERVER') && ...
                    isfield(config, 'REMOTE_CALC_USER') && ...
                    isfield(config, 'REMOTE_CALC_PASS')

                % A try/catch statement is used in case Ganymed-SSH2 or the remote 
                % calculation server is not available
                try

                    % Log start of javalib loading
                    if exist('Event', 'file') == 2
                        Event('Adding Ganymed-SSH2 javalib');
                    end

                    % Determine path of current executable
                    [path, ~, ~] = fileparts(mfilename('fullpath'));

                    % Verify javalib path exists
                    if ~isdir(fullfile(path, 'ssh2_v2_m1_r6/'))
                        Event('Ganymed-SSH2 javalib path is missing', 'WARN');
                    end

                    % Load Ganymed-SSH2 javalib
                    addpath(fullfile(path, 'ssh2_v2_m1_r6/')); 

                    % Log completion
                    if exist('Event', 'file') == 2
                        Event('Ganymed-SSH2 javalib added successfully');
                    end

                    % Establish connection to computation server.  The ssh2_config
                    % parameters below should be set to the DNS/IP address of the
                    % computation server, user name, and password with SSH/SCP and
                    % read/write access, respectively.  See the README for more 
                    % infomation
                    if exist('Event', 'file') == 2
                        Event(['Connecting to ', config.REMOTE_CALC_SERVER, ...
                            ' via SSH2']);
                    end
                    ssh2 = ssh2_config(config.REMOTE_CALC_SERVER, ...
                        config.REMOTE_CALC_USER, config.REMOTE_CALC_PASS);

                    % Test the SSH2 connection.  If this fails, catch the error 
                    % below.
                    [ssh2, ~] = ssh2_command(ssh2, 'ls');
                    if exist('Event', 'file') == 2
                        Event('SSH2 connection successfully established');
                    end

                    % Set calcdose flag
                    calcdose = 1;

                    % Clear temporary variables
                    clear path;

                % addpath, ssh2_config, or ssh2_command may all fail if ganymed is
                % not available or if the remote server is not responding
                catch err

                    % Log failure
                    if exist('Event', 'file') == 2
                        Event(getReport(err, 'extended', 'hyperlinks', 'off'), ...
                            'WARN');
                    end

                    % Set calcdose flag
                    calcdose = 0;
                end

                % Clear temporary variables
                clear status cmdout;
            else

                % Log missing config options
                if exist('Event', 'file') == 2
                    Event('The necessary config.txt options were not present', ...
                        'WARN');
                end

                % Set calcdose flag
                calcdose = 0;
            end
        end
    end
end

% If no inputs provided, return calcdose flag
if nargin == 0

    dose = calcdose;
    return;

% If only one argument was passed, store as registration and use previous
% image and plan variables
elseif nargin == 1
    
    % Store the plan variable
    plan = varargin{1};
    
% Otherwise, store image, plan, and loop through remaining options
% GPU algorithm and local dose calculation
elseif nargin >= 2
    
    % Store image, plan, and beam model folder variables
    image = varargin{1};
    plan = varargin{2};    
    
    % Default sadose to 0 (force use of gpusadose)
    if isempty(sadose)
        sadose = 0;
    end
    
    % Default modelfolder to ./GPU
    if isempty(modelfolder)
        modelfolder = './GPU';
    end
    
    % Default supersample to 0
    if isempty(supersample)
        supersample = 0;
    end
    
    % Default downsample to 0
    if isempty(downsample)
        downsample = 0;
    end
    
    % Default azimuths to 4
    if isempty(azimuths)
        azimuths = 4;
    end
    
    % Default raysteps to 1
    if isempty(raysteps)
        raysteps = 1;
    end
    
    % Loop through remaining arguments
    for i = 3:2:length(varargin)
        
        if strcmpi(varargin{i}, 'sadose')
            sadose = varargin{i+1};
        elseif strcmpi(varargin{i}, 'modelfolder')
            modelfolder = varargin{i+1};
        elseif strcmpi(varargin{i}, 'supersample')
            supersample = varargin{i+1};
        elseif strcmpi(varargin{i}, 'downsample')
            downsample = varargin{i+1};
        elseif strcmpi(varargin{i}, 'azimuths')
            azimuths = varargin{i+1};
        elseif strcmpi(varargin{i}, 'raysteps')
            raysteps = varargin{i+1};
        end
    end
end

% If dose calculation is not available, throw an error
if calcdose == 0
    if exist('Event', 'file') == 2
        Event(['Neither a local nor remote calculation engine could be ', ...
            'established. Dose calculation is not possible.'], 'ERROR');
    else
        error(['Neither a local nor remote calculation engine could be ', ...
            'established. Dose calculation is not possible.']);
    end
end

% Execute in try/catch statement
try 
 
%% Apply downsampling
% Downsampling factor if set to auto (0).  Dose calculation is known to 
% fail forhigh resolution images sets (when numel > 4e7) due to memory 
% issues on most Accuray research workstations.
if downsample == 0
    if numel(image.data) >= 4e7
        d = 2;
    else
        d = 1;
    end
    
% If not auto, use provided downsampling factor    
else
    d = downsample;
end

%% Verify registration
% If no registration vector was provided, add an empty one
if ~isfield(plan, 'registration')
    plan.registration = [0 0 0 0 0 0];
end

% Throw an error if the image registration pitch or yaw values are non-zero
if plan.registration(1) ~= 0 || plan.registration(2) ~= 0
    if exist('Event', 'file') == 2
        Event(['Dose calculation cannot handle pitch or yaw ', ...
            'corrections at this time'], 'ERROR');
    else
        error(['Dose calculation cannot handle pitch or yaw ', ...
            'corrections at this time']);
    end
end

% Test if the downsample factor is valid
if mod(image.dimensions(1), d) ~= 0
    if exist('Event', 'file') == 2
        Event(['The downsample factor is not an even divisor of the ', ...
            'image dimensions'], 'ERROR');
    else
        error(['The downsample factor is not an even divisor of the ', ...
            'image dimensions']);
    end
end

%% Start dose calculation
% Log beginning of dose calculation and start timer
if exist('Event', 'file') == 2
    Event(sprintf(['Beginning dose calculation using downsampling ', ...
        'factor of %i'], d));
    tic
end

% If new image data was passed, re-create temporary directory, CT .header 
% and .img files, dose.cfg, and copy beam model files
if nargin >= 2
    
    % This temprary directory will be used to store a copy of all dose
    % calculator input files. 
    folder = tempname;

    % Use mkdir to attempt to create folder in temp directory
    [status, cmdout] = system(['mkdir ', folder]);
    
    % If status is 0, the command was successful; otherwise, log an
    % error
    if status > 0
        if exist('Event', 'file') == 2
            Event(['Error creating temporary folder for dose calculation, ', ...
                'system returned the following: ', cmdout], 'ERROR');
        else
            error(['Error creating temporary folder for dose calculation, ', ...
                'system returned the following: ', cmdout]);
        end
    end

    % Log successful completion
    if exist('Event', 'file') == 2
        Event(['Temporary folder created at ', folder]);
    end
    
    % Clear temporary variables
    clear status cmdout;

    %% Write CT.header
    if exist('Event', 'file') == 2
        Event(['Writing ct.header to ', folder]);
    end
    
    % Generate a temporary file on the local computer to store the CT
    % header dose calculator input file.  Then open a write file handle 
    % to the temporary CT header file.
    fid = fopen(fullfile(folder, 'ct.header'), 'w');

    % Write the IVDT values to the temporary ct.header file
    fprintf(fid, 'calibration.ctNums=');
    fprintf(fid, '%i ', image.ivdt(:,1));
    fprintf(fid, '\ncalibration.densVals=');
    fprintf(fid, '%G ', image.ivdt(:,2));

    % Write the dimensions to the temporary ct.header. Note that the x,y,z
    % designation in the dose calculator is not in IEC coordinates; y is
    % actually in the flipped IEC-z direction, while z is in the IEC-y
    % direction.
    fprintf(fid, '\ncs.dim.x=%i\n', image.dimensions(1));
    fprintf(fid, 'cs.dim.y=%i\n', image.dimensions(2));
    fprintf(fid, 'cs.dim.z=%i\n', image.dimensions(3));

    % Since the ct data is from the top row down, include a flipy = true
    % statement.
    fprintf(fid, 'cs.flipy=true\n');

    % Write a list of the IEC-y (dose calculation/CT z coordinate) location
    % of each CT slice. Note that the first bounds starts at
    % image.start(3) - image.width(3)/2 and ends at image.dimensions(3) *
    % image.width(3) + image.start(3) - image.width(3)/2. For n CT slices
    % there should be n+1 bounds.
    fprintf(fid, 'cs.slicebounds=');
    fprintf(fid, '%G ', (0:image.dimensions(3)) * image.width(3) + ...
        image.start(3) - image.width(3)/2);

    % Write the coordinate of the first voxel (top left, since flipy =
    % true). Note that the dose calculator references the start coordinate
    % by the corner of the voxel, while the patient XML references the
    % coordinate by the center of the voxel. Thus, half the voxel
    % dimension must be added (here they are subtracted, as the start
    % coordinates are negative) to the XML start coordinates. These values
    % must be in cm.
    fprintf(fid, '\ncs.start.x=%G\n', image.start(1) - image.width(1)/2);
    fprintf(fid, 'cs.start.y=%G\n', image.start(2) - image.width(2)/2);
    fprintf(fid, 'cs.start.z=%G\n', image.start(3) - image.width(3)/2);

    % Write the voxel widths in all three dimensions.
    fprintf(fid, 'cs.width.x=%G\n', image.width(1));
    fprintf(fid, 'cs.width.y=%G\n', image.width(2));
    fprintf(fid, 'cs.width.z=%G\n', image.width(3));

    % The CT is stationary (not a 4DCT), so list a zero time phase
    fprintf(fid, 'phase.0.theta=0\n');

    % Close file handles
    fclose(fid);

    % Clear temporary variables
    clear fid;

    %% Write ct_0.img
    if exist('Event', 'file') == 2
        Event(['Writing ct_0.img to ', folder]);
    end
    
    % Generate a temporary file on the local computer to store the
    % ct_0.img dose calculator input file (binary CT image). Then open 
    % a write file handle to the temporary ct_0.img file.
    fid = fopen(fullfile(folder, 'ct_0.img'), 'w', 'l');

    % Write in little endian to the ct_0.img file (the dose
    % calculator requires little endian inputs).
    fwrite(fid, reshape(image.data, 1, []), 'uint16', 'l');

    % Close file handle
    fclose(fid);

    % Clear temporary variables
    clear fid;

    %% Write reference dose.cfg
    if exist('Event', 'file') == 2
        Event(['Writing dose.cfg to ', folder]);
    end
    
    % Generate a temporary file on the local computer to store the
    % dose.cfg dose calculator input file. Then open a write file 
    % handle to the temporary file
    fid = fopen(fullfile(folder, 'dose.cfg'), 'w');

    % Write the required dose.cfg dose calculator statments
    fprintf(fid, 'console.errors=true\n');
    fprintf(fid, 'console.info=true\n');
    fprintf(fid, 'console.locate=true\n');
    fprintf(fid, 'console.trace=true\n');
    fprintf(fid, 'console.warnings=true\n');
    fprintf(fid, 'dose.cache.path=/var/cache/tomo\n');

    % Write the dose image x/y dimensions, start coordinates, and voxel
    % sizes based on the CT values (by d). Note that the dose 
    % calculator assumes the z values based on the CT.
    fprintf(fid, 'dose.grid.dim.x=%i\n', image.dimensions(1)/d);
    fprintf(fid, 'dose.grid.dim.y=%i\n', image.dimensions(2)/d);
    fprintf(fid, 'dose.grid.start.x=%G\n', image.start(1) - image.width(1)/2);
    fprintf(fid, 'dose.grid.start.y=%G\n', image.start(2) - image.width(2)/2);
    fprintf(fid, 'dose.grid.width.x=%G\n', image.width(1)*d);
    fprintf(fid, 'dose.grid.width.y=%G\n', image.width(2)*d);

    % Turn on or off supersampling.  When sampleAngleMotion is set to 
    % false, the dose for each projection will be calculated at only one 
    % point (in the center) of the projection.  This will speed up dose 
    % calculation
    if supersample == 1
        fprintf(fid, 'dose.sampleAngleMotion=true\n');
    else
        fprintf(fid, 'dose.sampleAngleMotion=false\n');
    end

    % Reduce the number of azimuthal angles per zenith angle to 4.  This
    % will speed up dose calculation
    fprintf(fid, 'dose.azimuths=%i\n', azimuths);

    % Reduce fluence rate/steps to 1. This will also speed up dose 
    % calculation
    fprintf(fid, 'dose.xRayRate=%i\n', raysteps);
    fprintf(fid, 'dose.zRayRate=%i\n', raysteps);
    
    % If using gpusadose, write nvbb settings
    if sadose == 0
        
        % Turn on or off supersampling
        if supersample == 1
            fprintf(fid, 'nvbb.sourceSuperSample=1\n');
        else
            fprintf(fid, 'nvbb.sourceSuperSample=0\n');
        end
        
        % Reduce the number of azimuthal angles per zenith angle to 4.  
        % This will speed up dose calculation
        fprintf(fid, 'nvbb.azimuths=%i\n', azimuths);

        % Reduce fluence rate/steps to 1. This will also speed up dose 
        % calculation
        fprintf(fid, 'nvbb.fluenceXRate=%i\n', raysteps);
        fprintf(fid, 'nvbb.fluenceZRate=%i\n', raysteps);
        fprintf(fid, 'nvbb.fluenceXStep=%i\n', raysteps);
        fprintf(fid, 'nvbb.fluenceZStep=%i\n', raysteps);
    end
    
    % Configure the dose calculator to write the resulting dose array to
    % the file dose.img (to be read back into MATLAB following execution)
    fprintf(fid, 'outfile=dose.img\n');

    % Close file handles
    fclose(fid);

    % Clear temporary variables
    clear fid;

    %% Load pre-defined beam model PDUT files (dcom, kernel, lft, etc)
    if exist('Event', 'file') == 2
        Event(['Copying beam model files from ', modelfolder, '/ to ', ...
            folder]);
    end

    % The dose calculator also requires the following beam model files.
    % As these files do not change between patients (for the same machine),
    % they are not read from the patient XML but rather stored in the
    % directory stored in modelfolder.
    
    % If the local system is unix-based
    if isunix
        [status, cmdout] = system(['cp ',strrep(fullfile(modelfolder, ...
            '*.*'), ' ', '\ '), ' ', folder, '/']);

    % Otherwise, if Windows
    elseif ispc
        [status, cmdout] = system(['copy "',fullfile(modelfolder, '*.*'), ...
            '" ', folder, '\']);
    end
    
    % If status is 0, cp was successful.  Otherwise, log error
    if status > 0
        if exist('Event', 'file') == 2
            Event(['Error occurred copying beam model files to temporary ', ...
                'directory: ', cmdout], 'ERROR');
        else
            error(['Error occurred copying beam model files to temporary ', ...
                'directory: ', cmdout]);
        end
    end

    % Clear temporary variables
    clear status cmdout;
    
    % If a ssh2 connection exists, copy files to remote computation server
    if exist('ssh2', 'var') && ~isempty(ssh2)
    
        % This temprary directory will be used to store a copy of all dose
        % calculator input files. (note, the remote server's temporary 
        % directory is assumed to be /tmp)
        remotefolder = ['/tmp/', strrep(dicomuid, '.', '_')];

        % Make temporary directory on remote server 
        if exist('Event', 'file') == 2
            Event(['Creating remote directory ', remotefolder]);
        end
        [ssh2, ~] = ssh2_command(ssh2, ['mkdir ', remotefolder]);

        % Get local temporary folder contents
        list = dir(folder);

        % Loop through each local file, copying it to 
        for i = 1:length(list)
            
            % If listing is a valid file, and not a plan file
            if ~strcmp(list(i).name, '.') && ~strcmp(list(i).name, '..') && ...
                    ~strcmp(list(i).name, 'plan.header') && ...
                    ~strcmp(list(i).name, 'plan.img')
                
                % Log copy
                if exist('Event', 'file') == 2
                    Event(['Secure copying file ', list(i).name]);
                end
                
                % Copy file via scp_put
                ssh2 = scp_put(ssh2, list(i).name, remotefolder, folder);
            end
        end
        
        % Clear temporary variables
        clear list i;
    end
end

%% Write plan.header
if exist('Event', 'file') == 2
    Event(['Writing plan.header to ', folder]);
end

% Generate a temporary file on the local computer to store the
% plan.header dose calculator input file. Then open a write file handle 
% to the plan.header temporary file
fid = fopen(fullfile(folder, 'plan.header'), 'w');

% Loop through the events cell array
for i = 1:size(plan.events, 1)
    
    % Write the event tau
    fprintf(fid,'event.%02i.tau=%0.1f\n',[i-1 plan.events{i,1}]);

    % Write the event type
    fprintf(fid,'event.%02i.type=%s\n',[i-1 plan.events{i,2}]);

    % If type is isoX, apply IECX registration adjustment
    if strcmp(plan.events{i,2}, 'isoX')
        
        % Write isoX to plan.header
        fprintf(fid, 'event.%02i.value=%G\n', [i-1 ...
            plan.events{i,3} - plan.registration(4)]);
        
        % If a registration exists, log adjustment
        if plan.registration(4) ~= 0 && exist('Event', 'file') == 2
            Event(sprintf('Applied isoX registration adjustment %G cm', ...
                - plan.registration(4)));
        end

    % Otherwise, if type is isoY, apply IECZ registration adjustment
    elseif strcmp(plan.events{i,2}, 'isoY')
        
        % Write isoY to plan.header
        fprintf(fid, 'event.%02i.value=%G\n', [i-1 ...
            plan.events{i,3} + plan.registration(6)]);
        
        % If a registration exists, log adjustment
        if plan.registration(6) ~= 0 && exist('Event', 'file') == 2
            Event(sprintf('Applied isoY registration adjustment %G cm', ...
                plan.registration(6)));
        end
        
    % Otherwise, if type is isoZ, apply IECY registration adjustment
    elseif strcmp(plan.events{i,2}, 'isoZ')
        
        % Write isoZ to plan.header
        fprintf(fid, 'event.%02i.value=%G\n', [i-1 ...
            plan.events{i,3} - plan.registration(5)]);
        
        % If a registration exists, log adjustment
        if plan.registration(5) ~= 0 && exist('Event', 'file') == 2
            Event(sprintf('Applied isoZ registration adjustment %G cm', ...
                plan.registration(5)));
        end

    % Otherwise, if type is gantryAngle, apply roll registration adjustment
    elseif strcmp(plan.events{i,2}, 'gantryAngle')
        
        % Write gantryAngle to plan.header
        fprintf(fid, 'event.%02i.value=%G\n', [i-1 ...
            plan.events{i,3} + plan.registration(3) * 180/pi]);
        
        % If a registration exists, log adjustment
        if plan.registration(3) ~= 0 && exist('Event', 'file') == 2
            Event(sprintf('Applied roll registration adjustment %G degrees', ...
                plan.registration(3) * 180/pi));
        end

    % Otherwise, if the value is not a placeholder, write the value
    elseif plan.events{i,3} ~= 1.7976931348623157E308
        fprintf(fid, 'event.%02i.value=%G\n', [i - 1 plan.events{i,3}]);
    end
end

% Loop through each leaf (the dose calculator uses zero based indices)
for i = 0:63
    
    % If the leaf is below the lower leaf index, or above the upper
    % leaf index (defined by lower + number of leaves), there are no
    % open projections for this leaf, so write 0
    if i < min(plan.lowerLeafIndex) ...
            || i >= max(plan.lowerLeafIndex + plan.numberOfLeaves)
        fprintf(fid, 'leaf.count.%02i=0\n', i);

    % Otherwise, write n, where n is the total number of projections in
    % the plan (note that a number of them may still be empty/zero)
    else
        fprintf(fid, 'leaf.count.%02i=%i\n', [i plan.totalTau]);
    end
end

% Finally, write the scale value to plan.header
fprintf(fid, 'scale=%G\n', plan.scale);

% Close the file handle
fclose(fid);

% Clear temporary variables
clear i fid;

%% Write plan.img
if exist('Event', 'file') == 2
    Event(['Writing plan.img to ', folder]);
end

% Extend sinogram to full size given start and stopTrim
sinogram = zeros(64, plan.totalTau);
trimmedLengths(2:(length(plan.numberOfProjections)+1)) = ...
    plan.stopTrim - plan.startTrim;
for i = 2:length(trimmedLengths)
    sinogram(:, plan.startTrim(i-1):plan.stopTrim(i-1)) = ...
        plan.sinogram(:,(sum(trimmedLengths(1:i-1))+1):...
        (sum(trimmedLengths(1:i)))+1);
end

% Generate a temporary file on the local computer to store the
% plan.header dose calculator input file.  Then open a write file 
% handle to the plan.img temporary file
fid = fopen(fullfile(folder, 'plan.img'), 'w', 'l');

% Loop through each active leaf (defined by the lower and upper
% indices, above)
for i = min(plan.lowerLeafIndex) + 1:max(plan.lowerLeafIndex + ...
        plan.numberOfLeaves)

    % Loop through the number of projections for this leaf
    for j = 1:size(sinogram, 2)

        % Write open and close events based on the sinogram leaf
        % open time. 0.5 is subtracted to remove the one based indexing
        % and center the open time on the projection.
        fwrite(fid,j - 0.5 - sinogram(i,j)/2, 'double');
        fwrite(fid,j - 0.5 + sinogram(i,j)/2, 'double');
    end
end

% Close the plan.img file handle
fclose(fid);

% Clear temporary variables
clear i j fid sinogram;

%% If using a remote server, copy plan files and execute gpusadose
if exist('ssh2', 'var') && ~isempty(ssh2)
    
    % Copy plan.header using scp_put
    if exist('Event', 'file') == 2
        Event('Secure copying file plan.header');
    end
    ssh2 = scp_put(ssh2, 'plan.header', remotefolder, folder);

    % Copy plan.img using scp_put
    if exist('Event', 'file') == 2
        Event('Secure copying file plan.img');
    end
    ssh2 = scp_put(ssh2, 'plan.img', remotefolder, folder);
    
    % If using gpusadose
    if sadose == 0
        
        % Execute gpusadose in the remote server temporary directory
        if exist('Event', 'file') == 2
            Event('Executing gpusadose on remote server');
        end
        ssh2 = ssh2_command(ssh2, ['cd ', remotefolder, ...
            '; gpusadose -C dose.cfg &>out.txt']);
    
    % Otherwise, if using sadose
    else
        
        % Execute gpusadose in the remote server temporary directory
        if exist('Event', 'file') == 2
            Event('Executing sadose on remote server');
        end
        ssh2 = ssh2_command(ssh2, ['cd ', remotefolder, ...
            '; sadose -C dose.cfg &>out.txt']);
    end
    
    % Retrieve output to the temporary directory on the local computer
    ssh2 = scp_get(ssh2, 'out.txt', folder, remotefolder);
    
    % Read in command output
    cmdout = fileread(fullfile(folder, 'out.txt'));
    
    % Check if an error was encountered
    if ~isempty(regexpi(cmdout, 'ERROR'))
        
        % Log execution output as error
        if exist('Event', 'file') == 2
            Event(cmdout, 'ERROR');
        else
            error(cmdout);
        end
        
    % Otherwise, log output and retrieve image
    else
        
        % Log output
        if exist('Event', 'file') == 2
            Event(cmdout);
        end
        
        % Retrieve dose image to the temporary directory on the local 
        % computer
        if exist('Event', 'file') == 2
            Event('Retrieving calculated dose image from remote direcory');
        end
        ssh2 = scp_get(ssh2, 'dose.img', folder, remotefolder);
    end
    
    % Clear temporary variables
    clear cmdout;
    
%% Otherwise execute gpusadose locally
else
    
    % If using gpusadose
    if sadose == 0

        % If the system is unix-based
        if isunix
            
            % cd to temporary folder, then call gpusadose
            if exist('Event', 'file') == 2
                Event(['Executing gpusadose -C ', folder,'/dose.cfg']);
            end
            [status, cmdout] = ...
                system(['cd ', folder, '; gpusadose -C ./dose.cfg']);
        
        % Otherwise, if Windows
        elseif ispc
            
            % cd to temporary folder, then call gpusadose
            if exist('Event', 'file') == 2
                Event(['Executing gpusadose.exe -C ', folder,'\dose.cfg']);
            end
            [status, cmdout] = ...
                system(['cd ', folder, '; gpusadose.exe -C .\dose.cfg']);
        end
        
    % Otherwise, if using sadose
    else
        
        % If the system is unix-based
        if isunix
            
            % cd to temporary folder, then call gpusadose
            if exist('Event', 'file') == 2
                Event(['Executing sadose -C ', folder,'/dose.cfg']);
            end
            [status, cmdout] = ...
                system(['cd ', folder, '; sadose -C ./dose.cfg']);
        
        % Otherwise, if Windows
        elseif ispc
            
            % cd to temporary folder, then call gpusadose
            if exist('Event', 'file') == 2
                Event(['Executing sadose.exe -C ', folder,'\dose.cfg']);
            end
            [status, cmdout] = ...
                system(['cd ', folder, '; sadose.exe -C .\dose.cfg']);
        end
        
    end
    
    % If status is 0, the gpusadose call was successful.
    if status > 0
        
        % Log output as error
        if exist('Event', 'file') == 2
            Event(cmdout, 'ERROR');
        else
            error(cmdout);
        end
        
    % Otherwise, an error was returned from the system call
    elseif exist('Event', 'file') == 2
        
        % Log output not as an error
        Event(cmdout);
    end

    % Clear temporary variables
    clear status cmdout;
end

%% Read in dose image
% Open a read file handle to the dose image
fid = fopen(fullfile(folder, 'dose.img'), 'r');

% If a valid file handle is returned
if fid >= 3

    % Log event
    if exist('Event', 'file') == 2
        Event(['Reading dose.img from ', folder]);
    end

    % Read the dose image into tempdose
    tempdose = reshape(fread(fid, image.dimensions(1)/d * ...
        image.dimensions(2)/d * image.dimensions(3), 'single', ...
        0, 'l'), image.dimensions(1)/d, ...
        image.dimensions(2)/d, image.dimensions(3));

    % Close file handle
    fclose(fid);

    % Clear file handle
    clear fid;

    % Initialize dose.data array
    dose.data = zeros(image.dimensions);

    % Since the downsampling is only in the axial plane, loop through each 
    % IEC-Y slice
    if d > 1

        % Log interpolation step
        if exist('Event', 'file') == 2
            Event(sprintf(['Upsampling calculated dose image by %i using ', ...
                'nearest neighbor interpolation'], d));
        end

        % Loop through each axial dose slice
        for i = 1:image.dimensions(3)

            % Upsample dataset back to CT resolution using nearest neighbor
            % interpolation.  
            dose.data(:,:,i) = interp2(tempdose(:,:,i), ...
                0.4999+1/d:1/d:image.dimensions(2)/d+0.4999, ...
                (0.4999+1/d:1/d:image.dimensions(1)/d+0.4999)', 'nearest');
        end

        % Replicate the first and last rows and columns (since they are not 
        % interpolated)
        dose.data(1:d/2, :, :) = repmat(dose.data(d/2+1, :, :), d/2, 1, 1);
        dose.data(:, 1:d/2, :) = repmat(dose.data(:, d/2+1, :), 1, d/2, 1);
        dose.data(end-d/2+1:end, :, :) = ...
            repmat(dose.data(end-d/2, :, :), d/2, 1, 1);
        dose.data(:, end-d/2+1:end, :) = ...
            repmat(dose.data(:, end-d/2, :), 1, d/2, 1);
    else
        % If no downsampling occurred, simply copy tempdose
        dose.data = tempdose;
    end

    % Clear temporary variables
    clear i tempdose d;

    % Copy dose image start, width, and dimensions from CT image
    dose.start = image.start;
    dose.width = image.width;
    dose.dimensions = image.dimensions;

    % Log dose calculation completion
    if exist('Event', 'file') == 2
        Event(sprintf('Dose calculation completed in %0.3f seconds', toc));
    end
    
% Otherwise, no dose was computed    
else
    
    % Log failure
    if exist('Event', 'file') == 2
        Event('CalcDose failed to compute dose', 'ERROR');
    else
        error('CalcDose failed to compute dose');
    end
    
    % Return empty dose
    dose = [];
end
    
% Catch errors, log, and rethrow
catch err
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end
