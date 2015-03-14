function varargout = IndexLibrary(version, directory)
% IndexLibrary scans an given directory for patient archives, storing a
% summary of results in the file PatientLibraryIndex.xml within the same 
% directory.  When called again, it will re-index the directory, generating 
% a new index file.  A DOM node of the library contents is also optionally 
% returned.
%
% The library documents the following attributes for each approved plan:
% approved plan trial UID, plan label, timestamp, study UID, plan UID, and
% archive path.
%
% The following variables are required for proper execution: 
%   version: string containing theversion of the parent application, This
%       version will be saved to the index file
%   directory: string containing the location of the patient directory
%
% The following variables are returned upon succesful completion:
%   docNode (optional): Document Object Model node containing the library
%
% Below is an example of how this function is used:
%
%   % Create new library index file
%   IndexLibrary('1.0', 'path/to/patient/archives');
%
%   % Read the resulting index as a DOM node
%   docNode = xmlread('PatientLibraryIndex.xml');
%
%   % Update library index, this time returning DOM node
%   docNode = IndexLibrary('1.0', 'path/to/patient/archives');
%
% Copyright (C) 2014 University of Wisconsin Board of Regents
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

% Log start of indexing and start timer
if exist('Event', 'file') == 2
    Event(['Beginning index of patient library ', directory]);
    tic;
end

% Initialize plan counter
found = 0;

% Create new DOM XML structure using com.mathworks.xml.XMLUtils
docNode = com.mathworks.xml.XMLUtils.createDocument('patientLibraryIndex');

% Add element to XML structure
index = docNode.getDocumentElement;

% Add version as XML attribute 
index.setAttribute('version', version);

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Retrieve list of all files in the directory
folderList = dir(directory);

% Initialize folder counter
i = 0;

