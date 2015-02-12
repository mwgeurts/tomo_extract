## TomoTherapy Archive Extraction Tools

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2015, University of Wisconsin Board of Regents

The TomoTherapy&reg; Archive Extraction Tools are a compilation of functions that parse [TomoTherapy](http://www.accuray.com) patient archives and into MATLAB structures and arrays.  In addition, a function is included which can use these variables for dose calculation. These tools are used in various applications, including [exit_detector](https://github.com/mwgeurts/exit_detector), [systematic_error](https://github.com/mwgeurts/systematic_error), and [mvct_dose](https://github.com/mwgeurts/mvct_dose).

These tools use the [SSH/SFTP/SCP for Matlab (v2)] (http://www.mathworks.com/matlabcentral/fileexchange/35409-sshsftpscp-for-matlab-v2) interface based on the Ganymed-SSH2 javalib for sending files between and executing commands on a research workstation, which has been included in this repository.  Refer to the [Third Party Statements](README.md#third-party-statements) for copyright information of this interface.

TomoTherapy is a registered trademark of Accuray Incorporated.

## Contents

* [Installation and Use](README.md#installation-and-use)
* [Compatibility and Requirements](README.md#compatibility-and-requirements)
* [Tools and Examples](README.md#tools-and-examples)
  * [LoadImage](README.md#loadimage)
  * [LoadStructures](README.md#loadstructures)
  * [LoadPlan](README.md#loadplan)
  * [LoadPlanDose](README.md#loadplandose)
  * [LoadDailyQA](README.md#loaddailyqa)
  * [LoadStaticCouchQA](README.md#loadstaticcouchqa)
  * [FindIVDT](README.md#findivdt)
  * [FindMVCTScanLengths](README.md#findmvctscanlengths)
  * [FindPlans](README.md#findplans)
  * [CalcDose](README.md#calcdose)
  * [ParseDetData](README.md#parsedetdata)
* [Event Calling](README.md#event-calling)
* [Third Party Statements](README.md#third-party-statements)

## Installation and Use

To install the TomoTherapy Archive Extraction Tools, copy all MATLAB .m files and subfolders from this repository into your MATLAB path.  If installing as a submodule into another git repository, execute `git submodule add https://github.com/mwgeurts/tomo_extract`.

To configure a remote calculation server, find and modify the following line in `CalcDose()` with the DNS name (or IP address), username, and password for the workstation you wish to use.  This user account must have SSH access rights, rights to execute `gpusadose` and/or `sadose`, and finally read/write acces to the temp directory. 

```matlab
ssh2 = ssh2_config('tomo-research', 'tomo', 'hi-art');
```

## Compatibility and Requirements

The TomoTherapy Archive Extraction Tools have been validated for 4.X and 5.X patient archives using MATLAB versions 8.3 through 8.5 on Macintosh OSX 10.8 (Mountain Lion) through 10.10 (Yosemite).  These tools use the `javax.xml.xpath` Java library and `xmlread()` MATLAB function for parsing archive XML files.

## Tools and Examples

The following subsections describe what inputs and return variables are used, and provides examples for basic operation of each tool. For more information, refer to the documentation within the source code.

### LoadImage

`LoadImage()` loads the reference CT and associated IVDT information from a specified TomoTherapy patient archive and plan UID. This function calls `FindIVDT()` to load the IVDT data.

The following variables are required for proper execution: 

* path: path to the patient archive XML file
* name: name of patient XML file in path
* planUID: UID of plan to extract reference image from

The following variables are returned upon succesful completion:

* image: structure containing the image data, dimensions, width, start coordinates, structure set UID, couch checksum and IVDT 

Below is an example of how this function is used:

```matlab
path = '/path/to/archive/';
name = 'Anon_0001_patient.xml';
planUID = '1.2.826.0.1.3680043.2.200.1688035198.217.40463.657';
image = LoadImage(path, name, planUID);
```

### LoadStructures

`LoadStructures()` loads transverse reference structure sets given a reference image UID and creates mask arrays for each structure.  Voxels will be 1 if they are included in the structure and 0 if not.  Currently partial voxel inclusion is not supported. 

The following variables are required for proper execution: 

* varargin{1}: path to the patient archive XML file
* varargin{2}: name of patient XML file in path
* varargin{3}: structure of reference image.  Must include a structureSetUID field referencing structure set, as well as dimensions, width, and start fields. See `LoadImage()` for more information.
* varargin{4} (optional): cell array of atlas names, include/exclude regex statements, and load flags (if zero, matched structures will not be loaded). If not provided, all structures will be loaded. See [LoadAtlas()](https://github.com/mwgeurts/structure_atlas) for more information.

The following variables are returned upon succesful completion:

* structures: cell array of structure names, color, and 3D mask array of same size as reference image containing fraction of voxel inclusion in structure
 
Below is an example of how this function is used:

```matlab
path = '/path/to/archive/';
name = 'Anon_0001_patient.xml';
planUID = '1.2.826.0.1.3680043.2.200.1688035198.217.40463.657';
image = LoadImage(path, name, planUID);
atlas = LoadAtlas('atlas.xml');
structures = LoadStructures(path, name, image, atlas);
```

### LoadPlan

`LoadPlan()` loads the delivery plan from a specified TomoTherapy patient archive and plan trial UID.  This data can be used to perform dose calculation via `CalcDose()`.

The following variables are required for proper execution: 

* path: path to the patient archive XML file
* name: name of patient XML file in path
* planUID: UID of the plan

The following variables are returned upon succesful completion:

* planData: delivery plan data including scale, tau, lower leaf index, number of projections, number of leaves, sync/unsync actions, leaf sinogram, isocenter, and planTrialUID

Below is an example of how this function is used:

```matlab
path = '/path/to/archive/';
name = 'Anon_0001_patient.xml';
planUID = '1.2.826.0.1.3680043.2.200.1688035198.217.40463.657';
plan = LoadPlan(path, name, planUID);
```

### LoadPlanDose

`LoadPlanDose()` loads the optimized dose after EOP (ie, Final Dose) for a given reference plan UID and TomoTherapy patient archive.  The dose is returned as a structure.

The following variables are required for proper execution: 

* path: path to the patient archive XML file
* name: name of patient XML file in path
* planUID: UID of plan to extract dose image

The following variables are returned upon succesful completion:

* dose: structure containing the associated plan dose (After EOP) array, start coordinates, width, dimensions, and frame of reference

Below is an example of how this function is used:

```matlab
path = '/path/to/archive/';
name = 'Anon_0001_patient.xml';
planUID = '1.2.826.0.1.3680043.2.200.1688035198.217.40463.657';
dose = LoadPlanDose(path, name, planUID);
```

### LoadDailyQA

`LoadDailyQA()` parses a TomoTherapy Transit Dose DICOM RT object or patient archive XML file for procedure return data and derives various calibration parameters.  See below for more details on the parameters returned.

The following variables are required for proper execution:

* name: name of the DICOM RT file or patient archive XML file
* path: path to the DICOM RT file or patient archive XML file
* numberOfProjections: number of projections in the daily QA procedure
* openRows: number of detector channels included in the DICOM file
* mvctRows: the number of active MVCT data channels
* shiftGold: boolean, set to 1 to auto-shift gold standard data to measured profile when computing channelCal

The following structure fields are returned upon succesful completion:

* dailyqa.rawData: an array of raw MVCT detector channel data
* dailyqa.background: a double representing the mean background signal on the MVCT detector when the MLC leaves are closed
* dailyqa.leafMap: an array of MVCT detector channel to MLC leaf mappings.  Each channel represents the maximum signal for that leaf
* dailyqa.leafSpread: array of relative response for an MVCT channel for an open leaf (according to leafMap) to neighboring MLC leaves
* dailyqa.channelGold: array of the "expected" MLC response given the TomoTherapy treatment system gold standard beam model
* dailyqa.channelCal: array containing the relative response of each detector channel in an open field given KEEP_OPEN_FIELD_CHANNELS
* dailyqa.evenLeaves: array containing the MVCT detector response when all even MLC leaves are open, used to generate leafMap
* dailyqa.oddLeaves: array containing the MVCT detector response when all odd MLC leaves are open, used to generate leafMap
* dailyqa.returnQAData: substructure of daily QA procedure return data parsed by this function, with details on each procedure
* dailyqa.returnQADataList: a string cell array for formatted return data (for populating a menu() call)

Below is an example of how this function is used:

```matlab
path = '/path/to/archive/';
name = 'Daily_QA_patient.xml';
dailyqa = LoadDailyQA(path, name, 9000, 531, 528, 0); 
```

### LoadStaticCouchQA

`LoadStaticCouchQA()` searches a TomoTherapy machine archive (given by the name and path input variables) for static couch QA procedures. If more than one is found, it prompts the user to select one to load (using listdlg call) and reads the exit detector data into the return variable detdata. If no static couch QA procedures are found, the user is prompted to select a DICOM RT transit dose file.

The following variables are required for proper execution:

* name: name of the DICOM RT file or patient archive XML file
* path: path to the DICOM RT file or patient archive XML file
* leftTrim: the channel in the exit detector data that corresponds to the first channel in the channelCalibration array
* channelCal: array containing the relative response of each detector channel in an open field given KEEP_OPEN_FIELD_CHANNELS, created by `LoadDailyQA()`
* detectorRows: number of detector channels included in the DICOM file

The following variables are returned upon succesful completion:

* machine: string containing delivered machine name
* planUID: UID of the plan if parsed from the patient XML, otherwise 'UNKNOWN' if parsed from a transit dose DICOM file
* detdata: n x detectorRows of uncorrected exit detector data for a delivered static couch DQA plan, where n is the number of projections in the plan

Below is an example of how this function is used:

```matlab
% Load Daily QA data (channel calibration)
path = '/path/to/archive/';
name = 'Daily_QA_patient.xml';
dailyqa = LoadDailyQA(path, name, 9000, 531, 528, 0); 
 
% Load Static Couch QA data
path = '/path/to/archive/';
name = 'Static_Couch_QA_patient.xml';
[machine, planUID, detdata] = LoadStaticCouchQA(path, name, 27, ...
    dailyqa.channelCal, 643); 
```

### FindIVDT

`FindIVDT()` searches for the IVDT associated with a daily image, reference image, or machine.  If 'MVCT', the calibration UID provided is searched for in the machine archive, and the corresponding IVDT is returned.  If 'TomoPlan', the IVDT UID is the correct value, the IVDT is loaded for that value.  If 'TomoMachine', the machine archive is parsed for the most recent imaging equipment and the UID is returned.

The following variables are required for proper execution: 

* path: path to the patient archive XML file
* id: identifier, dependent on type. If MVCT, id should be the delivered machine calibration UID; if TomoPlan, shound be the full dose IVDT UID; if 'TomoMachine', should be the machine name
* type: type of UID to extract IVDT for.  Can be 'MVCT', 'TomoPlan', or 'TomoMachine'. 

The following variables are returned upon succesful completion:

* ivdt: n-by-2 array of associated CT number/density pairs

Below is an example of how this function is used:

```matlab  
path = '/path/to/archive/';
id = '1.2.826.0.1.3680043.2.200.1693609359.434.30969.2213';
ivdt = FindIVDT(path, id, 'TomoPlan');
```

### FindMVCTScanLengths

`FindMVCTScanLengths()` searches a TomoTherapy patient archive for patient plans with associated MVCT procedures, and returns a list of procedure UIDs and start/end scan positions, organized by plan type.

The following variables are required for proper execution: 

* path: string containing the path to the patient archive XML file
* name: string containing the name of patient XML file in path

The following variable is returned upon succesful completion:

* scans: cell array of structures for each plan, with each structure containing the following fields: planUID, planName, scanUIDs, and scanLengths

Below is an example of how this function is used:

```matlab
path = '/path/to/archive/';
name = 'Anon_0001_patient.xml';
scans = FindMVCTScanLengths(path, name);
```

### FindPlans

`FindPlans()` loads all delivery plan trial UIDs from a specified TomoTherapy patient archive. Only approved Helical, non-DQA plans are returned. 

The following variables are required for proper execution: 

* path: path to the patient archive XML file
* name: name of patient XML file in path

The following variable is returned upon succesful completion:

* plans: cell array of approved plan UIDs

Below is an example of how this function is used:

```matlab
path = '/path/to/archive/';
name = 'Anon_0001_patient.xml';
plans = FindPlans(path, name);
```

### CalcDose

`CalcDose()` reads in a patient CT and delivery plan, generate a set of inputs that can be passed to the TomoTherapy Standalone Dose Calculator, and executes the dose calculation either locally or remotely.  

This function will first attempt to calculate dose locally, if available (the system must support the which command).  If not found, the dose calculator inputs will be copied to a remote computation server via SCP and sadose/gpusadose executed via an initiated SSH connection. 

To change the connection information for the remote computation server, edit the following line in the code below.  The first argument is the server DNS name (or IP address), while the second and third are the username and password, respectively.  This user account must have SSH access rights, rights to execute sadose/gpusadose, and finally read/write 
access to the temp directory.

```matlab
ssh2 = ssh2_config('tomo-research', 'tomo', 'hi-art');
```

Following execution, the CT image, folder, and SSH connection variables are persisted, such that CalcDose may be executed again with only a new plan input argument.

Dose calculation will natively compute the dose at the CT resolution. However, if the number of image data elements is greater than 4e7, the dose will be downsampled by a factor of two.  The calculated dose will be downsampled (from the CT image resolution) by this factor in the IECX and IECY directions, then upsampled (using nearest neighbor interpolation) back to the original CT resolution following calculation.  To speed up calculation, the dose can be further downsampled by adjusting the downsample variable declaration in the code below, where downsample must be an even divisor of the CT dimensions (1, 2, 4, etc).  

Contact Accuray Incorporated to see if your research workstation includes the TomoTherapy Standalone Dose Calculator.

The following variables are required for proper execution: 

* image (optional): cell array containing the CT image to be calculated on. The following fields are required, data (3D array), width (in cm), start (in cm), dimensions (3 element vector), and ivdt (2 x n array of CT and density value)
* plan (optional): delivery plan structure including scale, tau, lower leaf index, number of projections, number of leaves, sync/unsync actions, and leaf sinogram. May optionally include a 6-element registration vector.
* modelfolder (optional): string containing the path to the beam model files (dcom.header, fat.img, kernel.img, etc.)
* sadose (optional): flag indicating whether to call sadose or gpusadose. If not provided, defaults to 0 (gpusadose). CPU calculation should only be used if non-analytic scatter kernels are necessary, as it will significantly slow down dose calculation.

The following variables are returned upon succesful completion:

* dose: If inputs are provided, a cell array contaning the dose volume. The dose.data field will be the same size as image.data, and the start, width, and dimensions fields will be identical.  If no inputs are provided, CalcDose will simply test for local and remote dose calculation and return a flag indicating whether or not a suitable dose calculator is found.

Below are examples of how this function is used:

```matlab
% Test if dose calculation is available (returns 0 or 1)
flag = CalcDose();

% Calculate dose, passing image, plan, and model folder inputs
dose = CalcDose(image, plan, modelfolder);

% Calculate dose on same image as above, using modified plan modplan
dose = CalcDose(modplan);

% Calculate dose again, but using sadose rather than gpusadose
dose = CalcDose(image, modplan, modelfolder, 1);
```

### ParseDetData

`ParseDetData()` is a function that exctracts the dose1, dose2, and detector data from a compressed TomoTherapy Detector Data file (detdata.dat). This function will display a progress bar while it loads (unless MATLAB was executed with the -nodisplay, -nodesktop, or -noFigureWindows flags). The following terminal commands are used to download the detector data file from the DRS following delivery:

```
ftp drs
bin
cd /sd0a
get detData.dat
quit
```

The following variables are required for proper execution: 

* filename: string containing the path and filename to the detector data

The following variables are returned upon succesful completion:

* data: structure containing timedate, views, dose1, dose2, cone, and detdata fields. dose1, dose2, and cone are vectors (views x 1), while detdata is an array (views x 640)

Below is an example of how this function is used:

```matlab
data = ParseDetData('./Treat_3_J48_detData.dat');
figure;
imagesc(data.detdata);
```

## Event Calling

These functions optionally return execution status and error information to an `Event()` function. If available in the MATLAB path, `Event()` will be called with one or two variables: the first variable is a string containing the status information, while the second is the status classification (WARN or ERROR). If the status information is only informative, the second argument is not included.  Finally, if no `Event()` function is available errors will still be thrown via the standard `error()` MATLAB function.

## Third Party Statements

SSH/SFTP/SCP for Matlab (v2)
<br>Copyright &copy; 2014, David S. Freedman
<br>All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in
  the documentation and/or other materials provided with the distribution

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
