function [Icrop, limits] = edgeCrop_20260402(I)

%% Preprocess
I = double(I);

% Convert to grayscale if needed
if ndims(I) == 3
    I = mean(I,3);
end

% Normalize
I = (I - min(I(:))) / (max(I(:)) - min(I(:)));

%% Downscale
scale = 0.1; % 5-20% works well
I_small = imresize(I, scale);

[Nrow_s, Ncol_s] = size(I_small);

%% Remove horizontal banding
I_hp = I_small - movmean(I_small, 50, 2);

%% Vertical Crop
% Energy (robust to oscillations)
rowenergy = sqrt(mean(I_hp.^2, 2));

% Smooth heavily
wrow = max(1, round(0.05 * Nrow_s));
rowenergy_s = movmean(rowenergy, wrow);

% Normalize
r = (rowenergy_s - min(rowenergy_s)) / (max(rowenergy_s) - min(rowenergy_s));

% Threshold
mask = r > 0.2;

% Largest continuous region
d = diff([0; mask; 0]);
start_idx = find(d == 1);
end_idx   = find(d == -1) - 1;

[~, k] = max(end_idx - start_idx);

tlim_s = start_idx(k);
blim_s = end_idx(k);

%% Horizonal crop
colenergy = sqrt(mean(I_hp.^2, 1));

wcol = max(1, round(0.05 * Ncol_s));
colenergy_s = movmean(colenergy, wcol);

c = (colenergy_s - min(colenergy_s)) / (max(colenergy_s) - min(colenergy_s));

mask_c = c > 0.2;

d = diff([0 mask_c 0]);
start_idx = find(d == 1);
end_idx   = find(d == -1) - 1;

[~, k] = max(end_idx - start_idx);

llim_s = start_idx(k);
rlim_s = end_idx(k);

%% Scale back
scale_inv = 1 / scale;

tlim = max(1, round(tlim_s * scale_inv));
blim = min(size(I,1), round(blim_s * scale_inv));
llim = max(1, round(llim_s * scale_inv));
rlim = min(size(I,2), round(rlim_s * scale_inv));

%% FInal Crop
Icrop = I(tlim:blim, llim:rlim);

%% Output limits
limits.tlim = tlim;
limits.blim = blim;
limits.llim = llim;
limits.rlim = rlim;

end
