clc;
clear;
close all;

%% =========================================================
% ARCFACE TRAINING — EXTRACT + SAVE TO SUPABASE + .MAT
% MTCNN + FACE ALIGNMENT + ARCFACE ONNX
%% =========================================================

datasetPath = 'dataset';
onnxPath    = 'buffalo_l\w600k_r50.onnx';
savePath    = 'arcfaceEmbeddings.mat';
cfg         = supabaseConfig();

%% =========================================================
% LOAD ARCFACE ONNX
%% =========================================================
fprintf('Loading ArcFace ONNX...\n');
arcNet = importNetworkFromONNX(onnxPath, ...
    'InputDataFormats',  'BCSS', ...
    'OutputDataFormats', 'BC');
fprintf('ArcFace loaded.\n');

%% =========================================================
% LOAD MTCNN
%% =========================================================
fprintf('Loading MTCNN...\n');
detector = mtcnn.Detector();
fprintf('MTCNN loaded.\n');

%% =========================================================
% ARCFACE REFERENCE LANDMARKS (112x112)
%% =========================================================
refPts = [38.29, 51.70;
          73.53, 51.70;
          56.02, 71.74;
          41.55, 92.37;
          70.73, 92.37];

%% =========================================================
% CLEAR EXISTING EMBEDDINGS FROM SUPABASE
%% =========================================================
fprintf('Clearing existing embeddings from Supabase...\n');
try
    deleteUrl  = sprintf('%s/rest/v1/face_embeddings?id=gte.0', cfg.url);
    deleteOpts = weboptions(...
        'RequestMethod', 'delete', ...
        'HeaderFields',  {
            'apikey',        cfg.apikey;
            'Authorization', ['Bearer ' cfg.apikey];
            'Content-Type',  'application/json'
        }, ...
        'Timeout', 10);
    webread(deleteUrl, deleteOpts);
    fprintf('Cleared.\n');
catch
    fprintf('Nothing to clear or delete failed — continuing.\n');
end

%% =========================================================
% SCAN DATASET
%% =========================================================
peopleFolders = dir(datasetPath);
peopleFolders = peopleFolders([peopleFolders.isdir]);
peopleFolders = peopleFolders(~ismember({peopleFolders.name},{'.','..'}));
fprintf('\nFound %d people.\n', length(peopleFolders));

allEmbeddings = [];
allLabels     = {};

%% =========================================================
% PROCESS EACH PERSON
%% =========================================================
for i = 1:length(peopleFolders)

    personName   = peopleFolders(i).name;
    personFolder = fullfile(datasetPath, personName);

    fprintf('\n====================================\n');
    fprintf('Processing: %s\n', personName);
    fprintf('====================================\n');

    imageFiles = [dir(fullfile(personFolder,'*.jpg'));
                  dir(fullfile(personFolder,'*.jpeg'));
                  dir(fullfile(personFolder,'*.png'))];

    if isempty(imageFiles)
        fprintf('No images found, skipping.\n');
        continue;
    end

    personEmbeddings = [];

    for j = 1:length(imageFiles)

        imgPath = fullfile(personFolder, imageFiles(j).name);
        fprintf('[%d/%d] %s — ', j, length(imageFiles), imageFiles(j).name);

        try
            img = imread(imgPath);

            if size(img,3) == 1
                img = cat(3,img,img,img);
            end

            %% Detect face + landmarks
            [bboxes, ~, landmarks] = detect(detector, img);

            if isempty(bboxes)
                fprintf('No face, skipping.\n');
                continue;
            end

            %% Take largest face
            areas    = bboxes(:,3) .* bboxes(:,4);
            [~, idx] = max(areas);
            bbox     = bboxes(idx,:);
            lm       = landmarks(idx,:);

            %% Align face
            srcPts = [lm(1), lm(6);
                      lm(2), lm(7);
                      lm(3), lm(8);
                      lm(4), lm(9);
                      lm(5), lm(10)];

            face    = [];
            alignOK = false;

            try
                tform      = estimateGeometricTransform2D(srcPts, refPts, ...
                    'similarity', 'MaxDistance', 100);
                outputView = imref2d([112 112]);
                face       = imwarp(img, tform, 'OutputView', outputView);
                alignOK    = true;
            catch
                alignOK = false;
            end

            %% Fallback crop
            if ~alignOK || isempty(face)
                x = max(1, round(bbox(1)));
                y = max(1, round(bbox(2)));
                w = min(round(bbox(3)), size(img,2) - x);
                h = min(round(bbox(4)), size(img,1) - y);

                if w <= 0 || h <= 0
                    fprintf('Invalid bbox, skipping.\n');
                    continue;
                end

                face = imcrop(img, [x y w h]);
                face = imresize(face, [112 112]);
            end

            if isempty(face)
                fprintf('Empty face, skipping.\n');
                continue;
            end

            if size(face,3) == 1
                face = cat(3,face,face,face);
            end

            %% Preprocess
            face = im2single(face);
            face = face(:,:,[3 2 1]);
            face = (face - 0.5) / 0.5;
            face = permute(face, [3 1 2]);
            face = reshape(face, [1 3 112 112]);
            face = dlarray(face, 'BCSS');

            %% Extract embedding
            emb = predict(arcNet, face);
            emb = double(extractdata(emb));
            emb = emb(:)';

            n = norm(emb);
            if n == 0
                fprintf('Zero norm, skipping.\n');
                continue;
            end
            emb = emb / n;

            personEmbeddings = [personEmbeddings; emb];

            if alignOK
                fprintf('OK (aligned)\n');
            else
                fprintf('OK (fallback)\n');
            end

        catch ME
            fprintf('ERROR: %s\n', ME.message);
        end

    end  % image loop

    if isempty(personEmbeddings)
        fprintf('No valid embeddings for %s, skipping.\n', personName);
        continue;
    end

    %% Store all embeddings
    for e = 1:size(personEmbeddings,1)
        allEmbeddings(end+1,:) = personEmbeddings(e,:);
        allLabels{end+1}       = personName;
    end

    fprintf('Stored %d embeddings for %s\n', size(personEmbeddings,1), personName);

