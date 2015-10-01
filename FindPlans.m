function plans = FindPlans(varargin)
% FindPlans loads all delivery plan trial UIDs from a specified TomoTherapy 
% patient archive. Only approved, non-DQA plans are returned. This function
% has currently been validated for version 3.X, 4.X and 5.X archives.
%
% The following variables are required for proper execution: 
%   varargin{1}: path to the patient archive XML file
%   varargin{2}: name of patient XML file in path
%   varargin{3} (optional): type of plan to load ('Helical'). If left out,
%       all plan types are returned.
%
% The following variable is returned upon succesful completion:
%   plans: cell array of approved plan UIDs
%
% Below is an example of how this function is used:
%
%   path = '/path/to/archive/';
%   name = 'Anon_0001_patient.xml';
%   plans = FindPlans(path, name);
%
%   % This time only retrieve Helical plans
%   helical = FindPlans(path, name, 'Helical');
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

% Log start of matching and start timer
if exist('Event', 'file') == 2
    Event(sprintf('Searching %s for approved plans', varargin{2}));
    tic;
end

% If a third argument was provided
if nargin == 3 && exist('Event', 'file') == 2
    Event(sprintf('Plan types restricted to %s', varargin{3}));
end

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node
if exist('Event', 'file') == 2
    Event('Loading file contents data using xmlread');
end
doc = xmlread(fullfile(varargin{1}, varargin{2}));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Declare a new xpath search expression.  Search for all fullPlanDataArrays
expression = ...
    xpath.compile('//fullPlanDataArray/fullPlanDataArray/plan/briefPlan');

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Preallocate cell array
plans = cell(1, nodeList.getLength);

% Log number of delivery plans found
if exist('Event', 'file') == 2
    Event(sprintf('%i plans found, now searching for approval status', ...
        nodeList.getLength));
end

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    
    % Retrieve a handle to this delivery plan
    node = nodeList.item(i-1);

    % Search for approved plan trial UID
    subexpression = xpath.compile('approvedPlanTrialUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Otherwise, if approved plan trial UID is empty, continue
    if strcmp(char(subnode.getFirstChild.getNodeValue), '') || ...
            strcmp(char(subnode.getFirstChild.getNodeValue), ...
            '* * * DO NOT CHANGE THIS STRING VALUE * * *')
        continue
    end
    
    % If a third argument was provided
    if nargin == 3
   
        % Search for plan delivery type
        subexpression = xpath.compile('planDeliveryType');

        % Evaluate xpath expression and retrieve the results
        subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

        % If plan delivery type was found, continue to next result
        if subnodeList.getLength == 0
            continue
        end

        % Retrieve a handle to the results
        subnode = subnodeList.item(0);

        % Otherwise, if approved plan delivery type is not equal to the 
        % provided type, continue
        if ~strcmp(char(subnode.getFirstChild.getNodeValue), varargin{3})
            continue
        end
    end
    
    % Search for plan type
    subexpression = xpath.compile('typeOfPlan');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If plan type was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Otherwise, if plan type is not PATIENT, continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), 'PATIENT')
        continue
    end
    
    % Search for plan database UID
    subexpression = xpath.compile('dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan UID
    plans{i} = char(subnode.getFirstChild.getNodeValue);
end

% Clear temporary variables
clear doc factory xpath i node subnode nodeList subnodeList expression ...
    subexpression;

% Remove empty cells due invalid plans
plans = plans(~cellfun('isempty', plans));

% If no valid delivery plans were found
if size(plans, 2) == 0
    
    % Throw a warning
    if exist('Event', 'file') == 2
        Event(sprintf('No approved plans found in %s', varargin{2}), 'WARN'); 
    end
    
% Otherwise the execution was successful
else
    
    % Log completion
    if exist('Event', 'file') == 2
        Event(sprintf(['%i approved plans successfully identified in ', ...
            '%0.3f seconds'], size(plans, 2), toc));
    end
end

% Catch errors, log, and rethrow
catch err
    if exist('Event', 'file') == 2
        Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
    else
        rethrow(err);
    end
end