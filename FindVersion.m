function [build, db] = FindVersion(path, name)
% FindVersion extracts the TomoTherapy build and database versions from the 
% patient archive specified in the input arguments and returns them as a 
% string.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%
% The following variable is returned upon succesful completion:
%   build: string containing the archive build version
%   db: string containing the archive database version
%
% Below is an example of how this function is used:
%
%   path = '/path/to/archive/';
%   name = 'Anon_0001_patient.xml';
%   [build, db] = FindVersion(path, name);
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
    Event(sprintf('Searching %s for archive version', name));
    tic;
end

% Initialize return variables
build = '';
db = '';

% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node
if exist('Event', 'file') == 2
    Event('Loading file contents data using xmlread');
end
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Declare a new xpath search expression.  Search for BuildVersion
expression = ...
    xpath.compile('//BuildVersion');

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% If a build version was found
if nodeList.getLength > 0
    
    % Retrieve a handle to the results
    node = nodeList.item(0);
    
    % Store version as char
    build = char(node.getFirstChild.getNodeValue);
end

% Declare a new xpath search expression.  Search for DatabaseVersion
expression = ...
    xpath.compile('//DatabaseVersion');

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% If a database version was found
if nodeList.getLength > 0
    
    % Retrieve a handle to the results
    node = nodeList.item(0);
    
    % Store version as char
    db = char(node.getFirstChild.getNodeValue);
end

% Clear temporary variables
clear node nodeList expression doc factory xpath;

% Log result
if ~strcmp(db, '')
    if exist('Event', 'file') == 2
        Event(sprintf(['Archive database version identified as %s in ', ...
            '%0.3f seconds'], version, toc));
    end
else
    if exist('Event', 'file') == 2
        Event('Archive database version could not be identified', 'WARN');
    else
        warning('Archive database version could not be identified');
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