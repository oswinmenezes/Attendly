clc;
clear;
close all;

%% =========================================================
% LIVE FACE REC-..OGNITION + ATTENDANCE
% ArcFace ONNX + MTCNN + FACE ALIGNMENT
% Loads from Supabase (3s timeout) else fallback .mat
%% =========================================================

embeddingsPath = 'arcfaceEmbeddings.mat';
onnxPath       = 'buffalo_l\w600k_r50.onnx';
cfg            = supabaseConfig();

%% =========================================================
% LOAD EMBEDDINGS — SUPABASE FIRST, .MAT FALLBACK
%% =========================================================
fprintf('Trying Supabase...\n');

allEmbeddings = [];
allLabels     = string([]);
loadedFrom    = '';

try
    fetchUrl  = sprintf('%s/rest/v1/face_embeddings?select=label,embedding&order=id.asc', cfg.url);

    fetchOpts = weboptions( ...
        'RequestMethod', 'get', ...
        'HeaderFields', {
            'apikey', cfg.apikey;
            'Authorization', ['Bearer ' cfg.apikey];
            'Range', '0-9999'
        }, ...
        'Timeout', 3, ...
        'ContentType', 'json');

    data = webread(fetchUrl, fetchOpts);

    if isempty(data)
        error('No data in Supabase.');
    end

    nRows = length(data);
    allLabels = strings(nRows,1);
    allEmbeddings = zeros(nRows,512);

    for i = 1:nRows
        allLabels(i) = string(data(i).label);
        allEmbeddings(i,:) = str2double(strsplit(data(i).embedding, ','));
    end

    loadedFrom = 'Supabase';
    fprintf('Loaded %d embeddings from Supabase.\n', nRows);

catch ME
    fprintf('Supabase failed (%s)\nFalling back to .mat...\n', ME.message);

    if exist(embeddingsPath,'file')
        load(embeddingsPath);
        allLabels = string(allLabels);
        loadedFrom = '.mat';
        fprintf('Loaded %d embeddings from .mat.\n', size(allEmbeddings,1));
    else
        error('No .mat file found.');
    end
end

fprintf('Source: %s\n', loadedFrom);

uniquePeople = unique(allLabels);
fprintf('People: %s\n', strjoin(uniquePeople, ', '));

%% =========================================================
% LOAD ARCFACE ONNX
%% =========================================================
fprintf('Loading ArcFace ONNX...\n');
arcNet = importNetworkFromONNX(onnxPath, ...
    'InputDataFormats','BCSS', ...
    'OutputDataFormats','BC');
fprintf('ArcFace loaded.\n');

%% =========================================================
% LOAD MTCNN
%% =========================================================
fprintf('Loading MTCNN...\n');
detector = mtcnn.Detector();
fprintf('MTCNN loaded.\n');

%% =========================================================
% REFERENCE LANDMARKS
%% =========================================================
refPts = [38.29, 51.70;
          73.53, 51.70;
          56.02, 71.74;
          41.55, 92.37;
          70.73, 92.37];

%% =========================================================
% CAMERA
%% =========================================================
cam = webcam(1);
cam.Resolution = '1280x720';

%% =========================================================
% SETTINGS
%% =========================================================
threshold = 0.35;
scoreGapThreshold = 0.05;
runTime = 15;
detectEvery = 5;
frameCount = 0;

%% =========================================================
% ATTENDANCE STORAGE (FIXED)
%% =========================================================
presentStudents = strings(0);   % ✅ FIXED (was {})

%% =========================================================
% TRACKING
%% =========================================================
trackedBoxes = [];
trackedNames = {};
trackedScores = {};

lastBoxes = [];
lastNames = {};
lastScores = {};

startTime = tic;
figure('Name', sprintf('ArcFace Recognition [%s]', loadedFrom));

