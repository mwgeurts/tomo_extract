function ivdt = FindIVDT(path, id, type)
% FindIVDT searches for the IVDT associated with a daily image, reference
% image, or machine.  If 'MVCT', the calibration UID provided is searched 
% for in the machine archive, and the corresponding IVDT is returned.  If 
% 'TomoPlan', the IVDT UID is the correct value, the IVDT is loaded for 
% that value.  If 'TomoMachine', the machine archive is parsed for the most 
% recent imaging equipment and the UID is returned.
%
% If the UID was not found, and the Java runtime environment exists, the
% user will be prompted to select an IVDT from the list of IVDTs in the
% archive.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   id: identifier, dependent on type. If MVCT, id should be the delivered 
%       machine calibration UID; if TomoPlan, shound be the full dose IVDT 
%       UID; if 'TomoMachine', should be the machine name
%   type: type of UID to extract IVDT for.  Can be 'MVCT', 'TomoPlan', or 
%       'TomoMachine'. 
%
% The following variables are returned upon succesful completion:
%   ivdt: n-by-2 array of associated CT number/density pairs
%
% Below is an example of how this function is used:
%   
%   path = '/path/to/archive/';
%   id = '1.2.826.0.1.3680043.2.200.1693609359.434.30969.2213';
%   ivdt = FindIVDT(path, id, 'TomoPlan');
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

%% Find imaging equipment UID
% Initialize imagingUID temporary string and empty return array
imagingUID = '';
ivdt = [];

% Start timer
tic;

% Choose code block to run based on type provided
switch type

% If type is MVCT
case 'MVCT'
    
    % Log start of search for MVCT IVDT
    if exist('Event', 'file') == 2
        Event('Beginning search for MVCT IVDT');
    end
    
    % Search for all machine XMLs in the patient archive folder
    machinelist = dir(fullfile(path, '*_machine.xml'));
    
    % Log location of xml path
    if exist('Event', 'file') == 2
        Event(sprintf('Searching for machine archives in %s', path));
    end
    
    % The machine XML is parsed using xpath class
    import javax.xml.xpath.*

    % Loop through the machine XMLs
    for i = 1:size(machinelist,1)
        
        % Read in the Machine XML and store the Document Object Model node
        doc = xmlread(fullfile(path, machinelist(i).name));
        
        % Log the machine xml being searched
        if exist('Event', 'file') == 2
            Event(sprintf('Initializing XPath instance for %s', ...
                machinelist(i).name));
        end
        
        % Initialize a new xpath instance to the variable factory
        factory = XPathFactory.newInstance;
        
        % Initialize a new xpath to the variable machinexpath
        xpath = factory.newXPath;
        
        % Log start of calibration array search
        if exist('Event', 'file') == 2
            Event(['Searching for calibration records in ', ...
                machinelist(i).name]);
        end

        % Search for the correct machine calibration array
        expression = xpath.compile('//calibrationArray/calibrationArray');
        
        % Evaluate xpath expression and retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET); 
        
        % If no calibration array was found, it is possible this file is 
        % not a machine equipment archive, so skip to the next result
        if nodeList.getLength == 0
            
            % Warn user that no calibration arrays were found in machine
            % archive
            if exist('Event', 'file') == 2
                Event(sprintf('No calibration data found in %s', ...
                    machinelist(i).name), 'WARN');
            end
            
            % Continue to next result
            continue;
          
        % Otherwise, log result
        elseif exist('Event', 'file') == 2
            
            % Log number of calibration arrays found
            Event(sprintf('%i calibration records found', ...
                nodeList.getLength)); 
        end
        
        % Loop through the results
        for j = 1:nodeList.getLength
            
            % Set a handle to the current result
            node = nodeList.item(j-1);

            % Search for calibration UID
            subexpression = xpath.compile('dbInfo/databaseUID');

            % Evaluate xpath expression and retrieve the results
            subnodeList = subexpression.evaluate(node, ...
                XPathConstants.NODESET);
            subnode = subnodeList.item(0);
            
            % If the calibration matches uid, search for the
            % defaultImagingEquiment
            if strcmp(char(subnode.getFirstChild.getNodeValue), id) == 0
                
                % Continue to next search result
                continue
            else
                
                % Search for calibration UID
                subexpression = ...
                    xpath.compile('defaultImagingEquipmentUID');
                

                % Evaluate xpath expression and retrieve the results
                subnodeList = subexpression.evaluate(node, ...
                    XPathConstants.NODESET);
                
                % If the defaultImagingEquipmentUID is not empty
                if subnodeList.getLength > 0
                    
                    % Log event
                    if exist('Event', 'file') == 2
                        Event(sprintf('Found calibration data UID %s', id));
                    end
                    
                    % Retrieve value
                    subnode = subnodeList.item(0);

                    % Set imagingUID to the defaultImagingEquipmentUID XML
                    % parameter value
                    imagingUID = char(subnode.getFirstChild.getNodeValue);

                    % Log the imagingUID
                    if exist('Event', 'file') == 2
                        Event(sprintf('Set imaging equipment UID to %s', ...
                            imagingUID));
                    end
                
                    % Since the correct IVDT was found, break the for loop
                    break;  
                end
            end
        end
        
        % Since the correct IVDT was found, break the for loop
        break;
    end
    
    % Clear temporary xpath variables
    clear fid i j doc factory expression subexpression node ...
        nodeList subnode subnodeList machineList;
    
