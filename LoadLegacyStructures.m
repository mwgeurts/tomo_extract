function structures = LoadLegacyStructures(varargin)
% LoadLegacyStructures loads transverse reference structure sets given a 
% reference image UID and creates mask arrays for each structure.  It is 
% identical in function to LoadStructures but is compatible with version 
% 2.X and earlier archives.
%
% The following variables are required for proper execution: 
%   varargin{1}: path to the patient archive XML file
%   varargin{2}: name of patient XML file in path
%   varargin{3}: structure of reference image.  Must include a 
%       structureSetUID field referencing structure set, as well as 
%       dimensions, width, and start fields
%   varargin{4} (optional): cell array of atlas names, include/exclude 
%       regex statements, and load flags (if zero, matched structures will 
%       not be loaded). If not provided, all structures will be loaded
%
% The following variables are returned upon succesful completion:
%   structures: cell array of structure names, color, width, start, 
%       dicmensions, and 3D mask array of same size as reference image 
%       containing fraction of voxel inclusion in structure
%     
% Below is an example of how this function is used:
%
%   path = '/path/to/archive/';
%   name = 'Anon_0001_patient.xml';
%   planUID = '1.2.826.0.1.3680043.2.200.1688035198.217.40463.657';
%   image = LoadLegacyImage(path, name, planUID);
%   atlas = LoadAtlas('atlas.xml');
%   structures = LoadLegacyStructures(path, name, image, atlas);
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
    
% Log start of plan load and start timer
if exist('Event', 'file') == 2
    Event(sprintf('Generating structure masks from %s for %s', varargin{2}, ...
        varargin{3}.structureSetUID));
    tic;
end

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node to doc
doc = xmlread(fullfile(varargin{1}, varargin{2}));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Search for structure sets associated with the structure set UID
expression = xpath.compile(['//fullPlanDataArray/fullPlanDataArray/', ...
    'plan/planStructureSet']);

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);  

% Initialize structure set counter
n = 0;

% Initialize return variable
structures = cell(0);

% Loop through the structure sets
for i = 1:nodeList.getLength
    
    % Set a handle to the current result
    node = nodeList.item(i-1);

    %% Verify database UID
    % Search for database UID
    subexpression = xpath.compile('dbInfo/databaseUID');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Store the first returned value
    subnode = subnodeList.item(0);

    % If this UID does not equal the structure set UID, continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), ...
            varargin{3}.structureSetUID)
        continue
    end
    
    %% Load structures
    % Search for roiLists
    subexpression = xpath.compile('roiList/roiList');
    
    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);
    
    % Loop through the roiLists
    for j = 1:subnodeList.getLength

        % Set a handle to the current result
        subnode = subnodeList.item(j-1);
        
        %% Load structure name
        % Search for structure set name
        subsubexpression = xpath.compile('name');

        % Evaluate xpath expression and retrieve the results
        subsubnodeList = ...
            subsubexpression.evaluate(subnode, XPathConstants.NODESET);

        % Store the first returned value
        subsubnode = subsubnodeList.item(0);

        % Store the structure name as a char array
        name = char(subsubnode.getFirstChild.getNodeValue);

        % Initialize load flag.  If this structure name matches a structure 
        % in the provided atlas with load set to false, this structure will 
        % not be loaded
        load = true;
        
        %% Compare name to atlas
        if nargin == 4

            % Loop through each atlas structure
            for k = 1:size(varargin{4}, 2)

                % Compute the number of include atlas REGEXP matches
                in = regexpi(name,varargin{4}{k}.include);

                % If the atlas structure also contains an exclude REGEXP
                if isfield(varargin{4}{k}, 'exclude') 

                    % Compute the number of exclude atlas REGEXP matches
                    ex = regexpi(name,varargin{4}{k}.exclude);
                else
                    % Otherwise, return 0 exclusion matches
                    ex = [];
                end

                % If the structure matched the include REGEXP and not the
                % exclude REGEXP (if it exists)
                if size(in,1) > 0 && size(ex,1) == 0

                    % Set the load flag based on the matched atlas 
                    % structure
                    load = varargin{4}{k}.load;

                    % Stop the atlas for loop, as the structure was matched
                    break;
                end
            end

            % Clear temporary variables
            clear in ex;
        end

        % If the load flag is still set to true
        if load

            % Increment counter
            n = n + 1;

            % Add a new cell array and set name structure field
            structures{n}.name = name; %#ok<*AGROW>
            
            %% Load structure color
            % Search for structure set red color
            subsubexpression = xpath.compile('color/red');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store red color in return cell array
            structures{n}.color(1) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for structure set green color
            subsubexpression = xpath.compile('color/green');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store green color in return cell array
            structures{n}.color(2) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);

            % Search for structure set blue color
            subsubexpression = xpath.compile('color/blue');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store blue color in return cell array
            structures{n}.color(3) = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
            
            %% Load density override information
            % Search for structure set density override flag
            subsubexpression = xpath.compile('isDensityOverridden');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store density override flag in return cell array as char
            structures{n}.isDensityOverridden = ...
                char(subsubnode.getFirstChild.getNodeValue);

            %% Load density override
            % Search for structure set override density
            subsubexpression = xpath.compile('overriddenDensity');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store override density in return cell array
            structures{n}.overriddenDensity = ...
                str2double(subsubnode.getFirstChild.getNodeValue);
            
            %% Load curve filename
            % Search for structure set curve data file
            subsubexpression = xpath.compile('curveDataFile');

            % Evaluate xpath expression and retrieve the results
            subsubnodeList = ...
                subsubexpression.evaluate(subnode, XPathConstants.NODESET);

            % If no curve data file was found, this structure may not 
            % contain any contours
            if subsubnodeList.getLength == 0

                % Clear structure
                structures{n} = [];

                % Reduce counter
                n = n - 1;

                % Continue to next structure
                continue
            end

            % Store the first returned value
            subsubnode = subsubnodeList.item(0);

            % Store full file path to return cell array
            structures{n}.filename = fullfile(varargin{1}, ...
                char(subsubnode.getFirstChild.getNodeValue));

        % Otherwise, the load flag was set to false during atlas matching
        elseif exist('Event', 'file') == 2

            % Notify user that this structure was skipped
            Event(['Structure ', name, ' matched exclusion list from atlas', ...
                ' and will not be loaded']);
        end
    end
    
    % Structure set was found, so break for loop to stop searching
    break;
