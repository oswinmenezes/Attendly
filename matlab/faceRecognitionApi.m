function detectedPeople = faceRecognitionApi(base64Images)

persistent arcNet detector allEmbeddings allLabels uniquePeople loaded

threshold = 0.35;
scoreGapThreshold = 0.05;

detectedPeople = strings(0);

refPts = [38.29, 51.70;
          73.53, 51.70;
          56.02, 71.74;
          41.55, 92.37;
          70.73, 92.37];

%% =========================================================
% INITIALIZATION (RUN ONCE)
%% =========================================================
if isempty(loaded)

    fprintf('Initializing Face Recognition API...\n');

    % -----------------------------
    % BASE DIRECTORY (IMPORTANT FIX)
    % -----------------------------
    baseDir = fileparts(mfilename('fullpath'));

    onnxPath = fullfile(baseDir, 'buffalo_l', 'w600k_r50.onnx');
    embeddingsPath = fullfile(baseDir, 'arcfaceEmbeddings.mat');

    % -----------------------------
    % LOAD ARCFACE
    % -----------------------------
    arcNet = importNetworkFromONNX(onnxPath, ...
        'InputDataFormats','BCSS', ...
        'OutputDataFormats','BC');

    fprintf('ArcFace loaded.\n');

    % -----------------------------
    % LOAD MTCNN
    % -----------------------------
    detector = mtcnn.Detector();
    fprintf('Detector loaded.\n');

    % -----------------------------
    % LOAD EMBEDDINGS (.MAT ONLY)
    % -----------------------------
    if ~isfile(embeddingsPath)
        error('arcfaceEmbeddings.mat not found at: %s', embeddingsPath);
    end

    load(embeddingsPath, 'allEmbeddings', 'allLabels');

    allLabels = string(allLabels);

    if isempty(allEmbeddings)
        error('Embeddings file is empty');
    end

    uniquePeople = unique(allLabels);

    fprintf('Loaded %d identities\n', length(uniquePeople));

    loaded = true;
end

%% =========================================================
% PROCESS BASE64 IMAGES
%% =========================================================
for imgIdx = 1:length(base64Images)

    try
        %% Decode Base64
        base64Str = char(base64Images{imgIdx});
        bytes = matlab.net.base64decode(base64Str);

        tmpFile = [tempname '.jpg'];
        fid = fopen(tmpFile,'wb');
        fwrite(fid, bytes);
        fclose(fid);

        img = imread(tmpFile);
        delete(tmpFile);

        img = im2uint8(img);

        %% Detect faces
        [bboxes,~,landmarks] = detect(detector, img);

        fprintf('Faces detected: %d\n', size(bboxes,1));

        if isempty(bboxes)
            continue;
        end

        %% PROCESS EACH FACE
        for i = 1:size(bboxes,1)

            bbox = bboxes(i,:);
            lm   = landmarks(i,:);

            %% ALIGN FACE
            srcPts = [lm(1), lm(6);
                      lm(2), lm(7);
                      lm(3), lm(8);
                      lm(4), lm(9);
                      lm(5), lm(10)];

            face = [];

            try
                tform = estimateGeometricTransform2D(srcPts, refPts, ...
                    'similarity','MaxDistance',100);

                outputView = imref2d([112 112]);
                face = imwarp(img, tform, 'OutputView', outputView);

            catch
                x = max(1, round(bbox(1)));
                y = max(1, round(bbox(2)));
                w = min(round(bbox(3)), size(img,2)-x);
                h = min(round(bbox(4)), size(img,1)-y);

                if w <= 0 || h <= 0
                    continue;
                end

                face = imcrop(img,[x y w h]);
                face = imresize(face,[112 112]);
            end

            if isempty(face)
                continue;
            end

            if size(face,3) == 1
                face = cat(3,face,face,face);
            end

            %% PREPROCESS
            face = im2single(face);
            face = face(:,:,[3 2 1]);
            face = (face - 0.5) / 0.5;
            face = permute(face,[3 1 2]);
            face = reshape(face,[1 3 112 112]);
            face = dlarray(face,'BCSS');

            %% EMBEDDING
            emb = predict(arcNet, face);
            emb = double(extractdata(emb));
            emb = emb(:)';

            n = norm(emb);
            if n == 0
                continue;
            end
            emb = emb / n;

            %% MATCHING
            similarities = allEmbeddings * emb';

            bestPerLabel = zeros(1, length(uniquePeople));

            for k = 1:length(uniquePeople)
                idx = allLabels == uniquePeople(k);
                bestPerLabel(k) = max(similarities(idx));
            end

            [bestScore, labelIdx] = max(bestPerLabel);

            temp = bestPerLabel;
            temp(labelIdx) = -inf;
            secondBest = max(temp);

            gap = bestScore - secondBest;

            fprintf('Best: %.4f | Second: %.4f | Gap: %.4f\n', ...
                bestScore, secondBest, gap);

            %% DECISION
            if bestScore >= threshold && gap >= scoreGapThreshold
                name = uniquePeople(labelIdx);
            else
                name = "Unknown";
            end

            fprintf('Recognized: %s\n', name);

            %% STORE UNIQUE RESULT
            if name ~= "Unknown"
                if ~any(detectedPeople == name)
                    detectedPeople(end+1) = name;
                end
            end

        end

    catch ME
        fprintf('Image %d failed: %s\n', imgIdx, ME.message);
    end

end

%% OUTPUT
detectedPeople = cellstr(unique(detectedPeople));

end