classdef gfx
    % class containing graphical parameters and functions for plotting in
    % MATLAB
    %
    % properties cover linewidths, markers, colors, destination style and page size,
    % font
    
    properties
        style {} = 'tex';
        theme {} = 'lassonde';
        orientation = 'default';
        pgw
        pgh
        
        font {} = 'SansSerif';
        fontsize = 11;
        alphbt = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        lw  {mustBeNumeric};      % linewidth
        lw0 {mustBeNumeric};     % "
        lw1 {mustBeNumeric};     % "
        lw2 {mustBeNumeric};     % "
        ms  {mustBeNumeric};      % marker size
        ms0 {mustBeNumeric};     % "
        ms1 {mustBeNumeric};     % "
        ms2 {mustBeNumeric};     % "
        c       % colours
        cs      % colours (cell)
        lns     % lines (cell)
        mks     % markers (cell)
    end
    
    methods
        function obj = gfx(style, orientation, theme)
            
            obj.style = style;

            if nargin > 1
                obj.orientation = orientation;
            end
            if nargin > 2
                obj.theme = theme;
            end

            switch lower(obj.style)
                case {'ppt','powerpoint'}
                    obj.lw0 = 1;
                    obj.lw1 = 2;
                    obj.lw2 = 4;
                    obj.lw = obj.lw1;
                    
                    obj.ms0 = 4;
                    obj.ms1 = 6;
                    obj.ms2 = 10;
                    obj.ms = obj.ms1;
                    
                    obj.pgw = 21.91;%33.867; %<-full screen%29.21; %figure width (16:9)
                    obj.pgh = 12.09;%19.05; %<-full sreen %12.09; %figure height (16:9)

                    assert(any(ismember(lower(obj.orientation),{'default','wide'})),strcat("orientation kwd '",obj.orientation,"' not recognized for style '",obj.style,"'"));
                    switch lower(obj.orienation)
                        case 'wide'
                            obj.pgw = 29.21; %figure width (16:9)
                    end
                    
                    obj.fontsize = 14; %figure text size
                    obj.font = 'SansSerif'; %figure font
                    
                case {'publisher','poster','pub'}
                    obj.lw0 = 1;
                    obj.lw1 = 2;
                    obj.lw2 = 4;
                    obj.lw = obj.lw1;
                    
                    obj.ms0 = 4;
                    obj.ms1 = 6;
                    obj.ms2 = 10;
                    obj.ms = obj.ms1;
                    
                    obj.pgw = 47.64 - 0.64;
                    obj.pgh = 47.64 - 0.64;
                    assert(any(ismember(lower(obj.orientation),{'default','landscape'})),strcat("orientation kwd '",obj.orientation,"' not recognized for style '",obj.style,"'"));
                    switch lower(obj.orienation)
                        case 'portrait'
                            temp = obj.pgw;
                            obj.pgw = obj.pgh;
                            obj.pgh = temp;
                            clear temp;
                    end
                    
                    obj.fontsize = 18;
                    obj.font = 'Source Sans Pro';
                    
                case {'word','doc','docx','tex','latex'}
                    obj.lw0 = 0.5;
                    obj.lw1 = 1.5;
                    obj.lw2 = 3;
                    obj.lw = obj.lw1;
                    
                    obj.ms0 = 4;
                    obj.ms1 = 6;
                    obj.ms2 = 10;
                    obj.ms = obj.ms1;
                    
                    obj.pgw = 21.59 - 2*2.54;
                    obj.pgh = 27.94 - 2*2.54;
                    
                    assert(any(ismember(lower(obj.orientation),{'default','landscape'})),strcat("orientation kwd '",obj.orientation,"' not recognized for style '",obj.style,"'"));
                    switch lower(obj.orientation)
                        case 'landscape'
                            temp = obj.pgw;
                            obj.pgw = obj.pgh;
                            obj.pgh = temp;
                            clear temp;
                    end
                    
                    obj.fontsize = 8; %text header
                    obj.font = 'SansSerif';
            end
            
            obj = colors(obj);
            obj.cs = struct2cell(obj.c);
            obj.lns = repmat({'o-','x-','+-','sq-','d-'},[1,50]);
            obj.mks = repmat({'o','x','+','sq','d'},[1,50]);
        end
        
        
        
        fh = apply(obj, frac, marg, varargin);
        
    end
    

% 
% gp = struct();
% gp.style = gfx_style;
% gp.theme = gfx_theme;
% 
% gp.apply = @gfx_apply;

% gp.sqlims = @apply_sqlims;
% gp.save = @save_fig;
% gp.save_gif = @save_gif;
% 
% 

end

