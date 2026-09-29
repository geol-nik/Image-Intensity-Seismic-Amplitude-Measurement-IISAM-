%plot_stations_together.m
%
%
S = dir('C:\Users\mrife\Downloads\Timeseries_Undipped\Undipped_txt\*.txt');
DES = [];
MLO = [];
NPT = [];
PAU = [];
%
% Extract file names from the structure array
for i = 1:length(S)
    fName = S(i).name;
    fPath = S(i).folder;
fullFilePath = fullfile(fPath, fName);
dataMatrix = readmatrix(fullFilePath);
   if contains(fName, 'DES')
        DES = [DES; dataMatrix]; % Vertically stacks the columns
    elseif contains(fName, 'MLO')
        MLO = [MLO; dataMatrix];
    elseif contains(fName, 'NPT')
        NPT = [NPT; dataMatrix];
    elseif contains(fName, 'PAU')
        PAU = [PAU; dataMatrix];
   end
end

DES_time = datetime(DES(:,1), 'ConvertFrom', 'datenum');
NPT_time = datetime(NPT(:,1), 'ConvertFrom', 'datenum');
PAU_time = datetime(PAU(:,1), 'ConvertFrom', 'datenum');
MLO_time = datetime(MLO(:,1), 'ConvertFrom', 'datenum');





subplot(4,1,1)
plot(DES_time, (DES(:,2)),'r', 'LineWidth', 1.5)
ylabel('Value');
title('DES Time Series Data');
grid off;



subplot(4,1,2)
plot(NPT_time, (NPT(:,2)),'b','LineWidth', 1.5)
ylabel('Value')
title('NPT Time Series Data')
grid off;



subplot(4,1,3)
plot(PAU_time, (PAU(:,2)), 'magenta','LineWidth', 1.5)
ylabel('Value')
title('PAU Time Series Data')
grid off;



subplot(4,1,4)
plot(MLO_time, (MLO(:, 2)), 'g','LineWidth', 1.5)
ylabel('Value')
title('MLO Time Series Data')
grid off;
hold on;

figure
plot(DES_time, (DES(:,2)),'r', 'LineWidth', 1.5)
ylabel('Value');
title('DES Time Series Data');
grid off;
hold on;

figure
plot(NPT_time, (NPT(:,2)),'b','LineWidth', 1.5)
ylabel('Value')
title('NPT Time Series Data')
grid off;
hold on;

figure
plot(PAU_time, (PAU(:,2)), 'magenta','LineWidth', 1.5)
ylabel('Value')
title('PAU Time Series Data')
grid off;
hold on;

figure
plot(MLO_time, (MLO(:, 2)), 'g','LineWidth', 1.5)
ylabel('Value')
title('MLO Time Series Data')
grid off;
hold off;
