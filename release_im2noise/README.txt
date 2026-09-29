im2noise documentation
==============================

Files in this release folder
----------------------------

    im2noise.m
        Main script. This is intentionally kept close to the original working
        im2noise.m script. Open it in MATLAB, edit the SETTINGS section, and
        run it.

    edgeCrop_20260402.m
        Helper function used by im2noise.m to automatically crop the scanned
        seismogram record away from the surrounding page/background.

    gridSeismogramIntensity.m
        Helper function used by im2noise.m to divide the cropped image into
        time windows and calculate average and median pixel intensity.


Purpose
-------

im2noise.m converts scanned seismogram images into image-intensity time
series. The basic idea is:

1. Read each scanned seismogram image from an input folder.
2. Convert the image to normalized grayscale pixel values.
3. Crop the image down to the seismogram record.
4. Divide the cropped image into time windows.
5. Measure average and median pixel intensity inside each window.
6. Write one CSV and one TXT time-series file per image.

The exported intensity values are relative image-based proxies. They are not
calibrated physical ground-motion measurements. They are most useful when
comparing scans that were digitized in a similar way.


Requirements
------------

    MATLAB
    Image Processing Toolbox

Supported input image extensions:

    .tif
    .tiff
    .jpg
    .jpeg
    .png


How to run
----------

1. Open MATLAB.

2. Change into this release folder:

       cd(release_im2noise folder)

3. Open im2noise.m.

4. Edit the SETTINGS section near the top of the file.

5. Run im2noise.m.

The script is not written as a function. You do not call it with input
arguments. Instead, you edit variables in the SETTINGS section and run the
script.


Important settings in im2noise.m
--------------------------------

Input folder:

    c_imin = "full directory path";

This is the folder containing scanned seismogram images.

Output folder:

    c_datout = "full directory path";

This is where outputs are written. The script creates needed subfolders.

Edge finding:

    prctsmooth = 1.5;
    invertrecord = false;

prctsmooth is retained from the original workflow, but the current automatic
crop helper mostly controls crop behavior internally. invertrecord should be
set to true when the trace is light on a dark background.

Window parameters:

    r_length = 24;
    w_length = 0.5;
    w_step   = 0.5;

r_length is the total record length in hours. w_length is the duration of one
analysis window in hours. w_step is the step between windows in hours. With
the defaults, a 24-hour record is sampled in 30-minute windows.

Interactive behavior:

    ui.interactive = true;
    defaultStation = "";
    defaultComponent = "";

When ui.interactive is true, the script asks the user to confirm metadata and
review the crop for each image. When false, it runs unattended using defaults
and automatic cropping.

Diagnostic plotting:

    diag.og = false;
    diag.crop = false;
    diag.intensity = false;
    diag.grid = false;
    diag.color = false;
    diag.hist = false;

Set these to true to write diagnostic plots. The most useful options are
diag.crop, diag.intensity, diag.grid, and diag.hist.


Input filename date handling
----------------------------

The script reads metadata from each filename using this exact pattern:

    YYYYMMDD_HHmm_STA_CMP

Example:

    19380402_0000_HVO_Z.jpg

Where:

    YYYY
        four-digit year

    MM
        two-digit month

    DD
        two-digit day

    HH
        two-digit hour, 24-hour time

    mm
        two-digit minute

    STA
        station code

    CMP
        component code

If the filename does not match this pattern in interactive mode, the metadata
dialog leaves the filename-derived fields blank for manual entry. The script
does not fill missing metadata from the file modification timestamp. If
interactive mode is disabled and filename metadata is missing, the image is
flagged for review.

In interactive mode, the metadata dialog lets you correct:

    year
    month
    day
    start time
    record length
    station code
    component code


Interactive crop controls
-------------------------

After metadata entry, the script displays the automatic crop.

Automatic crop preview:

    Y
        Accept the automatic crop.

    N
        Draw a manual crop rectangle.

    F
        Flag the file for review and skip it.

Manual crop preview:

    Enter
        Accept the manual crop.

    R
        Redraw the manual crop.

If a file is cancelled, flagged, unreadable, or uncroppable, the original
image is copied into the review folder.


Output folders
--------------

The script creates these folders under c_datout as needed:

    review/
        Input images copied here when they need manual review.

    timeseries/
        Main CSV and TXT time-series outputs.

