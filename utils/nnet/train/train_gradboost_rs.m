function [nets,mw,info] = train_gradboost_rs(net, inp, obs, m, boost_step, varargin)
% implementation of Gradient Boosting (Friedman 2000; VanHeijst 2008)
% [out_best, net, net_info, gb] OLD OUTPUTS
% REQUIRED PARAMETERS----------
% net_0 is an untrained artificial neural network (matlab object)
% inp is input data (column-wise samples)
% obs is target data
% n_boosts is the number of boosts (T)
% boost_step is the learning rate
% 
% OPTIONAL PARAMETERS----------
% plot is a boolean statement indicating whether to produce summary plots

% par = inputParser;
% addParameter(par,'plot',false,@islogical)
% parse(par,varargin{:})
% make_plot = par.Results.plot;

% if ~strcmp(net_0.DivideFcn,'divideind')
%     error('adaboost only support pre-partitioned datasets (net.DivideFcn = divideind)')
% end

par = inputParser;
addParameter(par,'rsf',@resample_default)
parse(par,varargin{:})
rsf = par.Results.rsf;

n_boosts = m;
net_0 = net;

% nets = cell(n_boosts,1);
% nets_info  = cell(n_boosts,1);
rho = NaN(1,n_boosts);

train_loss = NaN(n_boosts,1);       % training error
val_loss = NaN(n_boosts,1);         % validation error
test_loss = NaN(n_boosts,1);        % testing error
loss_fcn = @(x,y) nansum((x-y).^2) ./ numel(x(~(isnan(x) | isnan(y)))); % mean squared error

n_samples = numel(obs);
[n,idx,ldx] = split_divideparams(net,n_samples); % extract number of sampels and indices from ANN


residuals = zeros(n_boosts, n_samples);
mod = zeros(n_boosts, n_samples);
out_sum = zeros(n_boosts, n_samples);
tgt = obs;

nets = cell(n_boosts,1);
trns = cell(n_boosts,1);

for t2 = 1:n_boosts
    
    [net2,inp2,obs2] = rsf(net_0,inp,obs);
    
    n2_samples = size(obs2,2);
    [n2,idx2,ldx2] = split_divideparams(net,n2_samples); % extract number of sampels and indices from ANN

    if t2 == 1
        tgt2 = obs2;
    else
        % get the boosted prediction for the resampled dataset
        out_temp = nan(t2,n_samples);
        out_temp2 = nan(t2,n2_samples);
        for i2 = 1:(t2-1)
            out_temp(i2,:) = nets{i2}(inp);
            out_temp2(i2,:) = nets{i2}(inp2);
        end
        mod = rho(1,1:(t2-1)) * out_temp(1:(t2-1),:);
        mod2 = rho(1,1:(t2-1)) * out_temp2(1:(t2-1),:);
        tgt = obs - mod;
        tgt2 = obs2 - mod2;
        
    end
    
    [nets{t2}, trns{t2}] = train(net2,inp2,tgt2); %train the network...
%     mod2(t2,:) = nets{t2}(inp2);
    out = nets{t2}(inp);
    
    
    
%     fun_loss = @(rho_m) sum((target(ldx) - rho_m * mod(t2,ldx)).^2);
    
%     warning_settings = warning('query','all'); %temporarily surpress warnings caused by minimization function
%     warning('off','all');
%     rho(t2) = fmincon(fun_loss,0);

    rho(1,t2) =  out(ldx.val)' \ tgt(ldx.val)';
%     warning(warning_settings);

if t2 > 1
    rho(1,t2) = rho(1,t2) .* boost_step; % combine rho and learning rate into a single coefficient
end
%     if t2 == 1
%         out_sum(1,:) = rho(t2) .* mod(1,:);
%         residuals(1,:) = obs - out_sum(1,:);    
%     else
%         out_sum(t2,:) = out_sum(t2-1,:) + rho(t2) * mod(t2,:);
%         residuals(t2,:) = obs - out_sum(t2,:);
%     end
%     
%     tgt = residuals(t2,:);
    
%     train_loss(t2) = loss_fcn(obs(idx_train),out_sum(t2,idx_train));
%     val_loss(t2) = loss_fcn(obs(idx_val),out_sum(t2,idx_val));
%     test_loss(t2) = loss_fcn(obs(idx_test),out_sum(t2,idx_test));
end


[~,val_best] = (min(val_loss));
out_best = out_sum(val_best,:);

mw = rho';
info.rho = rho;
info.residuals = residuals;
info.q_obs = obs;
info.mod = mod;
info.out_sum = out_sum;
info.out_best = out_best;
info.loss_val = val_loss;
info.val_best = val_best;
% 
% if make_plot
%     figure('Name','gradboost.ls: train-val-test loss function')
%     hold 'on'
%     plot(1:n_boosts,train_loss,'o-','DisplayName','train loss');
%     th = plot(1:n_boosts,val_loss,'x-','DisplayName','val loss');
%     plot(1:n_boosts,test_loss,'sq-','DisplayName','test loss');
%     plot(val_best,val_loss(val_best),'o','Color',th.Color,'LineWidth',2','MarkerSize',12,'DisplayName','val best');
%     legend('Location','best')
%     clear th
% end

end