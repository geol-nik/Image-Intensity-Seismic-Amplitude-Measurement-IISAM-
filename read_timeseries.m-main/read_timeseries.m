%read_timeseries.m
%
%Written by Naomi Orcel, Morgan Rife, ALastair McCarthy 6/25/26
%
%this script will 
%1) read in daily text files from a single station
%2) create a matrix of these files containing dates and data
%3) interpolate, replace, and align IISAM data as a function of time
%4) read out continuous timeseries files for a specified range

close all
clear
clc

%Read in and store files
S = dir("F:\seismo_tremor_analysis-naming\1974_Smoke_Records_Out\crop\DES\timeseries\*.csv"); %fake directory for now, fill this in later when i have my hard drive - MSR

useMedian = true;

%IISAM = nan(size(t));
dataMatrix = []; % empty matrix to be filled with data from daily text files
fileEndMatrix = [];
%Loop over every file in the folder
for i = 1:length(S)
    %Take the filepath & filename of each txt file, put them in a temp
    %"newData" variable
    fName = S(i).name;
    fPath = S(i).folder;

    fullFilePath = fullfile(fPath, fName);

    newData = readmatrix(fullFilePath);
    
    nSamples = size(newData,1);
    dayNum = i;                   % start daycounter -MSR 6/26/26
    newData(:,3) = newData(:,3) + (dayNum-1)*24;

    dataMatrix = [dataMatrix; newData]; % Append new data to the matrix
  fileEndMatrix(end+1) = size(dataMatrix,1);
end
%Using median vs using average
if useMedian
    datTemp = dataMatrix(:,5);   % Median IISAM
else
    datTemp = dataMatrix(:,4);   % Average IISAM
end

% Cut out value jumps at actual file boundaries -MSR 6/29/26
datTemp_Cut = datTemp;

cutWindow = 7;   % removes 7 samples around each file boundary, 3.5 hours of data...

for j = 1:length(fileEndMatrix)-1 %Loops through every file boundary except the very last one.
    k = fileEndMatrix(j);

    idx1 = max(1,k-cutWindow);
    idx2 = min(length(datTemp_Cut),k+cutWindow); %creates splice window

    datTemp_Cut(idx1:idx2) = NaN; %replaces spliced parts with NaNs
end

disp(['Points removed before filling: ', num2str(sum(isnan(datTemp_Cut)))]) %tells us how many points are removed before we interpolated gaps

% Fill across removed splice regions
datTemp_Cut = fillmissing(datTemp_Cut,'linear');

disp(['Points removed before filling: ', num2str(sum(isnan(datTemp_Cut)))])%makes sure we didnt somehow leave a gap unfilled

% Interpolate across removed splice points-MSR 6/29/26
datTemp_Cut = fillmissing(datTemp_Cut,'linear');

%fix time vector, make sure to make files+1 in folder
  t = 0:0.5:max(dataMatrix(:,3));    % every 30 minutes for 30 days, new time vector
   %t = 0:0.5:max(dataMatrix(:,3));
   qy = interp1(dataMatrix(:,3), datTemp_Cut, t, 'linear', NaN); %estimate iisam values at regular intervals of time, t
   qyFilled = fillmissing(qy,'linear','EndValues','nearest'); % fills gaps made by NaNs with linear values
   smoothQy = smoothdata(qyFilled,'movmedian',7); %smooths data with moving median filter

%make new matrix for interp data vs new time, save to .txt -MSR 6/29/26
outputData = [t(:), smoothQy(:)];

outFile = fullfile(fPath,'DES_interpolated_timeseries.txt');
writematrix(outputData,outFile,'Delimiter','tab');

figure;

%plots to see if stuff is working - MSR 6/26/26
figure;

%Check continuity of time
subplot(4,1,1)
plot(dataMatrix(:,3),'.')
grid on
ylabel('Hours')
xlabel('Index')
title('Check: Continuous Time')

%Check time gaps
subplot(4,1,2)
plot(diff(dataMatrix(:,3)))
grid on
ylabel('\Deltat (hours)')
xlabel('Index')
title('Time Step Check')

%Raw data vs cleaned
subplot(4,1,3)
plot(dataMatrix(:,3),datTemp,'.','MarkerSize',6)
hold on
plot(dataMatrix(:,3),datTemp_Cut,'LineWidth',1.5)
legend('Raw IISAM','Splice spikes removed','Location','best')
grid on
xlabel('Hours')
ylabel('IISAM')
title('Raw vs Splice-Corrected')

%Final interpolated time series vs raw data -MSR 6/29/26
subplot(4,1,4)
plot(dataMatrix(:,3),datTemp,'.','MarkerSize',6)
hold on
plot(t,smoothQy,'LineWidth',1.5)
legend('Raw IISAM','Interpolated cleaned','Location','best')
grid on
xlabel('Hours')
ylabel('IISAM')
title('Final Interpolated Time Series')
