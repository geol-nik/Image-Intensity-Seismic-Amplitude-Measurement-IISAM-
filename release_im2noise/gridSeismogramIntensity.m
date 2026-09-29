function grids = gridSeismogramIntensity(Icrop, recordLengthHours, wLengthHours, wStepHours, includeColumns)
%GRIDSEISMOGRAMINTENSITY Grid a cropped seismogram into intensity windows.
%   GRIDS = GRIDSEISMOGRAMINTENSITY(ICROP, RECORDLENGTHHOURS,
%   WLENGTHHOURS, WSTEPHOURS) computes row-window, column-window, and
%   row-by-column box intensity summaries. By default, it computes columns
%   and boxes for older callers.
%
%   GRIDS = GRIDSEISMOGRAMINTENSITY(..., INCLUDECOLUMNS) controls whether
%   the column grid and box summaries are computed.

if nargin < 4
    error('gridSeismogramIntensity:NotEnoughInputs', ...
        'Expected Icrop, recordLengthHours, wLengthHours, and wStepHours.');
end

if nargin < 5 || isempty(includeColumns)
    includeColumns = true;
end

Icrop = prepareCrop(Icrop);
validateGridInputs(Icrop, recordLengthHours, wLengthHours, wStepHours);

windowFraction = wLengthHours / recordLengthHours;
stepFraction = wStepHours / recordLengthHours;

grids.row = buildAxisGrid(Icrop, 1, "row", windowFraction, ...
    stepFraction, recordLengthHours);

if includeColumns
    grids.column = buildAxisGrid(Icrop, 2, "column", windowFraction, ...
        stepFraction, recordLengthHours);
    grids.box = buildBoxGrid(Icrop, grids.row, grids.column);
end
end

function Icrop = prepareCrop(Icrop)
if ndims(Icrop) == 3
    Icrop = mean(Icrop(:,:,1:min(size(Icrop, 3), 3)), 3);
end

Icrop = double(Icrop);
Icrop(~isfinite(Icrop)) = NaN;
end

function axisGrid = buildAxisGrid(Icrop, axisDim, axisName, windowFraction, ...
    stepFraction, recordLengthHours)
axisLengthPx = size(Icrop, axisDim);

windowLengthPx = max(1, round(windowFraction * axisLengthPx));
windowStepPx = max(1, round(stepFraction * axisLengthPx));
windowLengthPx = min(windowLengthPx, axisLengthPx);

startIdx = 1:windowStepPx:max(1, axisLengthPx - windowLengthPx + 1);
endIdx = min(axisLengthPx, startIdx + windowLengthPx - 1);

nWindows = numel(startIdx);
avgIntensity = nan(nWindows, 1);
medIntensity = nan(nWindows, 1);
sampleCount = zeros(nWindows, 1);

for iWindow = 1:nWindows
    if axisDim == 1
        area = Icrop(startIdx(iWindow):endIdx(iWindow), :);
    else
        area = Icrop(:, startIdx(iWindow):endIdx(iWindow));
    end

    pixels = area(isfinite(area));
    sampleCount(iWindow) = numel(pixels);

    if ~isempty(pixels)
        avgIntensity(iWindow) = mean(pixels);
        medIntensity(iWindow) = prctile(pixels, 50);
    end
end

centerPx = ((startIdx + endIdx) ./ 2).';
normalizedPosition = ((centerPx - 0.5) ./ axisLengthPx);
timeEquivalentHours = normalizedPosition .* recordLengthHours;

axisGrid = struct( ...
    'axisName', axisName, ...
    'startIndex', startIdx(:), ...
    'endIndex', endIdx(:), ...
    'centerPixel', centerPx, ...
    'normalizedPosition', normalizedPosition, ...
    'timeEquivalentHours', timeEquivalentHours, ...
    'averageIntensity', avgIntensity, ...
    'medianIntensity', medIntensity, ...
    'sampleCount', sampleCount, ...
    'windowLengthPixels', windowLengthPx, ...
    'windowStepPixels', windowStepPx, ...
    'axisLengthPixels', axisLengthPx);
end

function boxGrid = buildBoxGrid(Icrop, rowGrid, columnGrid)
nRows = numel(rowGrid.startIndex);
nColumns = numel(columnGrid.startIndex);

avgIntensity = nan(nRows, nColumns);
medIntensity = nan(nRows, nColumns);
sampleCount = zeros(nRows, nColumns);

for iRow = 1:nRows
    rowRange = rowGrid.startIndex(iRow):rowGrid.endIndex(iRow);

    for iColumn = 1:nColumns
        columnRange = columnGrid.startIndex(iColumn):columnGrid.endIndex(iColumn);
        boxPixels = Icrop(rowRange, columnRange);
        boxPixels = boxPixels(isfinite(boxPixels));
        sampleCount(iRow, iColumn) = numel(boxPixels);

        if ~isempty(boxPixels)
            avgIntensity(iRow, iColumn) = mean(boxPixels);
            medIntensity(iRow, iColumn) = median(boxPixels);
        end
    end
end

boxGrid = struct( ...
    'averageIntensity', avgIntensity, ...
    'medianIntensity', medIntensity, ...
    'sampleCount', sampleCount, ...
    'rowAverageIntensity', mean(avgIntensity, 2, 'omitnan'), ...
    'rowMedianIntensity', median(avgIntensity, 2, 'omitnan'));
end

function validateGridInputs(Icrop, recordLengthHours, wLengthHours, wStepHours)
if isempty(Icrop) || size(Icrop, 1) < 1 || size(Icrop, 2) < 1
    error('gridSeismogramIntensity:EmptyCrop', ...
        'Icrop must contain at least one row and one column.');
end

if ~isfinite(recordLengthHours) || recordLengthHours <= 0
    error('gridSeismogramIntensity:BadRecordLength', ...
        'recordLengthHours must be a positive finite number.');
end

if ~isfinite(wLengthHours) || wLengthHours <= 0 || ...
        ~isfinite(wStepHours) || wStepHours <= 0
    error('gridSeismogramIntensity:BadWindowSize', ...
        'wLengthHours and wStepHours must be positive finite numbers.');
end
end
