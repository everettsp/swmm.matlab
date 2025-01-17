function fh = plot_corr(t,ys,varargin)
%plots correlation for ensemble modelling, colorizing training and testing
%tr is the training object from the neural network
%2 colours

% par = inputParser;
% addParameter(par,'p',75)
% addParameter(par,'gp',gfx('tex','default','lassonde'))
% parse(par,varargin{:})

% p = par.Results.p;
% gp = par.Results.gp;
% subplot_names = par.Results.subplot_names;
% 
% if p < 50
%     p = 100 - p;
% end

p = 75;
% fh = figure;
% fh.Name = 'correlation between observed and modelled values';

temp = size(t) == size(ys);
y_size = size(ys);
num_ens = y_size(~temp);

if num_ens ~= 1
    y = nanmedian(ys,2);
else
    y = ys;
end

plot(t,y,'x','DisplayName','Median',varargin{:})
hold on

if num_ens ~= 1
    y_up = prctile(ys,p,2);
    y_down = prctile(ys,100-p,2);
    plot([t t]',[y_up y_down]','HandleVisibility','off',varargin{:});
    fprintf('detected ensemble with %d members, plotting %dpc confidence intervals\n',num_ens,p)
end

lims = [min([xlim ylim]) max([xlim ylim])];
xlim(lims)
ylim(lims)

plot([-9999 9999],[-9999 9999],'--','Color',[0 0 0],'LineWidth',1,'DisplayName','1:1','HandleVisibility','on')

% apply_sqlims;
end

