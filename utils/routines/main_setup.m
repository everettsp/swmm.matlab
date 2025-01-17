function cfg = main_setup(ffile_cfg, varargin)
%% author: Everett Snieder - PhD Candidate - York University
% this script
% (1) creates SWMM files from shapefiles generated in ArcPy
% shapefiles represent subcatchments, conduits, junctions, etc.
% (2) events are discretised based on mean precip. data for each
% catchment
% (3) clusters events based on event statistics using SOM
% (4) executes 'prerun' script which generates RFF and HSF files for each event
% RFF (binary rainfall) and HSF (hotstart) are used during model cal. later
%%

par = inputParser;
addParameter(par,'overwrite',false)
parse(par,varargin{:})
overwrite = par.Results.overwrite; %whether to overwrite saved results file


if ~isfile(ffile_cfg) || overwrite

    % config file contains one entry for each SWMM base model
    cfg = struct();
    cfg(1).catchment = 'scs';
    cfg(end+1).catchment = 'tcs';
    path_mdls = 'C:\Users\everett\Google Drive\02_phd\00_projects_major\02_swmm_calibration\mdls\';

    %%
    % populate paths
    for k2 = 1:numel(cfg)
        catchment = cfg(k2).catchment;
        dir_mdl = [path_mdls,catchment,'\'];

        dir_mdl_data = [dir_mdl,'\data\'];
        if ~isfolder(dir_mdl_data)
            mkdir(dir_mdl_data)
            addpath(genpath(dir_mdl_data));
        end

        dir_figs = [dir_mdl,'figs\'];
        if ~isfolder(dir_figs)
            mkdir(dir_figs)
            addpath(genpath(dir_figs));
        end



        % create .mat file for rainfall/flow data
        ffile_data = [dir_mdl_data,'data.mat'];
        ffile_events_raw = [dir_mdl_data,'events_raw.mat'];
        ffile_events = [dir_mdl_data,'events.mat'];

        cfg(k2).mdl = '';
        cfg(k2).dir_mdl = dir_mdl;
        cfg(k2).ffile_data = ffile_data;
        cfg(k2).ffile_events = ffile_events;
        cfg(k2).ffile_events_raw = ffile_events_raw;
        cfg(k2).dir_figs = [dir_mdl,'figs\'];

    end
    %%
    for k2 = 1:numel(cfg)
        if ~exist(cfg(k2).ffile_data)

            % import shapefiles generated by ArcPy code
            mdl = import_shp_fun([dir_mdl,'mdl.inp'],'suffix','');

            % ugly fix for error that occured during ArcGIS
            if k2 == 2
                mdl.p.subcatchments.RainGage{1} = 'HY094';
            end


            catchment = cfg(k2).catchment;
            % create import table for TRCA hydrological data
            stns_precip = cell2table(lower(mdl.p.raingages.Name),'VariableNames',{'id'});
            stns_precip.type = repmat({'precip'},[height(stns_precip),1]);
            stns_precip.units = repmat({'mm'},[height(stns_precip),1]);

            stns_wl = cell2table(lower(mdl.p.outfalls.Name),'VariableNames',{'id'});
            stns_wl.type = repmat({'flow'},[height(stns_wl),1]);
            stns_wl.units =  repmat({'cms'},[height(stns_wl),1]);

            stns = [stns_precip;stns_wl];

            tts = import_trca(stns);

            tt_precip = tts(:,contains(tts.Properties.VariableNames,'precip'));
            tt_flow = tts(:,contains(tts.Properties.VariableNames,'flow'));



            % calculate the weighted mean precip
            % if a station samples are missing, calc. mean using non-nan stations
            num_stations = size(tt_precip,2);
            sc = mdl.p.subcatchments;

            sc_area = zeros(num_stations,1);
            fprintf('rain gages: ')
            for i2 = 1:num_stations
                stn_cell = split(tt_precip.Properties.VariableNames{i2},'_');
                stn_id = stn_cell{1}; stn_pram = stn_cell{2}; stn_units = stn_cell{3};
                ldx = contains(upper(strcat(sc.RainGage)), upper(stn_id));
                if ~any(ldx)
                    sc_area(i2) = 0;
                else
                    sc_area(i2) = sum(table2array(sc(ldx,'Area')));
                end
            end

            tt_precip_mean = timetable(tt_precip.Properties.RowTimes,...
                nansum(tt_precip.Variables .* ((~isnan(tt_precip.Variables) .* sc_area') ./ (~isnan(tt_precip.Variables) * sc_area)),2),...
                'VariableNames',{'precip'});
            tt_precip_mean(all(isnan(tt_precip.Variables),2),:).Variables = nan(sum(all(isnan(tt_precip.Variables),2)),1);

            % if fewer than all stations are nan, replace nan with weighted mean precip
            for i2 = 1:width(tt_precip)
                idx = isnan(tt_precip(:,i2).Variables);
                tt_precip(idx,i2).Variables = tt_precip_mean(idx,:).Variables;
            end

            % save the model and timeseries data to .mat file
            save(ffile_data,'mdl','tt_precip','tt_precip_mean','tt_flow')

        end
    end

    for k2 = 1:numel(cfg)
        if ~exist(cfg(k2).ffile_events_raw)
            dat = load(cfg(k2).ffile_data);
            mdl = dat.mdl;
            tt_flow = dat.tt_flow;
            tt_precip = dat.tt_precip;
            tt_precip_mean = dat.tt_precip_mean;

            catchment = cfg(k2).catchment;

            % make sure both flow and precip observations are available (don't want events where we have no data with which to cal.)
            available_flow = ismember(tt_precip.Properties.RowTimes,tt_flow.Properties.RowTimes);

            % discretise events
            events = events_summarize(tt_precip_mean(available_flow,:),hours(12),'event_threshold',5);


            tt_precip_dat = tt_precip;
            for i2 = 1:width(tt_precip)
                stn_cell = split(tt_precip_dat.Properties.VariableNames{i2},'_'); stn_id = stn_cell{1}; stn_pram = stn_cell{2}; stn_units = stn_cell{3};
                tt_precip_dat.Properties.VariableNames{i2} = upper(stn_id);
            end

            % add multi-gauge timeseries to event struct (events were discretised
            % based on aggregated precip)
            for i2 = 1:numel(events)
                events(i2).tt_rg = tt_precip_dat(events(i2).idx,:);
                [t,x] = get_centroid(events(i2).tt(:,'precip'));
                events(i2).p_cy = x;
                events(i2).p_ct = hours(t - events(i2).start_date);
            end
            clear tt_precip_dat

            %         acceptable_months = [4:10];
            %         events = events((ismember(month([events.start_date]),acceptable_months) & ...
            %             ismember(month([events.end_date]),acceptable_months)));

            % sort by total precip.
            [~,idx] = sort([events.date_rad],'ascend');
            events0 = events(idx);

            events = events_flow(tt_flow,events0);

            % check flow, precip, and warmup period for nan values
            idx = nan(numel(events),4);
            for i2 = 1:numel(events)
                idx(i2,1) = sum(any(isnan(events(i2).tt_fg.Variables),2));
                idx(i2,2) = sum(any(isnan(events(i2).tt_rg.Variables),2));
                idx(i2,3) = sum(any(isnan(events(i2).tt.Variables),2));
                prerun_duration = days(1);
                prerun_timerange = timerange(events(i2).tt_rg.Properties.RowTimes(1)-prerun_duration,events(i2).tt_rg.Properties.RowTimes(1));
                idx(i2,4) = sum(any(isnan(tt_precip(prerun_timerange,:).Variables),2));
            end
            idx = all(idx == 0,2); % remove event if any nans in precip or flow
            events = events(idx);

            % calculate flow centroids (could move this to event discr. script but
            % it's a bit of an uncommon statistic and is slow to calc., so prefer
            % keeping it out of a more general fun...)
            for i2 = 1:numel(events)
                [t,x] = get_centroid(events(i2).tt_fg);
                events(i2).q_cy = x;
                events(i2).q_ct = hours(t - events(i2).start_date);
            end
            events_raw = events;
            clear events;
            save(cfg(k2).ffile_events_raw,"events_raw")

        end
    end

    %%
    for k2 = 1:numel(cfg)
        dat = load(cfg(k2).ffile_data);
        mdl = dat.mdl;

        dat = load(cfg(k2).ffile_events_raw);
        events = dat.events_raw;
        catchment = cfg(k2).catchment;
        % convert events to 2D table
        events_tbl = struct2table(events);

        % create clustering feature set
        x_tbl = events_tbl(:,{'total','intensity_peak','intensity_mean','duration_hours','date_sine','date_cosine','qp','q_vol','q_cy','q_ct','p_cy','p_ct'});
        x_tbl.Properties.VariableNames = {'P','i_{p}','i_{\mu}','D','date\_sine','date\_cosine','q_{p}','Q','q_{cy}','q_{ct}','p_{cy}','p_{ct}'};
        x = x_tbl.Variables';

        num_clusters = 2;
        [x_classes, centroids] = cluster_som(x',[1,num_clusters]);

        % supplementary PCA analysis
        % cluster events with PCA feature set reduction
        % incrementally include more PCs and look at absolute error between
        % non-PC and PC reduced clustering
        % error is expected to tend towards 0 as number of PCs incr.
        max_pcas = 12;
        pca_diff = nan(11,1);
        [pcas,~,~] = pca(x');
        n_events = size(x_tbl,1)/2;
        for i2 = 1:max_pcas
            [x_classes_pca, centroids_pca] = cluster_som(x' * pcas(:,1:i2),[1,num_clusters]);
            pca_diff(i2) = sum(abs(x_classes_pca - x_classes));
            if pca_diff(i2) > n_events || pca_diff(i2) < -n_events
                pca_diff(i2) = n_events*2 - pca_diff(i2);
            end

        end


        % add clustering data to event table
        x_tbl.class = x_classes;

        x_dist = nan(size(x_classes));
        for i2 = 1:numel(x_classes)
            x_dist(i2) = sqrt(sum((centroids(x_classes(i2),:) - x(:,i2)').^2)); % euclid. norm from centroid
        end




        % sort classes 1:n_classes based on flow magnitude (this is typically the
        % most important classification feature)

        n_classes = max(unique(x_classes));
        mean_flow = nan(n_classes,1);
        for i2 = 1:n_classes
            mean_flow(i2) = mean([events(x_classes==i2).q_vol]);
        end
        [~,ind] = sort(mean_flow,'ascend');
        x_classes_new = x_classes;
        for i2 = 1:n_classes
            x_classes_new(x_classes == i2) = ind(i2);
        end
        x_classes = x_classes_new;
        x_tbl.class = x_classes;



        num_events_split = 10;

        events_tbl.class = x_classes;
        events_tbl.class_ed = x_dist;

        num_clusters = max(unique(x_classes));

        % evenly divide events for calibration and validation (legacy code)
        events_tbl.keep = false(height(events_tbl),1);

        for i2 = 1:num_clusters
            idx1 = find(events_tbl.class == i2);
            [~,idx2] = sort(events_tbl.class_ed(idx1),1,'ascend');
            idx3 = idx1(idx2(1:num_events_split));
            events_tbl.keep(idx3(1:num_events_split)) = true;
        end

        idx = events_tbl.keep;
        events_selected = table2struct(events_tbl(idx,:));
        % sort events by day of year
        [~,idx] = sort([events_selected.start_date],'ascend');
        events_selected = events_selected(idx);

        idx_random = randperm(numel(events));
        idx_random = idx_random(1:(num_events_split * num_clusters));
        events_random = table2struct(events_tbl(idx_random,:));
        [~,idx] = sort([events_random.start_date],'ascend');
        events_random = events_random(idx);

        events_selected = mdl.prerun(events_selected,'overwrite',false);
        events_random = mdl.prerun(events_random,'overwrite',false);

        save(cfg(k2).ffile_events,"events","events_selected", "events_random","max_pcas","pca_diff","x_tbl", "catchment","centroids")
        % save selected events in model config obj.


    end

    save(ffile_cfg,'cfg')

else
    dat = load(ffile_cfg);
    cfg = dat.cfg;
end
end