When diagnostics are enabled, additional folders may be created:

    crop/
        Cropped image diagnostic plots.

    intensity/
        Intensity vs. time plots.

    grid/
        Grid overlay plots showing the analysis windows.

    hist/
        Pixel intensity histograms.


Main CSV output
---------------

For each processed image, the script writes:

    timeseries/<image_name>_intensity_timeseries.csv

CSV columns:

    Station
        Station code entered by the user or defaultStation.

    Date
        Record start date/time formatted as yyyy-mm-dd HH:MM:SS.

    Time
        Center of the time window in hours from the start of the record.

    AvgInt
        Average pixel intensity for that time window.

    MedInt
        Median pixel intensity for that time window.

Example:

    Station,Date,Time,AvgInt,MedInt
    UNK,1938-04-02 00:00:00,0.2500,0.512345,0.498765


Plain text output
-----------------

For each processed image, the script also writes:

    timeseries/<image_name>_intensity_timeseries.txt

TXT columns:

    Time
    AvgInt
    MedInt

This file is tab-delimited.


Script flow
----------------------

im2noise.m is organized into sections:

    INIT
        Closes figures, clears workspace variables, and clears the command
        window.

    SETTINGS
        Contains all user-editable paths, window lengths, interactive mode,
        defaults, and diagnostic switches.

    SETUP OUTPUT DIRECTORIES
        Creates c_datout and review/. If diagnostic plotting is enabled, this
        section also creates diagnostic output folders.

    MAKE TIMESERIES CSV FOLDER
        Creates timeseries/.

    LOAD IMAGE FILE LIST
        Finds all supported image files in c_imin.

    MAIN LOOP THROUGH FILES
        Processes every image found in c_imin.

Inside the main loop, each image goes through:

1. Parse filename date if possible.
2. Read image.
3. Optionally invert image.
4. Ask for metadata and crop review when ui.interactive is true.
5. Automatically crop when ui.interactive is false.
6. Divide the crop into windows with gridSeismogramIntensity.
7. Optionally make diagnostic plots.
8. Write CSV output.
9. Write TXT output.


Image reading
-------------

The local readSeismogramImage function is at the bottom of im2noise.m.

It performs these steps:

1. Read the image with imread.
2. If the image has an indexed colormap, convert it with ind2gray.
3. If the image is RGB, convert it to grayscale with rgb2gray.
4. Convert the result to double precision with im2double.
5. Rescale intensities to the range 0 to 1.

The rest of the workflow assumes the image is grayscale double data.


Automatic cropping
------------------

Automatic cropping is handled by edgeCrop_20260402.m.

The helper:

1. Converts the image to double precision.
2. Converts color images to grayscale by averaging channels.
3. Normalizes the image.
4. Downscales the image to speed up crop detection.
5. Removes broad horizontal banding with a moving average subtraction.
6. Computes row energy to find the active vertical record region.
7. Computes column energy to find the active horizontal record region.
8. Finds the largest continuous active region in rows and columns.
9. Scales crop limits back to the original image size.
10. Returns the cropped image and crop limits.

Returned values:

    Icrop
        Cropped image.

    limits.tlim
        Top crop limit.

    limits.blim
        Bottom crop limit.

    limits.llim
        Left crop limit.

    limits.rlim
        Right crop limit.

In interactive mode, the automatic crop is only a suggestion. The user can
accept it, replace it with a manual rectangle, or flag the image.


Grid and intensity calculations
-------------------------------

Intensity windowing is handled by gridSeismogramIntensity.m.

The script calls it like this:

    grids = gridSeismogramIntensity(Icrop, recordLengthHours, w_length, w_step, true);

Inputs:

    Icrop
        Cropped seismogram image.

    recordLengthHours
        Total record duration in hours.

    w_length
        Window length in hours.

    w_step
        Step between windows in hours.

    true
        Tells the helper to calculate row windows, column windows, and
        row-by-column box summaries.

The helper converts time windows to pixel windows:

    windowFraction = w_length / recordLengthHours
    stepFraction   = w_step / recordLengthHours

    windowLengthPx = round(windowFraction * axisLengthPx)
    windowStepPx   = round(stepFraction * axisLengthPx)

