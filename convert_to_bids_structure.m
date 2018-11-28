% Script to convert existing dataset to BIDS format
% Alex von Lautz @NNU @OHBA
% License CC0

% My first foray into converting my data into the BIDS format for data
% sharing.
% Last year I collected an EEG study - called Magdot -, which now that I am aware of the BIDS
% project I want to put into this data format and share.

%% Set up directories
% The style of BIDS is: 
%└──project
%   └── subject
%       └── session
%           └── acquisition
% Because I only have one session per subject, I omit the session level.
% My data right now is stored in a very similar system, however, the names
% of files and folders are different.

orig_dir='/media/avl/DATA/Magdot/raw_data/'; %Where files from Magdot are stored
output_dir='/media/avl/DATA/B_Magdot/'; %where we want to output the bids compatible Magdot files
mkdir(output_dir)% make the ouput directory
% Let's start by looking at the existing files
filenames=dir(orig_dir);
% In my case there are folders for each participant called 'S01', 'S02'...
% etc., but also pilot data 'P01' not in the same structure
file_strings = regexp({filenames.name}, 'S\d+[0-9]', 'match');%Note that this includes non-match empty cells 
subj_ids=cell2mat(vertcat(file_strings{:}));%define the subjects we want
% Let's create the acquisition folders
for dosub=1:length(subj_ids)
    afolder{dosub}=fullfile(output_dir,['sub-' subj_ids(dosub,2:3)],'eeg');
    mkdir(afolder{dosub})
end 
%% Copy raw data to new bids structure
% I collected data with a biosemi 64 active electrode system
% The data is stored in the biosemi .bdf format, which is explicitly allowed
% in BIDS, as it converts easily to the preferred .edf standard and can be
% read directly by typical analysis software.
% However, the point of this exercise is to give some idea on how to
% convert all the data, so let's save the biosemi data under the optional
% folder /sourcedata and then create a standard .edf file when doing the
% sidecar in the next step.

% Note, the output filename includes the both the taskname (Magdot)
% and the acquisition method (EEG) with the structure named in the
% specification:
%sub-<participant_label>_task-<task_label>[_acq-<acq_label>][_run-<index>]_eeg.<manufacturer_specific_extension>
% Here, I run into my first problem. Because I have one long recording,
% I cannot split the data into different runs. In BIDS terms we had 8 runs
% for each subject. I will worry about this later and go ahead and copy my
% raw data over as a whole.
for dosub=1:length(subj_ids)
    sourcefolder{dosub}=fullfile(output_dir,['sub-' subj_ids(dosub,2:3)],'eeg','sourcedata');
    mkdir(sourcefolder{dosub})
    %define source data (.bdf)
    sdata{dosub}=fullfile(sourcefolder{dosub},['sub-' subj_ids(dosub,2:3) '_task-Magdot_eeg.bdf']);
    %define BIDS data (.edf)
    bdata{dosub}=fullfile(afolder{dosub},['sub-' subj_ids(dosub,2:3) '_task-Magdot_eeg']);
    %copy the source data into the sourcefolder
    copyfile(fullfile(orig_dir,subj_ids(dosub,:),[subj_ids(dosub,:) '.bdf']), sdata{dosub})
end

%% Create subject specific sidecar files
% When researching how to best approach this transferring, I came across 
% the function data2bids in fieldtrip, which looks like exactly what I
% need. 
% First I have to install the newest version of fieldtrip 
% Then I can put in the configuration structure as follows
% Note that I am taking the .bdf dataset from the sourcedirectory and am
% creating a new .edf in the acquisition folder
for dosub=1:length(subj_id)
 cfg = [];
    cfg.dataset                     = sdata{dosub};
    cfg.outputfile                  = bdata{dosub};
    cfg.eeg.writesidecar            = 'replace';
    cfg.channels.writesidecar       = 'replace';
    cfg.events.writesidecar         = 'replace';
    cfg.InstitutionName             = 'Free University Berlin';
    cfg.InstitutionalDepartmentName = 'Neurocomputation Neuroimaging Unit';
    cfg.InstitutionAddress          = 'Habelschwerdter Allee 45, JK25-211, 14195 Berlin, Germany';
    cfg.TaskName                    = 'Magdot';
    cfg.TaskDescription             = 'Subjects were presented with two subsequent random-dot motion patches and had to judge whether the second had more coherent motion than the first';
    cfg.eeg.PowerLineFrequency      = 50;  % German recordings
    cfg.eeg.EEGReference            = 'N/A'; % Active electrode system is not using a reference, in analyses the common average of all electrodes is typically used
    cfg.Instructions                = 'Perceive the RDM patches and respond via button press (index/middle finger) whether the second RDM patch was more coherent than the first';
    cfg.CogAtlasID                  = 'trm_4f244ad7dcde7';
    cfg.CogPOID                     = 'http://wiki.cogpo.org/index.php?title=Random_Dots'; % Cannot find the ID, so link
        
    data2bids(cfg)
end

%% Create dataset specific sidecar files
% There are three main sidecar files:
% 1 dataset_description.json file
% 2 the participants.tsv file
% 3 the README

% 1 dataset_description.json
% For this we need to have a way to save to .json, I use the jsonlab
% toolbox and the function savejson

dataset_description.BIDSVersion='1.2.0';
dataset_description.License= 'CC0';
dataset_description.Name='Magdot EEG dataset';
dataset_description.Authors='von Lautz,AH';
dataset_description.Acknowledgements='This work was supported by the Fellow-Program Free Knowledge of the Wikimedia Foundation';
dataset_description.HowToAcknowledge='Paper under review';
dataset_description.Funding='DFG GRK 1589/2';
savejson('',dataset_description,[output_dir,'dataset_description.json'])

% 2 participants.tsv file
% I don't want to put up any personal data before double-checking that I am
% allowed, so the next step is just to illustrate
participant_ID = ['sub-01'; 'sub-02'];
age = [26 33]';
sex = ['f';'m'];
group =['S2> index'; 'S2>middle'];%Every other participant answered with either index or middle finger for S2>S1
tsv_file = table(participant_ID,age,sex,group);
writetable(tsv_file,[output_dir,'participants.tsv'],'FileType','text','Delimiter','\t');

% 3 README file
% Of course we also want to tell people exactly what this project is about
readme=' This is EEG data from the Magdot project. \n I converted it using a tutorial-style script that can be found on https://github.com/alexvonlautz/FFW_BIDS';
fid=fopen([output_dir,'readme.txt'],'w');
fprintf(fid, readme);