% Start recursive loop through each folder, subfolder
while i < size(folderList, 1)
    
    % Increment current folder being analyzed
    i = i + 1;
    
    % If the folder content is . or .., skip to next folder in list
    if strcmp(folderList(i).name, '.') || strcmp(folderList(i).name, '..')
        continue
        
    % Otherwise, if the folder content is a subfolder
    elseif folderList(i).isdir == 1
        
        % Retrieve the subfolder contents
        subFolderList = dir(fullfile(directory, folderList(i).name));
        
        % Look through the subfolder contents
        for j = 1:size(subFolderList, 1)
            
            % If the subfolder content is . or .., skip to next subfolder 
            % in list
            if strcmp(subFolderList(j).name, '.') || ...
                    strcmp(subFolderList(j).name, '..')
                continue
            else
                
                % Otherwise, replace the subfolder name with its full
                % reference
                subFolderList(j).name = fullfile(folderList(i).name, ...
                    subFolderList(j).name);
            end
        end
        
        % Append the subfolder contents to the main folder list
        folderList = vertcat(folderList, subFolderList); %#ok<AGROW>
        
        % Clear temporary variable
        clear subFolderList;
        
    % Otherwise, if the folder content is a patient archive
    elseif size(strfind(folderList(i).name, '_patient.xml'), 1) > 0
        
        %% Load plan and search for CTs
        % Log loading of XML file
        if exist('Event', 'file') == 2
            Event(['Initializing XPath instance for ', folderList(i).name]);
        end
        
        % Read in the patient XML and store the DOM node to doc
        doc = xmlread(fullfile(directory,folderList(i).name));

        % Initialize a new xpath instance to the variable factory
        factory = XPathFactory.newInstance;

        % Initialize a new xpath to the variable xpath
        xpath = factory.newXPath;

        % Declare a new xpath search expression.  Search for all CTs
        expression = ...
            xpath.compile('//fullDiseaseDataArray/fullDiseaseDataArray');
        
        % Log beginning of search
        if exist('Event', 'file') == 2
            Event('Searching for reference image sets in patient XML');
        end
        
        % Retrieve the results
        nodeList = expression.evaluate(doc, XPathConstants.NODESET);

        %% Retrieve CT data
        % Loop through the results
        for j = 1:nodeList.getLength
            
            % Set a handle to the current result
            node = nodeList.item(j-1);

            %% Retrieve study ID
            % Declare new xpath search expression for DICOM study ID
            subexpression = xpath.compile(['fullDicomStudyDataArray/', ...
                'fullDicomStudyDataArray/dicomStudy/originalStudyUID']);
            
            % Evaluate xpath expression and retrieve the results
            subnodeList = subexpression.evaluate(...
                node, XPathConstants.NODESET);
            
            % If the original study UID was not found, skip to next
            if subnodeList.getLength == 0
                continue
            end
            
            % Store the first returned value
            studyUID = char(...
                subnodeList.item(0).getFirstChild.getNodeValue);

            %% Retrieve associated plans
            % Declare new xpath search expression for associated plans
            subexpression = xpath.compile(...
                'fullPlanDataArray/fullPlanDataArray');
            
            % Evaluate xpath expression and retrieve the results
            subnodeList = subexpression.evaluate(node, ...
                XPathConstants.NODESET);

            % Loop through associated plans
            for k = 1:subnodeList.getLength
                % Set a handle to the current plan
                subnode = subnodeList.item(k-1);

                %% Retrieve plan trial
                % Declare new xpath search for approvedPlanTrialUID
                subsubexpression = xpath.compile(...
                    'plan/briefPlan/approvedPlanTrialUID');
                
                % Evaluate xpath expression and retrieve the results
                subsubnodeList = subsubexpression.evaluate(...
                    subnode, XPathConstants.NODESET);
                
                % If no approvedPlanTrialUID was found, plan may not
                % have been approved, so continue
                if subsubnodeList.getLength == 0
                    continue
                else
                    % Otherwise, store approvedPlanTrialUID as char array
                    approvedPlanTrialUID = ...
                        char(subsubnodeList.item(0).getFirstChild.getNodeValue);
                end

                %% Retrieve plan type
                % Declare new xpath search expression for typeOfPlan
                subsubexpression = xpath.compile(...
                    'plan/briefPlan/typeOfPlan');
                
                % Evaluate xpath expression and retrieve the results
                subsubnodeList = subsubexpression.evaluate(...
                    subnode, XPathConstants.NODESET);
                
                % Store plan type as char array
                typeOfPlan = char(...
                    subsubnodeList.item(0).getFirstChild.getNodeValue);

                %% Retrieve plan state
                % Declare new xpath search expression for planState
                subsubexpression = xpath.compile(...
                    'plan/briefPlan/planState');
                
                % Evaluate xpath expression and retrieve the results
                subsubnodeList = subsubexpression.evaluate(...
                    subnode, XPathConstants.NODESET);
                
                % Store plan state as char array
                planState = char(...
                    subsubnodeList.item(0).getFirstChild.getNodeValue);

                %% Verify plan type, state, and trial UID
                % If plan type is PATIENT, and plan state is PLANNED, and
                % an approved plan trial UID exists
                if strcmp(typeOfPlan, 'PATIENT') ...
                        && strcmp(planState, 'PLANNED') ...
                        && ~strcmp(approvedPlanTrialUID, '')
                    
                    % Increment plan counter
                    found = found + 1;

                    %% Retrieve plan UID
                    % Declare new xpath search for plan database UID
                    subsubexpression = xpath.compile(...
                        'plan/briefPlan/dbInfo/databaseUID');
                    
                    % Evaluate xpath expression and retrieve the results
                    subsubnodeList = subsubexpression.evaluate(...
                        subnode, XPathConstants.NODESET);
                    
                    % Store plan UID as char array
                    planUID = char(...
                        subsubnodeList.item(0).getFirstChild.getNodeValue);

                    %% Retrieve plan label
                    % Declare new xpath search expression for plan label
                    subsubexpression = xpath.compile(...
                        'plan/briefPlan/planLabel');
                    
                    % Evaluate xpath expression and retrieve the results
                    subsubnodeList = subsubexpression.evaluate(...
                        subnode, XPathConstants.NODESET);
                    
                    % Store plan label as char array
                    planLabel = char(...
                        subsubnodeList.item(0).getFirstChild.getNodeValue);

                    % Log plan label and UID
                    if exist('Event', 'file') == 2
                        Event(['Found plan ', planLabel, ', UID ', ...
                            planUID]);
                    end
                    
                    %% Retrieve plan date/time
                    % Declare new xpath search for plan modification date
                    subsubexpression = xpath.compile(...
                        'plan/briefPlan/modificationTimestamp/date');
                    
                    % Evaluate xpath expression and retrieve the results
                    subsubnodeList = subsubexpression.evaluate(...
                        subnode, XPathConstants.NODESET);
                    
                    % Store plan modification date as char array
                    planModDate = char(...
                        subsubnodeList.item(0).getFirstChild.getNodeValue);

                    % Declare new xpath search for plan modification time
                    subsubexpression = xpath.compile(...
                        'plan/briefPlan/modificationTimestamp/time');
                    
                    % Evaluate xpath expression and retrieve the results
                    subsubnodeList = subsubexpression.evaluate(...
                        subnode, XPathConstants.NODESET);
                    
                    % Store plan modification time as char array
                    planModTime = char(...
                        subsubnodeList.item(0).getFirstChild.getNodeValue);

                    %% Create library entry for plan
                    % Create XML entry for this plan
                    plan = docNode.createElement('plan');

                    % Create DOM element for study UID
                    studyUIDNode = docNode.createElement('studyUID');
                    
                    % Add child with studyUID contents
                    studyUIDNode.appendChild(...
                        docNode.createTextNode(studyUID));
                    
                    % Append child to plan entry
                    plan.appendChild(studyUIDNode);

                    % Create DOM entry for plan UID
                    planUIDNode = docNode.createElement('planUID');
                    
                    % Add child with planUID contents
                    planUIDNode.appendChild(...
                        docNode.createTextNode(planUID));
                    
                    % Append child to plan entry
                    plan.appendChild(planUIDNode);

                    % Create DOM entry for plan trial UID
                    planTrialUIDNode = ...
                        docNode.createElement('approvedPlanTrialUID');
                    
                    % Add child with approvedPlanTrialUID contents
                    planTrialUIDNode.appendChild(...
                        docNode.createTextNode(approvedPlanTrialUID));
                    
                    % Append child to plan entry
                    plan.appendChild(planTrialUIDNode);

                    % Create DOM entry for plan label
                    planLabelNode = docNode.createElement('planLabel');
                    
                    % Add child with planLabel contents
                    planLabelNode.appendChild(...
                        docNode.createTextNode(planLabel));
                    
                    % Append child to plan entry
                    plan.appendChild(planLabelNode);

                    % Create DOM entry for plan modification date/time
                    datetimeNode = docNode.createElement('timestamp');
                    
                    % Add child with concatenated date and time contents
                    datetimeNode.appendChild(docNode.createTextNode(...
                        [planModDate, ' ', planModTime]));
                    
                    % Append child to plan entry
                    plan.appendChild(datetimeNode);

                    % Create DOM entry for patient archive path
                    archiveNode = docNode.createElement('patientArchive');
                    
                    % Add child with folder path (relative to library root)
                    archiveNode.appendChild(...
                        docNode.createTextNode(folderList(i).name));
                    
                    % Append child to plant entry
                    plan.appendChild(archiveNode);

                    % Attach plan to index
                    index.appendChild(plan);
                    
                    % Clear temporary variables
                    clear planUID planLabel planModDate planModTime ...
                        plan studyUIDNode planUIDNode planTrialUIDNode ...
                        planLabelNode datetimeNode archiveNode;
                end
                
                % Clear temporary variables
                clear subnode subsubexpression subsubnodeList ...
                    typeOfPlan planState;
            end
            
            % Clear temporary variables
            clear node subexpression subnodeList studyUID;
        end
        
        % Clear temporary variables
        clear doc factory xpath expression nodeList;
    end
end

%% Write Index
% Clear temporary variables
clear i folderList;

% Log the total number of plans found
if exist('Event', 'file') == 2
    Event(sprintf('%i plans added to index', found));
end

% Write DOM node to XML
if exist('Event', 'file') == 2
    Event('Writing library index XML file');
end

try
    % Attempt to write docNode to PatientLibraryIndex.xml
    xmlwrite(fullfile(directory, 'PatientLibraryIndex.xml'), docNode);
catch
    % If an error occurs while writing to file, throw error
    if exist('Event', 'file') == 2
        Event(['Patient library index coult not be written to ', ...
            fullfile(directory, 'PatientLibraryIndex.xml'), docNode], ...
            'ERROR');
    else
        error(['Patient library index coult not be written to ', ...
            fullfile(directory, 'PatientLibraryIndex.xml'), docNode]);
    end
end

% Log indexing completion
if exist('Event', 'file') == 2
    Event(sprintf(['Indexing complete for patient library %s in ', ...
        '%0.3f seconds'], directory, toc));
end

% If a return variable is requested, return docNode DOM object 
if nargout == 1
    varargout{1} = docNode;
end
    
% Clear temporary variables
clear index docNode;