end

% Clear temporary variables
clear i j name load node subnode subsubnode nodeList subnodeList ...
    subsubnodeList expression subexpression subsubexpression doc;

% Log how many structures were discovered
if exist('Event', 'file') == 2
    Event(sprintf('%i structures matched atlas for %s', n, ...
        varargin{3}.structureSetUID));
end

% Loop through the structures discovered
for i = 1:n
    
    % Generate empty logical mask of the same image size as the reference
    % image (see LoadReferenceImage for more information)
    structures{i}.mask = false(varargin{3}.dimensions); 
    
    % Inititalize structure volume
    structures{i}.volume = 0;
    
    % Read structure set XML and store the Document Object Model node
    doc = xmlread(structures{i}.filename);
    
    % Search for pointdata arrays
    expression = xpath.compile('//pointData');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET);  
    
    % If not pointData nodes found, warn user and stop execution
    if nodeList.getLength == 0
        if exist('Event', 'file') == 2
            Event(['Incorrect file structure found in ', ...
                structures{i}.filename], 'ERROR');
        else
            error(['Incorrect file structure found in ', ...
                structures{i}.filename]);
        end
    end
    
    % Log contour being loaded
    if exist('Event', 'file') == 2
        Event(sprintf('Loading structure %s (%i curves)', ...
            structures{i}.name, nodeList.getLength));
    end
    
    % Initialize points cell array
    structures{i}.points = cell(nodeList.getLength, 1);
    
    % Loop through ROICurves
    for j = 1:nodeList.getLength
        
       % Set a handle to the current result
        subnode = nodeList.item(j-1); 

        % Read in the number of points in the curve
        numpoints = str2double(subnode.getAttribute('numDataPoints'));
        
        % Some curves have zero points, so skip them
        if numpoints > 0
            
            % Read in curve points
            points = str2num(subnode.getFirstChild.getNodeValue); %#ok<ST2NM>
            
            % Determine slice index by searching IEC-Y index using nearest
            % neighbor interpolation
            slice = interp1(varargin{3}.start(3):varargin{3}.width(3):...
                varargin{3}.start(3) + (varargin{3}.dimensions(3) - 1) * ...
                varargin{3}.width(3), 1:varargin{3}.dimensions(3), ...
                points(1,3), 'nearest', 0);
        
            % If the slice index is within the reference image
            if slice ~= 0

                % Test if voxel centers are within polygon defined by point 
                % data, adding result to structure mask.  Note that voxels 
                % encompassed by even numbers of curves are considered to 
                % be outside of the structure (ie, rings), as determined 
                % by the addition test below
                mask = poly2mask((points(:,2) - varargin{3}.start(2)) / ...
                    varargin{3}.width(2) + 1, (points(:,1) - ...
                    varargin{3}.start(1)) / varargin{3}.width(1) + 1, ...
                    varargin{3}.dimensions(1), varargin{3}.dimensions(2));
                
                % If the new mask will overlap an existing value, subtract
                if max(max(mask + structures{i}.mask(:,:,slice))) == 2
                    structures{i}.mask(:,:,slice) = ...
                        structures{i}.mask(:,:,slice) - mask;
                  
                % Otherwise, add it to the mask
                else
                    structures{i}.mask(:,:,slice) = ...
                        structures{i}.mask(:,:,slice) + mask;
                end
                
            % Otherwise, the contour data exists outside of the IEC-y 
            elseif exist('Event', 'file') == 2
                
                % Warn the user that the contour did not match a slice
                Event(['Structure ', structures{i}.name, ...
                    ' contains contours outside of image array'], 'WARN');
            end
            
            % Store raw points, applying rotation vector to convert to
            % DICOM coordinate system
            structures{i}.points{j} = points .* ...
                repmat([1,-1,-1], size(points,1), 1);
        end
    end
    
    % Compute volumes from mask (note, this will differ from the true
    % volume as partial voxels are not considered
    structures{i}.volume = sum(sum(sum(structures{i}.mask))) * ...
        prod(varargin{3}.width);
    
    % Flip the structure mask in the first dimension
    structures{i}.mask = fliplr(structures{i}.mask);
    
    % Copy structure width, start, and dimensions arrays from image
    structures{n}.width = varargin{3}.width;
    structures{n}.start = varargin{3}.start;
    structures{n}.dimensions = varargin{3}.dimensions;
    
    % Check if at least one voxel in the mask was set to true
    if max(max(max(structures{i}.mask))) == 0
        
        % If not, warn the user that the mask is empty
        if exist('Event', 'file') == 2
            Event(['Structure ', structures{i}.name, ...
                ' is less than one voxel.'], 'WARN');
        end
        
        % Clear structure from return variable
        structures{i} = [];
    end
end

% Remove empty structure fields
structures = structures(~cellfun('isempty', structures));

% Clear temporary variables
clear n doc factory xpath expression nodeList subNode numpoints points ...
    slice mask;

% Log completion of function
if exist('Event', 'file') == 2
    Event(sprintf('Structure load completed in %0.3f seconds', toc));
end

% Catch errors, log, and rethrow
catch err
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end