% Otherwise, if type is TomoPlan
case 'TomoPlan'
    
    % UID passed to FindIVDT is imaging equipment, so this one's easy
    imagingUID = id;
    
% Otherwise, if type is TomoMachine
case 'TomoMachine'
    
    % Log start of IVDT search
    if exist('Event', 'file') == 2
        Event('Beginning search for most recent machine IVDT');
    end
    
    % Search for all machine XMLs in the patient archive folder
    machinelist = dir(fullfile(path, '*_machine.xml'));
    
    % Log location of xml path
    if exist('Event', 'file') == 2
        Event(sprintf('Searching for machine archives in %s', path));
    end
    
    % The machine XML is parsed using xpath class
    import javax.xml.xpath.*

    % Initialize most recent calibration timestamp
    timestamp = 0;
     
    % Loop through the machine XMLs
    for i = 1:size(machinelist,1)
        
        % Read in the Machine XML and store the Document Object Model node
        doc = xmlread(fullfile(path, machinelist(i).name));
        
        % Log machine xml being searched
        if exist('Event', 'file') == 2
            Event(sprintf('Initializing XPath instance for %s', ...
                machinelist(i).name));
        end
        
        % Initialize a new xpath instance to the variable factory
        factory = XPathFactory.newInstance;
        
        % Initialize a new xpath to the variable xpath
        xpath = factory.newXPath;

        % Declare new xpath search for the correct machine name
        expression = xpath.compile('//machine/briefMachine/machineName');
        
        % Evaluate xpath expression and retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET); 
        
        % If no machine name was found, it is possible this file is 
        % not a machine equipment archive, so skip to the next result
        if nodeList.getLength == 0
            
            % Warn user that a machine XML without a machine name exists
            if exist('Event', 'file') == 2
                Event(sprintf('No machine name found in %s', ...
                    machinelist(i).name), 'WARN');
            end
            
            % Continue to next result
            continue
        else
            
            % Otherwise, retrieve result
            node = nodeList.item(0);
            
            % If the machine name does not match, skip to next result
            if ~strcmp(char(node.getFirstChild.getNodeValue), id)
                continue
            end
            
            % Otherwise, the correct machine was found
            if exist('Event', 'file') == 2
                Event(['Machine archive found for ', id]); 
            end
        end
        
        % Log start of calibration array search
        if exist('Event', 'file') == 2
            Event(['Searching for calibration records in ', ...
                machinelist(i).name]);
        end
        
        % Declare new xpath search for all machine calibration arrays
        expression = xpath.compile('//calibrationArray/calibrationArray');
        
        % Evaluate xpath expression and retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET); 
        
        % If no calibration array was found, it is possible this file is 
        % not a machine equipment archive, so skip to the next result
        if nodeList.getLength == 0
            
            % Warn user that no calibration arrays were found in machine
            % archive
            if exist('Event', 'file') == 2
                Event(sprintf('No calibration data found in %s', ...
                    machinelist(i).name), 'WARN');
            end
            
            % Continue to next result
            continue;
            
        % Otherwise log results
        elseif exist('Event', 'file') == 2
            
            % Log number of calibration records found
            Event(sprintf('%i calibration records found', ...
                nodeList.getLength)); 
        end
        
        % Loop through the results
        for j = 1:nodeList.getLength
            
            % Set a handle to the current result
            node = nodeList.item(j-1);

            % Declare new xpath search expression for calibration date
            subexpression = xpath.compile('dbInfo/creationTimestamp/date');

            % Evaluate xpath expression and retrieve the results
            subnodeList = subexpression.evaluate(node, ...
                XPathConstants.NODESET);
            
            % Store the first returned value
            subnode = subnodeList.item(0);
            
            % Store date multiplied by 1e6
            date = str2double(subnode.getFirstChild.getNodeValue) * 1e6;
            
            % Declare new xpath search expression for calibration time
            subexpression = xpath.compile('dbInfo/creationTimestamp/time');

            % Evaluate xpath expression and retrieve the results
            subnodeList = subexpression.evaluate(node, ...
                XPathConstants.NODESET);
            
            % Store the first returned value
            subnode = subnodeList.item(0);
            
            % Add time to date
            date = date + str2double(subnode.getFirstChild.getNodeValue);
            
            % If the current calibration data is not the most recent
            if date < timestamp
                % Continue to next result
                continue
                
            % Otherwise, search for UID
            else
                % Update timestamp to current calibration array
                timestamp = date;
                
                % Search for calibration UID
                subexpression = xpath.compile('defaultImagingEquipmentUID');
                
                % Evaluate xpath expression and retrieve the results
                subnodeList = subexpression.evaluate(node, ...
                    XPathConstants.NODESET);
                
                % If no defaultImagingEquipment was found, continue
                if subnodeList.getLength == 0
                    continue
                else
                    % Otherwise, retrieve result
                    subnode = subnodeList.item(0);

                    % If the defaultImagingEquipmentUID contains a
                    % placeholder, continue
                    if strcmp(char(subnode.getFirstChild.getNodeValue), ...
                            '* * * DO NOT CHANGE THIS STRING VALUE * * *')
                        continue
                    end
                    
                    % Otherwise, set the imagingUID to this one (it may be 
                    % updated if a newer calibration data array is found)
                    imagingUID = char(subnode.getFirstChild.getNodeValue);
                end
            end
        end
        
        % Inform user which imaging equipment was found
        if exist('Event', 'file') == 2
            Event(sprintf('Set imaging equipment UID to %s', imagingUID));
        end
        
        % Since the correct machine was found, break the for loop
        break;
    end
    
    % Clear temporary xpath variables
    clear fid i j doc factory expression subexpression node ...
        nodeList subnode subnodeList date timestamp machineList;
    
