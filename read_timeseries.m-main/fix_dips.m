%remove_timeseries_dips.m
%
%written by Morgan Rife 7/21/26
%
%this script will
%1) calculate and remove the difference in IISAM range between timeseries'
%2) modify scaling issues by fixing standard deviation differences 
%it will do this through a specified time range of months of interest
close all
clear
clc

S = dir("C:\Users\mrife\Downloads\NPT\interpolated_timeseries\*.txt"); 
for i = 1:length(S)
    fName = S(i).name;
    fPath = S(i).folder;
end
%organization
stationName = fName(15:17);

 fullFilePath = fullfile(fPath, fName);
 newData = readmatrix(fullFilePath);
 x_datetime = datetime(newData(:, 1), 'ConvertFrom', 'datenum');

 isnov_first = (month(x_datetime) == 11) & (day(x_datetime) == 1);
 novFirstData = newData(isnov_first, :);
 month_numbers = month(x_datetime, 'monthofyear');
 
%relevant data for the specified months of interest
problemMonths = [8, 9, 10]; % Example: August, September, October
pMonths = ismember(month_numbers, problemMonths);
pMonths = pMonths | isnov_first;


datapMonths = newData(pMonths, :);
ydatapMonths = datapMonths(:,2);


dataGoodMonths = newData(~pMonths, :);
ydataGoodMonths = dataGoodMonths(:,2);
targetMin = min(ydataGoodMonths);
targetMax = max(ydataGoodMonths);
newpMonths = datapMonths;
%newpMonths(:,2) = rescale(ydatapMonths, targetMin, targetMax);
finalpMonths = newpMonths(:, 2);
probMonthsTime = datetime(datapMonths(:,1), 'ConvertFrom', 'datenum');
goodMonthsTime = datetime(dataGoodMonths(:,1), 'ConvertFrom', 'datenum');
plotData = newData(:, 2);
% Good Month Stats
goodMean = mean(ydataGoodMonths, 'omitnan');
goodStd  = std(ydataGoodMonths, 'omitnan');

% Prob Month stats
problemMean = mean(ydatapMonths, 'omitnan');
problemStd  = std(ydatapMonths, 'omitnan');

% Rescale and shift problem months up
finalpMonths = (ydatapMonths - problemMean) * (goodStd / problemStd) + goodMean;

plotData(pMonths) = finalpMonths;
plotTime = x_datetime;

figure;
hold on;

% Plot good months in blue
plot(plotTime, plotData, 'g', 'MarkerSize', 10);



xlabel('Time');
ylabel('Median IISAM');
title('Rescaled Median IISAM in 1974');
xticks(min(plotTime) : days(10) : max(plotTime));
xtickformat('MMM-dd');
grid on;

hold off;

outputData = [datenum(plotTime(:)), plotData(:)];
outFileName = [stationName, '_timeseries_undipped.txt'];
plots = fullfile(fPath, 'plots');

if ~exist(plots, 'dir')
    mkdir(plots);
end
outputPath = fullfile(plots, outFileName);
writematrix(outputData, outputPath, 'Delimiter', '\t');







