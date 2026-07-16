function [allEmbeddings, allLabels] = loadEmbeddingsFromSupabase(cfg)
%% Loads all embeddings from Supabase into memory for local matching

fprintf('Loading embeddings from Supabase...\n');

% Supabase returns max 1000 rows by default — use range header for more
fetchUrl = sprintf('%s/rest/v1/face_embeddings?select=label,embedding&order=id.asc', ...
    cfg.url);

fetchOpts = weboptions(...
    'RequestMethod', 'get', ...
    'HeaderFields',  {
    'apikey',        cfg.apikey;
    'Authorization', ['Bearer ' cfg.apikey];
    'Range',         '0-9999'   % fetch up to 10000 rows
    }, ...
    'Timeout', 30, ...
    'ContentType', 'json');

data = webread(fetchUrl, fetchOpts);

if isempty(data)
    allEmbeddings = [];
    allLabels     = string([]);
    fprintf('No embeddings found.\n');
    return;
end

nRows         = length(data);
allLabels     = strings(nRows, 1);
allEmbeddings = [];

for i = 1:nRows
    allLabels(i) = string(data(i).label);

    vals = str2double(strsplit(data(i).embedding, ','));
    allEmbeddings(end+1,:) = vals;
end

fprintf('Loaded %d embeddings for %d people.\n', ...
    nRows, length(unique(allLabels)));
end