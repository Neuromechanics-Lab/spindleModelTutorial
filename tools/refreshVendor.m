function refreshVendor()
% refreshVendor  Re-copy the vendored dependency files from the source repos.
%
%   The tutorial vendors a small subset of two sibling repositories so that this
%   repo is SELF-SUFFICIENT (a plain `git clone` runs, with nothing else to
%   install). Those copies are frozen snapshots - run this script to re-sync them
%   after the source repos change.
%
%   Requires the source repos to be present as siblings (or pointed to by the
%   SPINDLE_TOOLBOX_DIR / GAMMA_OPT_DIR environment variables):
%       <parent>/matlabMuscleSpindleModellingTools
%       <parent>/gammaDriveOptimization
%
%   Usage:   cd tools; refreshVendor
%
%   The file list below is the complete dependency surface, determined with
%   matlab.codetools.requiredFilesAndProducts on the two app classes:
%     * SpindleLearnApp    -> 12 toolbox files, 0 from gammaDriveOptimization
%     * SpindleToolkitApp  -> those 12 + 2 B-spline files
%   If the apps gain new dependencies, re-run that check and update this list.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
parentDir = fileparts(root);

% -- Locate the source repos -------------------------------------------
toolboxDir = getenv('SPINDLE_TOOLBOX_DIR');
if isempty(toolboxDir)
    toolboxDir = fullfile(parentDir, 'matlabMuscleSpindleModellingTools');
end
optDir = getenv('GAMMA_OPT_DIR');
if isempty(optDir)
    optDir = fullfile(parentDir, 'gammaDriveOptimization');
end
assert(isfolder(toolboxDir), 'Source repo not found: %s', toolboxDir);
assert(isfolder(optDir),     'Source repo not found: %s', optDir);

% -- The complete dependency surface (relative paths within each repo) --
toolboxFiles = {
    fullfile('spindle_model', '@halfSarcWithCoopBag',   'halfSarcWithCoopBag.m')
    fullfile('spindle_model', '@halfSarcWithCoopChain', 'halfSarcWithCoopChain.m')
    fullfile('spindle_model', 'getDefaultSarcB.m')
    fullfile('spindle_model', 'getDefaultSarcC.m')
    fullfile('spindle_model', 'sarcSimDriverIntrafusal20250627.m')
    fullfile('spindle_model', 'sarc2spindle_20240310.m')
    fullfile('spindle_model', 'integrateAndFire_v2.m')
    fullfile('spindle_model', 'find_hsl_from_force_spindle20250627.m')
    fullfile('extrafusal_model', '@halfSarcWithCoopExtrafusal_3state', ...
             'halfSarcWithCoopExtrafusal_3state.m')
    fullfile('extrafusal_model', 'getDefaultSarcE.m')
    fullfile('extrafusal_model', 'musTenDriver20250627.m')
    fullfile('extrafusal_model', 'mtu_balance_forces_for_spindle20250627.m')
    };
optFiles = {
    fullfile('functions', 'runSpindleSimForOpt_Bspline_5cp.m')
    fullfile('functions', 'getIntrafusal_pCa_Bspline_5cp.m')
    fullfile('functions', 'syncIntrafusalStartLength.m')
    fullfile('functions', 'runSpindleSimForOpt_Bspline_5cp_gDynBspline.m')
    fullfile('functions', 'getIntrafusal_pCa_Bspline_5cp_gDynBspline.m')
    };

vendorRoot = fullfile(root, 'vendor');
n = 0;
n = n + copySet(toolboxDir, toolboxFiles, fullfile(vendorRoot, 'matlabMuscleSpindleModellingTools'));
n = n + copySet(optDir,     optFiles,     fullfile(vendorRoot, 'gammaDriveOptimization'));

% -- Record provenance --------------------------------------------------
% The licence line matters: a repository cannot relicense third-party code it
% bundles, so anyone reading vendor/ needs to know where these files stand.
% Both source repos are the same author's, so the root LICENSE covers them.
stamp = sprintf(['Vendored dependency snapshot\n' ...
    '============================\n\n' ...
    'These files are COPIES, taken from their source repositories at the\n' ...
    'commits below. Do not edit them here - edit the source repo and re-run\n' ...
    'tools/refreshVendor.m.\n\n' ...
    '  matlabMuscleSpindleModellingTools : %s\n' ...
    '  gammaDriveOptimization            : %s\n\n' ...
    'Files: %d\n\n' ...
    'Licence\n' ...
    '-------\n' ...
    'Both source repositories were written by the same author as this one\n' ...
    '(Surabhi N. Simha), so these copies carry no third-party licence: they\n' ...
    'are covered by the GNU AGPL v3 LICENSE at the root of this repository.\n'], ...
    gitDescribe(toolboxDir), gitDescribe(optDir), n);
fid = fopen(fullfile(vendorRoot, 'VENDOR_INFO.txt'), 'w');
fwrite(fid, stamp); fclose(fid);

fprintf('%s\nRefreshed %d vendored files into %s\n', stamp, n, vendorRoot);
end


% ======================================================================
function n = copySet(srcRoot, relFiles, dstRoot)
n = 0;
for i = 1:numel(relFiles)
    src = fullfile(srcRoot, relFiles{i});
    dst = fullfile(dstRoot, relFiles{i});
    assert(isfile(src), 'Missing source file: %s', src);
    d = fileparts(dst);
    if ~isfolder(d), mkdir(d); end
    copyfile(src, dst);
    n = n + 1;
end
end

function s = gitDescribe(repoDir)
% Short commit hash of a repo, read straight from .git (no shell-out: MATLAB's
% system() can hang in -batch mode).
s = 'unknown (not a git checkout)';
try
    gitDir = fullfile(repoDir, '.git');
    if ~isfolder(gitDir), return; end
    head = strtrim(fileread(fullfile(gitDir, 'HEAD')));
    if startsWith(head, 'ref:')
        refPath = strtrim(extractAfter(head, 'ref:'));
        refFile = fullfile(gitDir, refPath);
        if isfile(refFile)
            s = strtrim(fileread(refFile));
        else   % packed refs
            pk = fullfile(gitDir, 'packed-refs');
            if isfile(pk)
                lines = strsplit(fileread(pk), newline);
                hit = lines(contains(lines, refPath));
                if ~isempty(hit), s = strtrim(extractBefore(strtrim(hit{1}), ' ')); end
            end
        end
    else
        s = head;   % detached HEAD
    end
    if numel(s) >= 7, s = s(1:7); end
catch
end
end
