function data = ParseDetData(filename)
% ParseDetData is a function that exctracts the dose1, dose2, and detector
% data from a compressed TomoTherapy Detector Data file (detdata.dat).
% This function will display a progress bar while it loads (unless MATLAB 
% was executed with the -nodisplay, -nodesktop, or -noFigureWindows flags).
% The following terminal commands are used to download the detector data 
% file from the DRS following delivery:
%
% ftp drs
% bin
% cd /sd0a
% get detData.dat
% quit
%
% The following variables are required for proper execution: 
%   filename: string containing the path and filename to the detector data
%
% The following variables are returned upon succesful completion:
%   data: structure containing timedate, views, dose1, dose2, cone, and
%       detdata fields. dose1, dose2, and cone are vectors (views x 1), 
%       while detdata is an array (views x 640)
%
% Below is an example of how this function is used:
%
%   data = ParseDetData('./Treat_3_J48_detData.dat');
%   figure;
%   imagesc(data.detdata);
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2012 University of Wisconsin Board of Regents
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
    Event(sprintf('Parsing detector data file %s', filename));
    tic;
end

% If a valid screen size is returned (MATLAB was run without -nodisplay)
if usejava('jvm') && feature('ShowFigureWindows')
    
    % Start waitbar
    progress = waitbar(0, 'Parsing detector data file');
end

% Attempt to open read handle to file
fid = fopen(filename, 'r', 'l');

% If file handle was unsuccessful
if fid < 3
    
    % Throw an error
    if exist('Event', 'file') == 2
        Event(sprintf('Unable to open file %s', filename), 'ERROR');
    else  
        error('Unable to open file %s', filename);
    end
end

% Read time and date of DAS data, converting to CST
time = fread(fid, 1, 'uint32');
time = time / 60 / 60 / 24 + datenum('01-Jan-1970 00:00:00');
time = time - 6/24;
data.timedate = datestr(time);

% Read number of projections
data.views = fread(fid, 1, 'int32');
if exist('Event', 'file') == 2
    Event(sprintf('Reading %i views from file', data.views));
end

% Initialize return variables
data.detdata = zeros(data.views, 640);
data.dose1 = zeros(data.views, 1);
data.dose2 = zeros(data.views, 1);

% Skip remainder of header data to start of view data
fseek(fid, 12, -1);

% Loop through views
for i = 1:data.views

    % Update waitbar
    if exist('progress', 'var') && ishandle(progress)
        waitbar(i/data.views, progress);
    end
    
    % Skip to Dose1
    fseek(fid, 140, 0);
    
    % Read Dose1 and Dose2
    data.dose1(i) = fread(fid, 1, 'float');
    data.dose2(i) = fread(fid, 1, 'float');

    % Skip to detector data
    fseek(fid, 192, 0);
    
    % Read 640 channels of detector data
    data.detdata(i, :) = fread(fid, 640, 'float');

    % Skip to next view
    fseek(fid, 172, 0);
end

% Compute cone (dose2/dose1)
data.cone = data.dose2 ./ data.dose1;

% Close file handle
fclose(fid);

% Clear temporary variables
clear i fid time;

% Close waitbar
if exist('progress', 'var') && ishandle(progress)
    close(progress);
end

% Catch errors, log, and rethrow
catch err
    
    % Delete progress handle if it exists
    if exist('progress', 'var') && ishandle(progress), delete(progress); end
    
    % Log error
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end