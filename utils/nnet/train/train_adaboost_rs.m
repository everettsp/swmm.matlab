function [nets, ww, info] = train_adaboost_rs(net, inp_0, obs_0, m, phi_fixed, error_exponent,varargin)
% implementation of Adaboost.RT (Solomatine 2004; Solomatine 2006)
%
% REQUIRED PARAMETERS----------
% net_0 is an untrained artificial neural network (matlab object)
% inp_0 is input data (column-wise samples)
% obs_0 is target data
% n_boosts is the number of boosts (T)
% phi is the relative error threshold (phi)
% error_exponent is the exponent applied to the model error calculation (n)
% resample_or_reweight indicates whether to resample the input set or weight the training cost function
% 
% OPTIONAL PARAMETERS----------
% plot is a boolean statement indicating whether to produce summary plots

par = inputParser;
addParameter(par,'rsf',@resample_default)
parse(par,varargin{:})
rsf = par.Results.rsf;



net_0 = net;
inp = inp_0;
tgt = obs_0;

if size(inp,2) ~= size(tgt,2)
    error('dimensions must agee')
end


% get data partiton indices

if ~strcmp(net_0.DivideFcn,'divideind')
    error('adaboost only support pre-partitioned datasets (net.DivideFcn = divideind)')
end

[~,n_samples] = size(inp);
[n,idx,ldx] = split_divideparams(net,n_samples); % extract number of sampels and indices from ANN


% assign uniform weighting schemes to validation and test data
% ew_val = ones(1,numel(idx_val)) ./ numel(idx_val);
% ew_test = ones(1,numel(idx_test)) ./ numel(idx_test);

T = m;

% initialize adaboost parameters
adb_beta = NaN(T,1);
epsilon = NaN(T,1);
phi = NaN(T,1);

% obs_train = NaN(n_boosts,n);  % training observations
% obs_train(1,:) = tgt;    % training observations
% ew_train = NaN(n_boosts,n);   % weighting

% initialize weights for tvt
D = NaN(T,n.all);
D2 = [];

for s2 = ["train","val","test"]; D(1,idx.(s2)) = 1/n.(s2); end

out = NaN(T,n.all);              % ann prediction
out_mean = NaN(T,n.all);         % weighted mean prediction
are = NaN(T,n.all);        % average relative error
phi_gt = false(T,n.all);   % error true
train_loss = NaN(T,1);       % training error
val_loss = NaN(T,1);         % validation error
test_loss = NaN(T,1);        % testing error
loss_fcn = @(x,y) nansum((x-y).^2) ./ numel(x(~(isnan(x) | isnan(y)))); % mean squared error
nets = cell(T,1);

nrml = @(x) x/nansum(x);

for t2 = 1:T
    
    [net2,inp2,tgt2] = rsf(net_0,[inp;D(t2,:)],tgt);
    D2(t2,:) = inp2(end,:); % concatenate the weight vector to the inputs, such that SMOTE will synthetically estimate new weight values, instead of using initial weight values as in (Diez-Pastor2015a)
    inp2 = inp2(1:(end-1),:);
    n_samples = numel(tgt2);
    
    [n2,ind2,idx2] = split_divideparams(net2,n_samples); % extract number of sampels and indices from ANN

    D2(t2,:) = nrml(D2(t2,:)); % normalize
    for s2 = ["train","val","test"]; D(t2,idx.(s2)) = 1/n.(s2); end

%     n_synth = numel(tgt_synth);
    
%     switch lower(resample_or_reweight)                                      % specify whether to resample or reweight...
%         case {'resample','sample','rs'}
%             net_rs = net_0;                                             % copy the initialized ANN
            net3 = net2;
            if t2 > 1                                                       % if not the first model, resample training obs

%                 idx_train_rs = randsample(idx_train,n_train,true,D(t2,idx_train));  % get resample indices
%                 idx_val_rs = randsample(idx_val,n_val,true,D(t2,idx_val));  % get resample indices
                
%                 net_resample.DivideParam.trainInd = idx_train_rs;           % set training indices
%                 net_resample.DivideParam.trainInd = idx_val_rs;


                [net3,~,~] = resample_weighted(net2,inp2,tgt2,D2(t2,:));

                %               
%         obs_train(t2,:) = obs(idx_train_rs);
                
            end
%             obs_train(t2,:) = obs(idx_adb);                            % store the resampled trainig obs
            [nets{t2}, trns{t2}] = train(net3, inp2, tgt2);      % train using the resampled train data
            