% Otherwise, an incorrect type was passed    
otherwise    
    if exist('Event', 'file') == 2
        Event('Incorrect type passed to FindIVDT', 'ERROR');
    else
        error('Incorrect type passed to FindIVDT');
    end
end

% If no matching imaging equipment was found, notify user
if strcmp(imagingUID, '')
    if exist('Event', 'file') == 2
        Event('An imaging equipment UID was not found', 'WARN');
    else
        warning('An imaging equipment UID was not found');
    end
end

%% Search Imaging Archives
% Initialize IVDT match id
s = 0;

% Notify user that imaging archives are now being searched
if exist('Event', 'file') == 2
    Event(sprintf('Searching %s for imaging equipment archives', path));
end

% Search for all imaging equipment XMLs in the patient archive folder
ivdtlist = dir(fullfile(path,'*_imagingequipment*.xml'));
ivdtnames = cell(0);

% Loop through the image equipment XMLs
for i = 1:size(ivdtlist,1)
    
    % Read in the IVDT XML and store the Document Object Model node to doc
    doc = xmlread(fullfile(path, ivdtlist(i).name));

    % Initialize a new xpath instance to the variable factory
    factory = XPathFactory.newInstance;

    % Initialize a new xpath to the variable xpath
    xpath = factory.newXPath;

    % Declare new xpath search expression for correct IVDT
    expression = xpath.compile('//imagingEquipment/dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    nodeList = expression.evaluate(doc, XPathConstants.NODESET); 

    % If no database UID was found, it is possible this file is not
    % an imaging equipment archive, so skip to the next result
    if nodeList.getLength == 0
        
        % Warn user that an imaging equipment XML was found without a
        % database UID
        if exist('Event', 'file') == 2
            Event(sprintf('No database UID found in %s', ivdtlist(i).name), ...
                'WARN');
        end
        
        % Continue to next result
        continue;
    end
    
    % Parse out name from filename
    [~, ivdtnames{length(ivdtnames)+1}, ~] = fileparts(ivdtlist(i).name);

    % Retrieve a handle to the databaseUID result
    node = nodeList.item(0);

    % If the UID does not match the deliveryPlan IVDT UID, this is not 
    % the correct imaging equipment, so continue to next result
    if strcmp(char(node.getFirstChild.getNodeValue), imagingUID)
        
        % Notify the user that a matching UID was found
        if exist('Event', 'file') == 2
            Event(sprintf('Matched IVDT UID %s in %s', ...
                imagingUID, ivdtlist(i).name));
        end
        
        % Store matched IVDT 
        s = i;
        
        % Since the correct IVDT was found, break the for loop
        break;
        
    % Otherwise, continue to next result    
    else
        continue;
    end
end

% If no IVDT was found
if s == 0 && size(ivdtlist,1) > 0
    
    % If a valid screen size is returned (MATLAB was run without -nodisplay)
    if usejava('jvm') && feature('ShowFigureWindows')
    
        % Ask the user to select an IVDT
        [s, ~] = listdlg('PromptString', ['A matching IVDT was not found. ', ...
            'Select an equivalent IVDT:'], 'SelectionMode', 'single', ...
            'ListSize', [250 100], 'ListString', ivdtnames);
    
    end
    
    % If no IVDT is still selected (Java is not available or the user did 
    % not select an IVDT)
    if s == 0
        
        % Throw an error
        if exist('Event', 'file') == 2
            Event(sprintf('A matching IVDT was not found for UID %s', ...
                imagingUID), 'ERROR');
        else
            error('A matching IVDT was not found for UID %s', imagingUID);
        end
    end
   
% Otherwise, if no imaging archives were found
elseif size(ivdtlist,1) == 0
    
    % Throw an error
    if exist('Event', 'file') == 2
        Event(sprintf('An IVDT was not found for UID %s', ...
            imagingUID), 'ERROR');
    else
        error('An IVDT was not found for UID %s', imagingUID);
    end
end

%% Load IVDT from Imaging Archive
% Read in the IVDT XML and store the Document Object Model node to doc
doc = xmlread(fullfile(path, ivdtlist(s).name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Declare new xpath search expression for sinogram file
expression = xpath.compile(...
    '//imagingEquipment/imagingEquipmentData/sinogramDataFile');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Store the first returned value
node = nodeList.item(0);

% Store the path to the IVDT sinogram (data array)
ivdtsin = fullfile(path,char(node.getFirstChild.getNodeValue));

% Declare new xpath search for the IVDT sinogram's dimensions
expression = xpath.compile(...
    '//imagingEquipment/imagingEquipmentData/dimensions/dimensions');

% Evaluate xpath expression and retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);           

% Store the first returned value
node = nodeList.item(0);

% Store the IVDT x dimensions 
ivdtdim(1) = str2double(node.getFirstChild.getNodeValue);

% Store the first returned value
node = nodeList.item(1);

% Store the IVDT y dimensions
ivdtdim(2) = str2double(node.getFirstChild.getNodeValue);

% Open a file handle to the IVDT sinogram, using binary mode
fid = fopen(ivdtsin,'r','b');

% Read the sinogram as single values, using the dimensions
% determined above
ivdt = reshape(fread(fid, ivdtdim(1)*ivdtdim(2), ...
    'single'), ivdtdim(1), ivdtdim(2));

% Close the file handle
fclose(fid);

%% Finish up
% Clear temporary variables
clear fid node nodeList expression ivdtdim ivdtsin ivdtlist doc ...
    factory xpath ivdtmatch;

% Log completion of search
if exist('Event', 'file') == 2
    Event(sprintf('IVDT data retrieved for %s in %0.3f seconds', ...
        imagingUID, toc));
end

% Catch errors, log, and rethrow
catch err
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end
    
% Clear temporary variable
clear imagingUID;
