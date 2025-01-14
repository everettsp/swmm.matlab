function swmm_tt2dat(tt,ffile_dat)
% writes a .dat raingauge file based on a filename (with full path)
% and a timetable
% raingauge ID must be specified by timetable variable name

% temp = load(path_tt);

if ~isregular(tt)
%     error('timetable is not regular, fix timesteps/missing values')
    make_regular = @(ttx) retime(ttx,'regular','nearest','TimeStep',ttx.Properties.RowTimes(2) - ttx.Properties.RowTimes(1));
    tt = make_regular(tt);
end

% % make sure rg filename has correct extension
% if ~contains(ffile_rg,'.dat')
%     ffile_rg = [ffile_rg '.dat'];
% end

%%
% if overwrite
% path_parse   = strfind(ffile_model,'\');
% model_name = ffile_model((path_parse(end)+1):end);
% path_parent = ffile_model(1:path_parse(end-1));
% path_rg = [path_parent 'rg'];
% 
% if ~exist(path_rg) == 7
%     mkdir(path_rg)
% end

% if numel(tt.Properties.VariableNames) > 1
%     ffile_rg = char(strcat('raingages','.dat'));
% elseif numel(tt.Properties.VariableNames) == 1
%     ffile_rg = char(strcat(tt.Properties.VariableNames,'.dat'));
% end


[num_rows,num_vars] = size(tt);
fid = fopen(ffile_dat,'w+');

% print headers to file
fprintf(fid, 'everett generated rainfall data file, do not edit');
fprintf(fid, ';%s\t%s\t%s\t%s\t%s\t%s\t%s\t\n',...
    'Station',...
    'Year',...
    'Month',...
    'Day',...
    'Hour',...
    'Minute',...
    'Precipitation');

% for each variable, print each row of the timetable, delimiting with tabs
for i1 = 1:num_vars
    data = tt(:,i1).Variables;
%     stn_id = char(tt.Properties.VariableNames{i1});
%     stn_cell = split(tt.Properties.VariableNames{i1},'_'); stn_id = stn_cell{1}; stn_pram = stn_cell{2}; stn_units = stn_cell{3};
    stn_id = tt.Properties.VariableNames{i1};
%     name_station = name_station(4:end); % remove the 'rg_' prefix from the station name
    % alphabetic prefix is necessary since raingages can have numeric IDs
    % in SWMM, need to store as timetablle...
    for i2 = 1:num_rows
        % write new content to file
        rowtime = tt.Properties.RowTimes(i2);
        
        fprintf(fid, '%s\t%04d\t%02d\t%02d\t%02d\t%02d\t%4f\n',...
            stn_id,...
            year(rowtime),...
            month(rowtime),...
            day(rowtime),...
            hour(rowtime),...
            minute(rowtime),...
            data(i2));
    end
end

fclose(fid);
% end
%% set options
% set the simulation start and end datetimes based on tt_event
% start_date = datestr(tt_event.Properties.RowTimes(1),'mm/dd/yyyy');
% start_time = char(timeofday(tt_event.Properties.RowTimes(1)));
% end_date = datestr(tt_event.Properties.RowTimes(end),'mm/dd/yyyy');
% end_time = char(timeofday(tt_event.Properties.RowTimes(end)));
% 
% % write parameters to swmm file
% swmm_options(ffile_model,...
%     'START_DATE',start_date,...
%     'START_TIME',start_time,...
%     'REPORT_START_DATE',start_date,...
%     'END_DATE',end_date,...
%     'END_TIME',end_time);
end