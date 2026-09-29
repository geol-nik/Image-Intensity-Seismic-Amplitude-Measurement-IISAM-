%% INIT
close all
clear 
clc

%% SETTINGS
c_imin   = "C:\Users\cooki\OneDrive\Desktop\tremor_analysis\datasets\test_nik_2\im";
c_datout = "C:\Users\cooki\OneDrive\Desktop\tremor_analysis\results\SMOKE RECORDS 1974_test_out";

% Edge finding
prctsmooth  = 1.5;
invertrecord = false;

% Window parameters
r_length = 24;     % record length (hours)
w_length = 0.5;    % window length (hours)
w_step   = 0.5;    % window step (hours)

% UI behavior
ui.interactive = true;  % true = prompt for metadata/crop review, false = run unattended
defaultStation = "";
defaultComponent = "";

% Plotting
gridRowsOnly = true; % true = horizontal row boundaries only; false = full grid
diag.og = false;
diag.crop = false;
diag.intensity = false;
diag.grid = false;
diag.color = false;
diag.hist = false; 

%% SETUP OUTPUT DIRECTORIES
if ~isfolder(c_datout)
    mkdir(c_datout)
end

reviewDir = fullfile(c_datout,'review');
if ~isfolder(reviewDir)
    mkdir(reviewDir)
end

% Check if diag plots are eneabled
diagEnabled = any(struct2array(diag));
if diagEnabled
    if diag.crop
        diagDirCrop = fullfile(c_datout, 'crop');
        if ~isfolder(diagDirCrop)
            mkdir(diagDirCrop)
        end
    end

    if diag.intensity
        diagDirInt = fullfile(c_datout,'intensity');
        if ~isfolder(diagDirInt)
            mkdir(diagDirInt)
        end
    end

    if diag.grid
        diagDirGrid = fullfile(c_datout,'grid');
        if ~isfolder(diagDirGrid)
            mkdir(diagDirGrid)
        end
    end

    if diag.hist
        diagDirHist = fullfile(c_datout,'hist');
        if ~isfolder(diagDirHist)
            mkdir(diagDirHist)
        end
    end
end

%% MAKE TIMESERIES CSV FOLDER
tsDir = fullfile(c_datout,'timeseries');
if ~isfolder(tsDir)
    mkdir(tsDir)
end

%% LOAD IMAGE FILE LIST
exts = {'*.tif','*.tiff','*.jpg','*.jpeg','*.png'};
files = [];
for k = 1:numel(exts)
    files = [files; dir(fullfile(c_imin, exts{k}))];
end

if isempty(files)
    error('im2noise:NoImagesFound', ...
        'No JPG/TIF/PNG images were found in %s.', c_imin);
end