%         case {'reweight','weight','rw','ew'}                                % initialize new error weight vector
%             ew_train(t2,idx_adb) = D(t2,:);                               % get error weights from D matrix
% %             ew_train(t2,idx_val) = ew_val;                                  % uniform weights for validaiton data
%             ew_train(t2,idx_test) = ew_test;                                % uniform weights for test data
%             nets{t2} = net_0;
%             [nets{t2}, trns{t2}] = ...
%                 train(net_0, inp, tgt,{},{},ew_train(t2,:));                  % train using weighted loss function
%     end
    
    out(t2,:) = nets{t2}(inp);                                              % compute model output
    are(t2,:) = abs(tgt-out(t2,:))./tgt;      % average relative error
    if t2 == 1
        phi_fixed = prctile(are(t2,idx.cal),phi_fixed);      % dynamically recalculate phi (of data used for calib.)
    end
    
    phi(t2) = phi_fixed;
    phi_gt(t2,:) = are(t2,:) > phi(t2);                                     % get samples greater than phi
    
    if ~any(phi_gt(t2,:))
        disp('no error above threshold, terminating...')
        break
    end
    
    
    epsilon(t2) = nansum(D(t2, ldx.val & phi_gt(t2,:)));                               % calculate error (on train set)
    adb_beta(t2) = epsilon(t2).^error_exponent;                             % calculate error
    
    ww = log(1./adb_beta(1:t2));                                            % model weight (RT method)
    ww = nrml(ww);
    
%     ldx = ~(isnan(tgt) | any(isnan(out(1:t2,:)),1)) & ismember((1:numel(tgt)),idx_train); % model weight (+ method)
%     ww2 = out(1:t2,ldx)'\tgt(ldx)';
    out_mean(t2,:) = ww' * out(1:t2,:);
%     out_mean(t2,:) = ww' * out(1:t2,:) / sum(ww);                           % weighted mean prediction
    loss = struct();
    
    for s2 = ["train","val","test","cal"]; loss.(s2) = loss_fcn(tgt(idx.(s2)),out_mean(t2,idx.(s2))); end
    
%     train_loss(t2) = loss_fcn(tgt(idx.train),out_mean(t2,n_cal));
%     val_loss(t2) = loss_fcn(tgt(idx_val),out_mean(t2,idx_val));
%     test_loss(t2) = loss_fcn(tgt(idx_test),out_mean(t2,idx_test));
%     
    if t2 ~= T                                                       % if it's not the final iteration
        D(t2+1,~phi_gt(t2,:)) = D(t2,~phi_gt(t2,:)) .* adb_beta(t2);        % update weights
        D(t2+1,phi_gt(t2,:)) = D(t2,phi_gt(t2,:));                          % update weights
        D(t2+1,:) = D(t2+1,:) / nansum(D(t2+1,:));                          % normalize
    end
end

% ADABOOST+ implementation...
% determine weighting based on validation data

    
% [~,val_best] = (min(loss.val));     % find best boost number based on validation performance
% out_best = out_mean(val_best,:);    % select mean prediction corresponding to best boost number






% net = nets{1};
% net_info = nets_info{1};

% save everything in a struct for visualization/troubleshooting
% this struct is quite large and can't always be saved as is for very large datasets
% recommended to only save essential fields, or change the format for record-keeping
info = struct();
% info.idx_train = idx_train;
% info.beta = adb_beta;
% info.D = D;
% info.ww = ww;
% info.mw = ww;
% info.epsilon = epsilon;
% info.phi = phi;
% info.phi_gt = phi_gt;
% info.are = are;
% info.obs = obs;
% info.out = out;
% info.out_mean = out_mean;
% info.train_loss = train_loss;
% info.val_loss = val_loss;
% info.test_loss = test_loss;
% info.val_best = val_best;
% info.obs_train = obs_train;
% info.ew_train = ew_train;

% if make_plot
%     figure('Name','adaboost.rt: train-val-test loss function')
%     hold 'on'
%     plot(1:n_boosts,train_loss,'o-','DisplayName','train loss');
%     th = plot(1:n_boosts,val_loss,'x-','DisplayName','val loss');
%     plot(1:n_boosts,test_loss,'sq-','DisplayName','test loss');
%     plot(val_best,val_loss(val_best),'o','Color',th.Color,'LineWidth',2','MarkerSize',12,'DisplayName','val best');
%     legend('Location','best')
%     clear th
% end
end