end  % person loop

if isempty(allEmbeddings)
    fprintf('No embeddings extracted. Check dataset and MTCNN.\n');
    return;
end

allLabels    = string(allLabels);
uniquePeople = unique(allLabels);

%% =========================================================
% SEPARABILITY CHECK
%% =========================================================
fprintf('\n====================================\n');
fprintf('SEPARABILITY CHECK\n');
fprintf('====================================\n');

for a = 1:length(uniquePeople)
    for b = a+1:length(uniquePeople)

        idxA  = allLabels == uniquePeople(a);
        idxB  = allLabels == uniquePeople(b);

        meanA = mean(allEmbeddings(idxA,:),1);
        meanB = mean(allEmbeddings(idxB,:),1);
        meanA = meanA / norm(meanA);
        meanB = meanB / norm(meanB);

        sim = dot(meanA, meanB);
        fprintf('  %s vs %s : %.6f', uniquePeople(a), uniquePeople(b), sim);

        if sim > 0.60
            fprintf('  *** TOO SIMILAR\n');
        elseif sim > 0.40
            fprintf('  !! Borderline\n');
        else
            fprintf('  OK\n');
        end
    end
end

%% =========================================================
% SAME vs DIFFERENT PERSON TEST
%% =========================================================
fprintf('\n====================================\n');
fprintf('SAME vs DIFFERENT PERSON TEST\n');
fprintf('====================================\n');

for a = 1:length(uniquePeople)

    personA = uniquePeople(a);
    idxA    = find(allLabels == personA);

    if length(idxA) >= 2
        sim = dot(allEmbeddings(idxA(1),:), allEmbeddings(idxA(2),:));
        fprintf('SAME | %s photo1 vs photo2 : %.6f', personA, sim);
        if sim > 0.5
            fprintf('  OK\n');
        else
            fprintf('  *** LOW\n');
        end
    end

    for b = a+1:length(uniquePeople)
        personB = uniquePeople(b);
        idxB    = find(allLabels == personB);

        sim = dot(allEmbeddings(idxA(1),:), allEmbeddings(idxB(1),:));
        fprintf('DIFF | %s vs %s : %.6f', personA, personB, sim);

        if sim < 0.3
            fprintf('  OK\n');
        elseif sim < 0.5
            fprintf('  !! Borderline\n');
        else
            fprintf('  *** TOO SIMILAR\n');
        end
    end

    fprintf('\n');
end

fprintf('====================================\n');
fprintf('EXPECTED:\n');
fprintf('  SAME person : > 0.5  (ideally > 0.7)\n');
fprintf('  DIFF person : < 0.3  (ideally < 0.1)\n');
fprintf('====================================\n');

%% =========================================================
% SAVE TO .MAT (backup)
%% =========================================================
fprintf('\nSaving .mat backup...\n');
save(savePath, 'allEmbeddings', 'allLabels');
fprintf('.mat saved.\n');

%% =========================================================
% UPLOAD TO SUPABASE
%% =========================================================
fprintf('\nUploading embeddings to Supabase...\n');

uploadUrl  = sprintf('%s/rest/v1/face_embeddings', cfg.url);
uploadOpts = weboptions(...
    'RequestMethod', 'post', ...
    'MediaType',     'application/json', ...
    'HeaderFields',  {
        'apikey',        cfg.apikey;
        'Authorization', ['Bearer ' cfg.apikey];
        'Prefer',        'return=minimal'
    }, ...
    'Timeout', 15);

uploadCount = 0;
failCount   = 0;

for i = 1:size(allEmbeddings,1)

    embStr  = strjoin(arrayfun(@(v) sprintf('%.8f',v), ...
        allEmbeddings(i,:), 'UniformOutput', false), ',');
    payload = struct('label', char(allLabels(i)), 'embedding', embStr);

    try
        webwrite(uploadUrl, payload, uploadOpts);
        uploadCount = uploadCount + 1;
        fprintf('Uploaded %d/%d\n', uploadCount, size(allEmbeddings,1));
    catch ME
        failCount = failCount + 1;
        fprintf('Upload failed row %d: %s\n', i, ME.message);
    end

end

fprintf('\n====================================\n');
fprintf('TRAINING COMPLETE\n');
fprintf('Total embeddings : %d\n', size(allEmbeddings,1));
fprintf('Uploaded         : %d\n', uploadCount);
fprintf('Failed           : %d\n', failCount);
fprintf('People           : %s\n', strjoin(uniquePeople, ', '));
fprintf('====================================\n');