%% MAIN LOOP THROUGH FILES
for f = 1:length(files)

    fileName = files(f).name;
    fullPath = fullfile(c_imin,fileName);

    fprintf('Processing %s\n', fileName)

    %% PARSE FILENAME METADATA
    [~, nameOnly, ~] = fileparts(fileName);

    station = defaultStation;
    component = defaultComponent;
    recordLengthHours = r_length;
    skipFile = false;

    dateOut = [];

    % Expected name format: YYYYMMDD_HHmm_STA_CMP
    metadata = regexp(nameOnly, ...
        '^(?<date>\d{8})_(?<time>\d{4})_(?<station>[A-Za-z0-9]+)_(?<component>[A-Za-z0-9]+)$', ...
        'names', 'once');

    if ~isempty(metadata)
        try
            dateOut = datetime([metadata.date metadata.time], 'InputFormat','yyyyMMddHHmm');
            station = string(metadata.station);
            component = string(metadata.component);
        catch
            dateOut = [];
            station = defaultStation;
            component = defaultComponent;
            warning('Filename metadata has an invalid date/time: %s', fileName)
        end
    end

    %% READ IMAGE
    try
        I = readSeismogramImage(fullPath);
    catch ME
        warning('Could not read %s (%s). Flagging for review.', fileName, ME.message)
        copyfile(fullPath, fullfile(reviewDir,fileName));
        continue
    end

    if invertrecord
        I = imcomplement(I);
    end
    
    %% INITIALIZE FIGURE HEADERS
    if diag.og
        hf = figure('Visible','off');
        ha = axes;
    end

    if diag.crop
        hf1 = figure('Visible','off');
        ha1 = axes;
    end

    if diag.intensity
        hf2 = figure('Visible','off');
        ha2row = axes('Parent',hf2);
    end

    if diag.grid
        hfgrid = figure('Visible','off');
        hagrid = axes('Parent',hfgrid);
    end

    if diag.color
        hf3 = figure('Visible','off');
        ha3 = axes;
    end

    if diag.hist
        hf4 = figure('Visible','off');
        ha4 = axes;
    end
    
    %% METADATA + CROP
    if ui.interactive
        hf = figure('Name',['Record & Metadata: ' fileName], ...
            'NumberTitle','off', ...
            'Units','normalized', ...
            'Position',[0.05 0.08 0.90 0.84]);
        hPreview = axes('Parent',hf);
        imshow(I, [], 'Parent', hPreview, 'InitialMagnification','fit');
        axis(hPreview,'image')
        axis(hPreview,'off')
        title(hPreview, sprintf('Original Image: %s', fileName),'Interpreter','none');

        % Metadata input
        prompt = { 'Year (yyyy):', ...
                   'Month (1-12):', ...
                   'Day (1-31):', ...
                   'Start time (HH:MM, 24-hr):', ...
                   'Record length (hours):', ...
                   'Station code:', ...
                   'Component code:' };
        dlgtitle = 'Enter record metadata';
        dims = [1 50];
        if isempty(dateOut)
            dateDefaults = {'', '', '', ''};
        else
            dateDefaults = { datestr(dateOut,'yyyy'), ...
                             num2str(month(dateOut)), ...
                             num2str(day(dateOut)), ...
                             datestr(dateOut,'HH:MM') };
        end
        definput = [dateDefaults, ...
                    {num2str(r_length), ...
                     char(station), ...
                     char(component)}];
        answer = inputdlg(prompt, dlgtitle, dims, definput);

        % Handle cancel
        if isempty(answer)
            fprintf('User cancelled metadata entry for %s - flagging for review\n', fileName);
            copyfile(fullPath, fullfile(reviewDir,fileName));
            close(hf)
            continue
        end

        % Parse metadata
        try
            year_in = str2double(answer{1});
            month_in = str2double(answer{2});
            day_in = str2double(answer{3});
            tstr = strtrim(answer{4});
            len_hours = str2double(answer{5});
            station_in = strtrim(answer{6});
            comp_in = strtrim(answer{7});

            comp_code = upper(comp_in);

            tt = sscanf(tstr,'%d:%d');
            if numel(tt) ~= 2
                error('Start time must be HH:MM');
            end
            start_hour = tt(1) + tt(2)/60;
            if ~isfinite(len_hours) || len_hours <= 0
                error('Record length must be a positive number of hours');
            end

            userDate = datetime(year_in, month_in, day_in, ...
                floor(start_hour), round((start_hour-floor(start_hour))*60), 0);
            recordLengthHours = len_hours;
            r_length = recordLengthHours;

            station = string(station_in);

            component = string(comp_code);
            dateOut = datestr(userDate, 'yyyy-mm-dd HH:MM:SS');
        catch
            fprintf('Invalid metadata entered for %s - flagging for review\n', fileName);
            copyfile(fullPath, fullfile(reviewDir,fileName));
            close(hf)
            continue
        end

        % Crop prompt
        cropOK = false;
        while ~cropOK
            try
                [Icrop, limits] = edgeCrop_20260402(I);
            catch ME
                warning('Could not crop %s (%s). Flagging for review.', fileName, ME.message)
                copyfile(fullPath, fullfile(reviewDir,fileName));
                skipFile = true;
                break
            end

            tlim = limits.tlim;
            blim = limits.blim;
            llim = limits.llim;
            rlim = limits.rlim;

            % Show result on same figure
            figure(hf);
            imagesc(Icrop);
            axis image;
            colorbar;
            title({'Auto Crop Result', ...
                   'Press Y = accept | N = manual crop | F = flag for review'})

            waitforbuttonpress
            key = lower(get(hf,'CurrentCharacter'));

            if key == 'y'
                cropOK = true;

            elseif key == 'f'
                fprintf('Flagging %s for review\n', fileName);
                copyfile(fullPath, fullfile(reviewDir,fileName));
                skipFile = true;
                break

            elseif key == 'n'
                manualOK = false;
                while ~manualOK
                    imagesc(I);
                    axis image;
                    colorbar;
                    title({'Draw rectangle around seismogram', ...
                           'Double click inside box when finished'});

                    hrect = drawrectangle;
                    wait(hrect)
                    pos = round(hrect.Position);

                    % Guard against out-of-bounds
                    pos(1) = max(1, pos(1));
                    pos(2) = max(1, pos(2));
                    pos(3) = max(1, min(size(I,2) - pos(1) + 1, pos(3)));
                    pos(4) = max(1, min(size(I,1) - pos(2) + 1, pos(4)));

                    Icrop = I(pos(2):(pos(2)+pos(4)-1), pos(1):(pos(1)+pos(3)-1));

                    imagesc(Icrop);
                    axis image;
                    colorbar;
                    title({'Manual Crop Preview', 'Enter = accept | R = redraw'})

                    waitforbuttonpress
                    key2 = get(hf,'CurrentCharacter');

                    if key2 == 13  % Enter
                        manualOK = true;
                        cropOK = true;
                        tlim = pos(2);
                        blim = pos(2) + pos(4) - 1;
                        llim = pos(1);
                        rlim = pos(1) + pos(3) - 1;
                    elseif lower(key2) == 'r'
                        manualOK = false;
                    end
                end
            end
        end

        close(hf);  % close figure after metadata + crop accepted

        if skipFile
            continue
        end
    else
        if isempty(dateOut)
            warning(['Filename does not match YYYYMMDD_HHmm_STA_CMP for %s, ' ...
                'and interactive metadata entry is disabled. Flagging for review.'], fileName)
            copyfile(fullPath, fullfile(reviewDir,fileName));
            continue
        end
        dateOut = datestr(dateOut, 'yyyy-mm-dd HH:MM:SS');
        try
            [Icrop, limits] = edgeCrop_20260402(I);
        catch ME
            warning('Could not crop %s (%s). Flagging for review.', fileName, ME.message)
            copyfile(fullPath, fullfile(reviewDir,fileName));
            continue
        end

        tlim = limits.tlim;
        blim = limits.blim;
        llim = limits.llim;
        rlim = limits.rlim;
    end

    %% WINDOW SETUP
    r_lenp = size(Icrop, 1);
    if r_lenp < 2
        warning('Crop for %s is too small to window. Flagging for review.', fileName)
        copyfile(fullPath, fullfile(reviewDir,fileName));
        continue
    end

    grids = gridSeismogramIntensity(Icrop, recordLengthHours, w_length, w_step, true);
    rowGrid = grids.row;

    avgint = grids.box.rowAverageIntensity;
    medint = grids.box.rowMedianIntensity;
    t_time = rowGrid.timeEquivalentHours;
    box = numel(avgint);
    
    %% DIAGNOSTIC PLOTS
    if diag.og
        % Original image
        hf;
        imagesc(ha, I);
        axis(ha,'image')
        colorbar
        title(ha,'Original Image')
    end
    
    if diag.crop
        % Cropped image
        hf1;
        imagesc(ha1, Icrop);
        axis(ha1,'image')
        colorbar
        title(ha1,'Cropped Seismogram')
    end

    if diag.intensity
        % Intensity vs time
        hf2;
        plot(ha2row, t_time, avgint, 'LineWidth',1.2)
        hold(ha2row,'on')
        plot(ha2row, t_time, medint, 'LineWidth',1.2)
        hold(ha2row,'off')
        legend(ha2row, 'Average','Median', 'Location', 'best')
        ylabel(ha2row,'Pixel Intensity')
        xlabel(ha2row,'Time (hours)')
        title(ha2row,'Row-Window Intensity')
        grid(ha2row,'on')
    end

    if diag.grid
        drawGridOverlay(hagrid, Icrop, grids, gridRowsOnly);
        title(hagrid, 'Analysis Grid Overlay')
    end

    if diag.color
        hf3;
        if ~isempty(F)
            pcolor(ha3, l, s, F, EdgeColor="none");
        end
    end

    if diag.hist
        % Histogram plot
        hf4;
        histogram(ha4, Icrop(:))
        title(ha4, 'Pixel Intensity Histogram')
        xlabel(ha4,'Pixel Intensity')
        ylabel(ha4,'Count')
    end

    %% EXPORT DIAGNOSTIC FIGURES
    if diagEnabled
        % if diag.og
        %     exportgraphics(hf,  [diagDirOg '_original.png']);
        %     close(hf)
        % end

        if diag.crop
            exportgraphics(hf1, ...
                fullfile(diagDirCrop, sprintf('%s_crop.png',nameOnly)));
            close(hf1)
        end

        if diag.intensity
            exportgraphics(hf2, ...
                fullfile(diagDirInt, sprintf('%s_intensity.png',nameOnly)));
            close(hf2)
        end

        if diag.grid
            exportgraphics(hfgrid, ...
                fullfile(diagDirGrid, sprintf('%s_grid.png',nameOnly)));
            close(hfgrid)
        end

        if diag.hist
            exportgraphics(hf4, ...
                fullfile(diagDirHist, sprintf('%s_hist.png',nameOnly)));
            close(hf4)
        end

        % if diag.color
        %     exportgraphics(hf3, [diagDirpColor '_color.png']);
        %     close(hf3)
        % end
    end

    %% WRITE TO TIMESERIES CSV
    tsCSV = fullfile(tsDir, [nameOnly '_intensity_timeseries.csv']);

    fid = fopen(tsCSV,'w');
    fprintf(fid,'Station,Date,Time,AvgInt,MedInt\n');

    for i = 1:box
        fprintf(fid,'%s,%s,%.4f,%.6f,%.6f\n', ...
            char(station), dateOut, t_time(i), avgint(i), medint(i));
    end

    fclose(fid);

    %% WRITE TO PLAIN TEXT TIMESERIES
    tsTXT = fullfile(tsDir, [nameOnly '_intensity_timeseries.txt']);

    fid = fopen(tsTXT,'w');
    fprintf(fid,'Time\tAvgInt\tMedInt\n');

    for i = 1:box
        fprintf(fid,'%.4f\t%.6f\t%.6f\n', t_time(i), avgint(i), medint(i));
    end

    fclose(fid);