For row windows, each window is a horizontal band across the cropped image.
For each row band, the helper calculates:

    averageIntensity
    medianIntensity
    sampleCount
    startIndex
    endIndex
    centerPixel
    normalizedPosition
    timeEquivalentHours

The time value is based on the center of the window:

    normalizedPosition = (centerPixel - 0.5) / axisLengthPx
    timeEquivalentHours = normalizedPosition * recordLengthHours

im2noise.m uses:

    grids.box.rowAverageIntensity
    grids.box.rowMedianIntensity
    grids.row.timeEquivalentHours

These become AvgInt, MedInt, and Time in the output files.


Diagnostic plots
----------------

If enabled, diagnostics help verify that the script is analyzing the correct
part of the record.

    diag.crop
        Saves the cropped seismogram image.

    diag.intensity
        Saves average and median intensity vs. time.

    diag.grid
        Saves the cropped image with row and column grid boundaries overlaid.

    diag.hist
        Saves a histogram of cropped-image pixel intensities.

The local drawGridOverlay function in im2noise.m draws the grid plot.
gridBoundaryPositions converts start and end indices from
gridSeismogramIntensity into line positions for plotting.


Function and file map
---------------------

im2noise.m:

    Main script body
        Controls settings, file discovery, metadata, cropping, windowing,
        plotting, and output writing.

    drawGridOverlay
        Local helper that plots the row and column grid over a cropped image.

    gridBoundaryPositions
        Local helper that converts grid window indices into plot boundary
        coordinates.

    readSeismogramImage
        Local helper that reads and normalizes an image.

edgeCrop_20260402.m:

    edgeCrop_20260402
        External helper that automatically crops the record region.

gridSeismogramIntensity.m:

    gridSeismogramIntensity
        External helper that builds row, column, and box intensity grids.

    prepareCrop
        Converts crop data to double precision and handles non-finite values.

    buildAxisGrid
        Builds either row-window or column-window statistics.

    buildBoxGrid
        Builds row-by-column intensity statistics.

    validateGridInputs
        Checks that record length and window sizes are valid.


Common edits
------------

Change the input folder:

    c_imin = "C:\your\scan\folder";

Change the output folder:

    c_datout = "C:\your\output\folder";

Run without prompts:

    ui.interactive = false;

Run with manual metadata and crop review:

    ui.interactive = true;

Use 15-minute windows on a 24-hour record:

    r_length = 24;
    w_length = 0.25;
    w_step = 0.25;

Use overlapping 30-minute windows every 15 minutes:

    r_length = 24;
    w_length = 0.5;
    w_step = 0.25;

Invert light-on-dark records:

    invertrecord = true;

Save grid diagnostics:

    diag.grid = true;


Troubleshooting
---------------

Problem:
    The script says no images were found.

Likely cause:
    c_imin points to the wrong folder, or the folder does not contain supported
    image types.

Fix:
    Check c_imin and confirm the folder contains .tif, .tiff, .jpg, .jpeg, or
    .png files.

Problem:
    Crops are wrong.

Fix:
    Run with ui.interactive = true and manually redraw bad crops. You can also
    inspect diag.crop and diag.grid outputs.

Problem:
    Many files are copied to review/.

Likely causes:
    The image cannot be read, the crop failed, metadata was cancelled, or the
    crop was too small.

Fix:
    Process a few files interactively first and check whether the scans need
    manual crop rectangles.

Problem:
    Time values do not match the record.

Likely cause:
    r_length, w_length, or w_step does not match the actual scan.

Fix:
    Edit the window parameters in SETTINGS.

Problem:
    Output intensity is inverted from what you expect.

Fix:
    Change invertrecord. Use false for normal dark trace on light background.
    Use true for light trace on dark background.


Suggested validation workflow
-----------------------------

1. Set c_imin to a folder with one or two representative scans.

2. Set ui.interactive = true.

3. Set diag.crop = true and diag.grid = true.

4. Run im2noise.m.

5. Confirm the crop and grid look correct.

6. Inspect the CSV in timeseries/.

7. Once the settings look good, set c_imin to the full scan folder.

8. Optionally set ui.interactive = false for unattended batch processing.


Version note
------------

This release package was revised on 2026-05-13 to keep im2noise.m in the same
script-style structure as the original working file. The helper files it calls
are included in this folder so the script can be run from the release folder.