%% =========================================================
% MAIN LOOP
%% =========================================================
while ishandle(gcf) && toc(startTime) < runTime

    frame = snapshot(cam);
    frameCount = frameCount + 1;
    frame = im2uint8(frame);

    if mod(frameCount, detectEvery) == 0

        trackedBoxes = [];
        trackedNames = {};
        trackedScores = {};

        try
            [bboxes,~,landmarks] = detect(detector, frame);
            fprintf('Faces detected: %d\n', size(bboxes,1));

            if ~isempty(bboxes)

                for i = 1:size(bboxes,1)

                    bbox = bboxes(i,:);
                    if bbox(3) < 60 || bbox(4) < 60
                        continue;
                    end

                    lm = landmarks(i,:);

                    %% Align
                    srcPts = [lm(1), lm(6);
                              lm(2), lm(7);
                              lm(3), lm(8);
                              lm(4), lm(9);
                              lm(5), lm(10)];

                    face = [];
                    alignOK = false;

                    try
                        tform = estimateGeometricTransform2D(srcPts, refPts, ...
                            'similarity','MaxDistance',100);

                        outputView = imref2d([112 112]);
                        face = imwarp(frame, tform, 'OutputView', outputView);
                        alignOK = true;
                    catch
                        alignOK = false;
                    end

                    %% fallback crop
                    if ~alignOK || isempty(face)
                        x = max(1,round(bbox(1)));
                        y = max(1,round(bbox(2)));
                        w = min(round(bbox(3)), size(frame,2)-x);
                        h = min(round(bbox(4)), size(frame,1)-y);

                        if w<=0 || h<=0, continue; end

                        face = imcrop(frame,[x y w h]);
                        face = imresize(face,[112 112]);
                    end

                    if isempty(face), continue; end

                    if size(face,3)==1
                        face = cat(3,face,face,face);
                    end

                    %% preprocess
                    face = im2single(face);
                    face = face(:,:,[3 2 1]);
                    face = (face - 0.5)/0.5;
                    face = permute(face,[3 1 2]);
                    face = reshape(face,[1 3 112 112]);
                    face = dlarray(face,'BCSS');

                    %% embedding
                    emb = predict(arcNet, face);
                    emb = double(extractdata(emb));
                    emb = emb(:)';

                    if norm(emb)==0, continue; end
                    emb = emb / norm(emb);

                    %% match
                    similarities = allEmbeddings * emb';

                    bestPerLabel = zeros(1,length(uniquePeople));

                    for k = 1:length(uniquePeople)
                        idx = allLabels == uniquePeople(k);
                        bestPerLabel(k) = max(similarities(idx));
                    end

                    [bestScore,labelIdx] = max(bestPerLabel);

                    temp = bestPerLabel;
                    temp(labelIdx) = -inf;
                    secondBest = max(temp);

                    gap = bestScore - secondBest;

                    fprintf('Best: %.4f | Second: %.4f | Gap: %.4f\n', ...
                        bestScore, secondBest, gap);

                    if bestScore >= threshold && gap >= scoreGapThreshold
                        name = uniquePeople(labelIdx);
                    else
                        name = "Unknown";
                    end

                    fprintf('Identified: %s\n', name);

                    %% ATTENDANCE FIXED
                    if name ~= "Unknown"
                        if ~any(presentStudents == name)   % ✅ FIXED
                            presentStudents(end+1) = name; % ✅ FIXED
                            fprintf('>> MARKED PRESENT: %s\n', name);
                        end
                    end

                    x = max(1,round(bbox(1)));
                    y = max(1,round(bbox(2)));
                    w = min(round(bbox(3)), size(frame,2)-x);
                    h = min(round(bbox(4)), size(frame,1)-y);

                    trackedBoxes(end+1,:) = [x y w h];
                    trackedNames{end+1} = name;
                    trackedScores{end+1} = bestScore;

                end
            end

        catch ME
            fprintf('Detection error: %s\n', ME.message);
        end

        if ~isempty(trackedBoxes)
            lastBoxes = trackedBoxes;
            lastNames = trackedNames;
            lastScores = trackedScores;
        end
    end

    %% draw
    dispFrame = frame;

    if ~isempty(lastBoxes)
        for i = 1:size(lastBoxes,1)

            bbox = lastBoxes(i,:);
            name = lastNames{i};
            score = lastScores{i};

            label = sprintf('%s : %.2f', name, score);

            if name == "Unknown"
                color = 'red';
            else
                color = 'green';
            end

            dispFrame = insertObjectAnnotation(dispFrame,'rectangle',bbox,label, ...
                'LineWidth',3,'Color',color,'TextColor','white');
        end
    end

    imshow(dispFrame);
    drawnow limitrate;
end

%% CLEANUP
clear cam;
close all;

%% =========================================================
% ATTENDANCE REPORT
%% =========================================================
fprintf('\n====================================\n');
fprintf('        ATTENDANCE REPORT\n');
fprintf('====================================\n');
fprintf('  Source: %s\n', loadedFrom);
fprintf('====================================\n');

presentCount = 0;
absentCount  = 0;

for i = 1:length(uniquePeople)

    student = uniquePeople(i);

    if any(presentStudents == student)
        status = "PRESENT";
        presentCount = presentCount + 1;
    else
        status = "ABSENT";
        absentCount = absentCount + 1;
    end

    fprintf('  %-15s : %s\n', student, status);
end

fprintf('====================================\n');
fprintf('  Present : %d | Absent : %d\n', presentCount, absentCount);
fprintf('====================================\n');
fprintf('SESSION ENDED\n');
fprintf('====================================\n');