end

function drawGridOverlay(ax, Icrop, grids, rowsOnly)
imagesc(ax, Icrop);
axis(ax,'image')
colormap(ax, gray)
colorbar(ax)
hold(ax,'on')

nRows = size(Icrop, 1);
nCols = size(Icrop, 2);

rowBoundaries = gridBoundaryPositions(grids.row, nRows);

for i = 1:numel(rowBoundaries)
    plot(ax, [0.5, nCols + 0.5], [rowBoundaries(i), rowBoundaries(i)], ...
        'r-', 'LineWidth', 0.75)
end

if ~rowsOnly
    colBoundaries = gridBoundaryPositions(grids.column, nCols);
    for i = 1:numel(colBoundaries)
        plot(ax, [colBoundaries(i), colBoundaries(i)], [0.5, nRows + 0.5], ...
            'c-', 'LineWidth', 0.75)
    end
end

hold(ax,'off')
xlim(ax, [0.5, nCols + 0.5])
ylim(ax, [0.5, nRows + 0.5])
end

function boundaries = gridBoundaryPositions(axisGrid, axisLength)
indices = unique([axisGrid.startIndex; axisGrid.endIndex + 1]);
boundaries = min(max(indices - 0.5, 0.5), axisLength + 0.5);
end

function I = readSeismogramImage(fullPath)
% Reads a scanned seismogram image and returns normalized grayscale data.

[Iraw, map] = imread(fullPath);

if ~isempty(map)
    Iraw = ind2gray(Iraw, map);
elseif ndims(Iraw) == 3
    Iraw = rgb2gray(Iraw(:,:,1:3));
end

I = im2double(Iraw);
I = rescale(I);
end
