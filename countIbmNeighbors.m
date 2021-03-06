function counts = countIbmNeighbors(outFile, cleanDir, thresh_db, nfft, fs)

% Count co-ocurrences of neighbors in ideal binary masks
%
% For use as compatPot in mrfGridLbp().  Neighbor order is up, right, down,
% left.

if ~exist('thresh_db', 'var') || isempty(thresh_db), thresh_db = 0; end
if ~exist('nfft', 'var') || isempty(nfft), nfft = 1024; end
if ~exist('fs', 'var') || isempty(fs), fs = 16000; end
nFiles = 20;

[cf nf rf] = getFileNames(cleanDir, nFiles);

F = nfft/2 + 1;  % number of frequencies
I = 3;           % number of classes (src1, src2, garbargeSrc)
nNeigh = 4;      % number of neighbors in grid MRF
counts = ones([F I I nNeigh]);
for f = 1:length(cf)
    maxSrc = computeIbm(cf{f}, nf{f}, rf{f}, thresh_db, nfft, fs);
    %ibm = trimIbm(ibm);
    counts = updateCounts(counts, maxSrc, nNeigh);
end
counts = counts(2:end-1,:,:,:);
clear ibm

save(outFile)


function [cf nf rf] = getFileNames(cleanDir, nFiles)
% cf: anechoic target, nf: anechoic mixture, rf: reverberant mixture
[~,cf] = findFiles(cleanDir, '-src1.wav');
ord = randperm(length(cf));
cf = cf(ord(1:nFiles));

nf = cell(size(cf));
rf = cell(size(cf));
for i = 1:length(cf)
    nf{i} = strrep(cf{i}, '-src1', '');
    rf{i} = strrep(nf{i}, 'anech', 'reverb');
end


function maxSrc = computeIbm(cleanFile, noisyFile, reverbFile, thresh_db, nfft, fs)

[cL cR] = loadSpec(cleanFile, nfft, fs);
[nL nR] = loadSpec(noisyFile, nfft, fs);
[rL rR] = loadSpec(reverbFile, nfft, fs);

src1 = combineChannels(cL, cR);
src2 = combineChannels(nL-cL, nR-cR);
rev  = combineChannels(rL-nL, rR-nR);

srcs = cat(3, src1, src2, rev);
[~,maxSrc] = max(srcs, [], 3);

function [L R] = loadSpec(fileName, nfft, fs)
[lr tfs] = wavReadBetter(fileName);
lr = resample(lr, fs, tfs);
[L R] = binSpec(lr', nfft);

function C = combineChannels(L, R)
% Geometric average magnitude of the two channels
C = 0.5 * (db(abs(L)) + db(abs(R)));

function ibm = trimIbm(ibm)
% Trim off beginning and ending frames with no target
nTarget = sum(ibm,1);
start = 1;
while nTarget(start) == 0
    start = start + 1;
end
stop = length(nTarget);
while nTarget(stop) == 0
    stop = stop - 1;
end
ibm = ibm(:,start:stop);


function counts = updateCounts(counts, maxSrc, nNeigh)
% Counts is FxIxIx4, where dimensions are (frequency, targetClass,
% neighborClass, neighborDirection).
%
% Neighbors:     1      [(-1,0), (0,1), (1,0), (0,-1)]
%             4  X  2   df = [-1  0  1  0] = mod(n,  2).*(n-2)
%                3      dt = [ 0  1  0 -1] = mod(n+1,2).*(3-n)

[F T] = size(maxSrc);
for n = 1:nNeigh
    df = mod(n,   2).*(n - 2);  % [-1  0  1  0];
    dt = mod(n+1, 2).*(3 - n);  % [ 0  1  0 -1];
    
    fi = max(1,1-df):min(F,F-df);
    target = maxSrc(fi, max(1,1-dt):min(T,T-dt));
    neighbor = maxSrc(max(1,1+df):min(F,F+df), max(1,1+dt):min(T,T+dt));

    for i1 = 1:size(counts,2)
        for i2 = 1:size(counts,3)
            counts(fi,i1,i2,n) = counts(fi,i1,i2,n) ...
                + sum((target == i1) .* (neighbor == i2), 2);
        end
    end
end
