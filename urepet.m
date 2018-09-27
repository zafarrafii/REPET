function urepet
% UREPET a simple user interface system for recovering patterns repeating 
% in time and frequency in mixtures of sounds
%
%   Toolbar:
%       Open Mixture:                   Open mixture file (as .wav or .mp3)
%       Play Mixture:                   Play/stop selected mixture audio
%       Select:                         Select/deselect on signal axes (left/right mouse click)
%       Zoom:                           Zoom on any axes
%       Pan:                            Pan on any axes
%       REPET:                          Process selected mixture using REPET
%       Save Background:                Save background estimate of selected mixture (as .wav)
%       Play Background:                Play/stop background audio of selected mixture
%       Save Foreground:                Save foreground estimate of selected mixture (as .wav)
%       Play Foreground:                Play/stop foreground audio of selected mixture
%
%   See also http://zafarrafii.com/#REPET
%
%   Reference:
%       Zafar Rafii, Antoine Liutkus, and Bryan Pardo. "A Simple User 
%       Interface System for Recovering Patterns Repeating in Time and 
%       Frequency in Mixtures of Sounds," 40th IEEE International 
%       Conference on Acoustics, Speech and Signal Processing, Brisbane, 
%       Australia, April 19-24, 2015.
%
%   Author:
%       Zafar Rafii
%       zafarrafii@gmail.com
%       http://zafarrafii.com
%       https://github.com/zafarrafii
%       https://www.linkedin.com/in/zafarrafii/
%       09/27/18

% Get screen size
screen_size = get(0,'ScreenSize');

% Create the figure window
figure_object = figure( ...
    'Visible','off', ...
    'Position',[screen_size(3:4)/4+1,screen_size(3:4)/2], ...
    'Name','uREPET', ...
    'NumberTitle','off', ...
    'MenuBar','none', ...
    'CloseRequestFcn',@figurecloserequestfcn);

% Create a toolbar on figure
toolbar_object = uitoolbar(figure_object);

% Play and stop icons for the play audio toggle buttons
play_icon = playicon;
stop_icon = stopicon;

% Create the open, save, and parameters toggle buttons on toolbar
open_toggle = uitoggletool(toolbar_object, ...
    'CData',iconread('file_open.png'), ...
    'TooltipString','Open', ...
    'Enable','on', ...
    'ClickedCallback',@openclickedcallback);
play_toggle = uitoggletool(toolbar_object, ...
    'CData',play_icon, ...
    'TooltipString','Play', ...
    'Enable','off', ...
    'UserData',struct('PlayIcon',play_icon,'StopIcon',stop_icon));

% Create the pointer, zoom, and hand toggle buttons on toolbar
select_toggle = uitoggletool(toolbar_object, ...
    'Separator','On', ...
    'CData',iconread('tool_pointer.png'), ...
    'TooltipString','Select', ...
    'Enable','off', ...
    'ClickedCallBack',@selectclickedcallback);
zoom_toggle = uitoggletool(toolbar_object, ...
    'CData',iconread('tool_zoom_in.png'), ...
    'TooltipString','Zoom', ...
    'Enable','off',...
    'ClickedCallBack',@zoomclickedcallback);
pan_toggle = uitoggletool(toolbar_object, ...
    'CData',iconread('tool_hand.png'), ...
    'TooltipString','Pan', ...
    'Enable','off',...
    'ClickedCallBack',@panclickedcallback);

% Create uREPET and save toggle button on toolbar
urepet_toggle = uitoggletool(toolbar_object, ...
    'Separator','On', ...
    'CData',urepeticon, ...
    'TooltipString','uREPET', ...
    'Enable','off');
save_toggle = uitoggletool(toolbar_object, ...
    'CData',iconread('file_save.png'), ...
    'TooltipString','Save', ...
    'Enable','off');

% Create the signal and spectrogram axes
signal_axes = axes( ...
    'OuterPosition',[0,0.9,1,0.1], ...
    'Visible','off');
spectrogram_axes = axes( ...
    'OuterPosition',[0,0,1,0.9], ...
    'Visible','off');

% Change the pointer when the mouse moves over the signal axes or the
% spectrogram axes
enterFcn = @(figure_handle,currentPoint) set(figure_handle,'Pointer','ibeam');
iptSetPointerBehavior(signal_axes,enterFcn);
iptPointerManager(figure_object);
enterFcn = @(figure_handle,currentPoint) set(figure_handle,'Pointer','crosshair');
iptSetPointerBehavior(spectrogram_axes,enterFcn);
iptPointerManager(figure_object);

% Initialize the audio player (for the figure's close request callback)
audio_player = audioplayer(0,80);

% Make the figure visible
figure_object.Visible = 'on';

    % Clicked callback function for the open toggle button
    function openclickedcallback(~,~)
        
        % Change the toggle button state to off
        open_toggle.State = 'off';
        
        % Remove the figure's close request callback so that it allows
        % all the other objects to get created before it can get closed
        figure_object.CloseRequestFcn = '';
        
        % Change the pointer symbol while the figure is busy
        figure_object.Pointer = 'watch';
        
        % Open file selection dialog box; return if cancel
        [audio_name,audio_path] = uigetfile({'*.wav';'*.mp3'}, ...
            'Select WAVE or MP3 File to Open');
        if isequal(audio_name,0) || isequal(audio_path,0)
            figure_object.CloseRequestFcn = @figurecloserequestfcn;
            return
        end
        
        % Clear all the (old) axes and hide them
        cla(signal_axes)
        signal_axes.Visible = 'off';
        cla(spectrogram_axes)
        spectrogram_axes.Visible = 'off';
        
        % Build full file name
        audio_file = fullfile(audio_path,audio_name);
        
        % Read audio file and return sample rate in Hz
        [audio_signal,sample_rate] = audioread(audio_file);
        
        % Number of samples and channels
        [number_samples,number_channels] = size(audio_signal);
        
        % Plot the audio signal and make it unable to capture mouse clicks
        plot(signal_axes, ...
            1/sample_rate:1/sample_rate:number_samples/sample_rate, ...
            audio_signal, ...
            'PickableParts','none');
        
        % Update the signal axes properties
        signal_axes.XLim = [1,number_samples]/sample_rate;
        signal_axes.YLim = [-1,1];
        signal_axes.XGrid = 'on';
        signal_axes.Title.String = audio_name;
        signal_axes.Title.Interpreter = 'None';
        signal_axes.XLabel.String = 'Time (s)';
        signal_axes.Layer = 'top';
        signal_axes.UserData.PlotXLim = [1,number_samples]/sample_rate;
        signal_axes.UserData.SelectXLim = [1,number_samples]/sample_rate;
        drawnow
        
        % Add the constant-Q transform (CQT) toolbox folder to the search 
        % path
        addpath('urepet/CQT_toolbox_2013')
        
        % Number of frequency channels per octave, and minimum and maximum 
        % frequency in Hz
        octave_resolution = 24;
        minimum_frequency = 27.5;
        maximum_frequency = sample_rate/2;
        
        % Initialize the CQT object and the spectrogram
        audio_cqt = cell(1,number_channels);
        audio_spectrogram = [];
        
        % Compute the CQT object and the spectrogram for every channel
        for channel_index = 1:number_channels
            audio_cqt{channel_index} ...
                = cqt(audio_signal(:,channel_index),octave_resolution,sample_rate,minimum_frequency,maximum_frequency);
            audio_spectrogram = cat(3,audio_spectrogram,abs(audio_cqt{channel_index}.c));
        end
        
        % Number of frequency channels and time frames
        [number_frequencies,number_times,~] = size(audio_spectrogram);
        
        % True maximum frequency in Hz
        maximum_frequency = minimum_frequency*2.^((number_frequencies-1)/octave_resolution);
        
        % Display the audio spectrogram (in dB, averaged over the channels)
        % (compensating for the buggy padding that the log scale is adding)
        imagesc(spectrogram_axes, ...
            [1,number_times]/number_times*number_samples/sample_rate, ...
            [(minimum_frequency*2*number_frequencies+maximum_frequency)/(2*number_frequencies+1), ...
            (maximum_frequency*2*number_frequencies+minimum_frequency)/(2*number_frequencies+1)], ...
            db(mean(audio_spectrogram,3)))
        
        % Update the mixture spectrogram axes properties
        spectrogram_axes.YScale = 'log';
        spectrogram_axes.YDir = 'normal';
        spectrogram_axes.XGrid = 'on';
        spectrogram_axes.Colormap = jet;
        spectrogram_axes.Title.String = 'Log-spectrogram';
        spectrogram_axes.XLabel.String = 'Time (s)';
        spectrogram_axes.YLabel.String = 'Frequency (Hz)';
        spectrogram_axes.ButtonDownFcn = @spectrogramaxesbuttondownfcn;
        drawnow
        
        % Enable the save and parameters toggle buttons
        play_toggle.Enable = 'on';
        select_toggle.Enable = 'on';
        zoom_toggle.Enable = 'on';
        pan_toggle.Enable = 'on';
        
        % Add the figure's close request callback back
        figure_object.CloseRequestFcn = @figurecloserequestfcn;
        
        % Change the pointer symbol back
        figure_object.Pointer = 'arrow';
        
        % Mouse-click callback for the axes
        function spectrogramaxesbuttondownfcn(~,~)
            
            1
            
        end
        
        
        
%         % Initialize the rectangle handle as a an array for graphics object
%         rectangle_handle = gobjects(0);
%           
%         % Infinite loop
%         while 1
%             
%             % Create customizable rectangular ROI
%             rectangle_handle = drawrectangle(spectrogram_axes);
%             
%             % Position of ROI
%             [rectangle_xmin,rectangle_ymin,rectangle_width,rectangle_height] = rectangle_handle.Position;
%             
%             % Input rectangle
%             input_rectangle = input_spectrogram(rectangle_ymin:rectangle_ymin+rectangle_height, ...
%                 rectangle_xmin:rectangle_xmin+rectangle_width,:);
%             
%         end
        
        

        
        return
        
        
        background_or_foreground = 'b';                                             % Initial recovering background (or foreground)
        max_number_repetitions = 5;                                                 % Initial max number of repetitions
        min_time_separation = 1;                                                    % Initial min time separation between repetitions (in seconds)
        min_frequency_separation = 1;                                               % Initial min frequency separation between repetitions (in semitones)
        
        
        
        while 1                                                             % Infinite loop
            h = imrect(gca);                                                % Create draggable rectangle
            if isempty(h)                                                   % Return if figure close
                return
            end
            fcn = makeConstrainToRectFcn('imrect', ...
                get(gca,'XLim'),get(gca,'YLim'));                           % Create rectangularly bounded drag constraint function
            setPositionConstraintFcn(h,fcn);                                % Set position constraint function of ROI object
            position = wait(h);                                             % Block MATLAB command line until ROI creation is finished
            if isempty(position)                                            % Return if figure close
                return
            end
            delete(h)                                                       % Remove files or objects
            
            b = waitbar(0,'Please wait...');                                % Open wait bar dialog box
            j = round(position(1));                                         % X-position
            i = round(position(2));                                         % Y-position
            w = round(position(3));                                         % Width
            h = round(position(4));                                         % Height
            R = V(i:i+h-1,j:j+w-1,:);                                       % Selected rectangle
            C = normxcorr2(mean(R,3),mean(V,3));                            % Normalized 2-D cross-correlation
            V = padarray(V,[h-1,w-1,0],'replicate');                        % Pad array for finding peaks
            
            np = max_number_repetitions;                                    % Maximum number of peaks
            mpd = [min_frequency_separation*2, ...
                min_time_separation*round(m/(l/fs))];                       % Minimum peak separation
            k = 1;                                                          % Initialize peak counter
            while k <= np                                                   % Repeat execution of statements while condition is true
                [~,I] = max(C(:));                                          % Linear index of peak
                [I,J] = ind2sub([n+h-1,m+w-1],I);                           % Subscripts from linear index
                C(max(1,I-mpd(1)+1):min(n+h-1,I+mpd(1)+1), ...
                    max(1,J-mpd(2)+1):min(m+w-1,J+mpd(2)+1)) = 0;           % Zero neighborhood around peak
                R = cat(4,R,V(I:I+h-1,J:J+w-1,:));                          % Concatenate similar rectangles
                waitbar(k/np,b)                                             % Update wait bar dialog box
                k = k+1;                                                    % Update peak counter
            end
            close(b)                                                        % Close wait bar dialog box
            
            V = V(h:n+h-1,w:m+w-1,:);                                       % Remove pad array
            M = (min(median(R,4),R(:,:,:,1))+eps)./(R(:,:,:,1)+eps);        % Time-frequency mask of the underlying repeating structure
            if strcmp(background_or_foreground,'f')                         % If recovering foreground
                M = 1-M;
            end
            P = getimage(gca);                                              % Image data from axes
            P(i:i+h-1,j:j+w-1) = 0;
            for k = 1:p                                                     % Loop over the channels
                Xcqk = Xcq{k};
                Xcqk.c(i:i+h-1,j:j+w-1) = Xcqk.c(i:i+h-1,j:j+w-1,:).*M(:,:,k);  % Apply time-frequency mask to CQT
                Xcq{k} = Xcqk;
                P(i:i+h-1,j:j+w-1) = P(i:i+h-1,j:j+w-1)+Xcqk.c(i:i+h-1,j:j+w-1);
            end
            P(i:i+h-1,j:j+w-1) = db(P(i:i+h-1,j:j+w-1)/p);                  % Update rectangle in image
            set(get(gca,'Children'),'CData',P)                              % Update image in axes
       end
        
    end

    % Clicked callback function for the select toggle button
    function selectclickedcallback(~,~)
        
        % Keep the select toggle button state to on and change the zoom and
        % pan toggle button states to off
        select_toggle.State = 'on';
        zoom_toggle.State = 'off';
        pan_toggle.State = 'off';
        
        % Turn the zoom off
        zoom off
        
        % Turn the pan off
        pan off
        
    end

    % Clicked callback function for the zoom toggle button
    function zoomclickedcallback(~,~)
        
        % Keep the zoom toggle button state to on and change the select and
        % pan toggle button states to off
        select_toggle.State = 'off';
        zoom_toggle.State = 'on';
        pan_toggle.State = 'off';
        
        % Make the zoom enable on the figure
        zoom_object = zoom(figure_object);
        zoom_object.Enable = 'on';
        
        % Set the zoom for the x-axis only on the signal axes
        setAxesZoomConstraint(zoom_object,signal_axes,'x');
        
        % Turn the pan off
        pan off
        
    end

    % Clicked callback function for the pan toggle button
    function panclickedcallback(~,~)
        
        % Keep the pan toggle button state to on and change the select and
        % zoom toggle button states to off
        select_toggle.State = 'off';
        zoom_toggle.State = 'off';
        pan_toggle.State = 'on';
        
        % Turn the zoom off
        zoom off
        
        % Make the pan enable on the figure
        pan_object = pan(figure_object);
        pan_object.Enable = 'on';
        
        % Set the pan for the x-axis only on the signal axes
        setAxesPanConstraint(pan_object,signal_axes,'x');
        
    end
    
    % Close request callback function for the figure
    function figurecloserequestfcn(~,~)
        
        % If the audio is playing, stop it
        if isplaying(audio_player)
            stop(audio_player)
        end
        
        % Create question dialog box to close the figure
        user_answer = questdlg('Close uREPET?',...
            'Close uREPET','Yes','No','Yes');
        switch user_answer
            case 'Yes'
                delete(figure_object)
            case 'No'
                return
        end
        
    end


%     function saveclickedcallback(~,~)
%         
%         if isempty(x)                                                       % Return if no input/output
%             return
%         end
%         
%         [filename2,pathname] = uiputfile( ...                               % Open standard dialog box for saving files
%             {'*.wav', 'WAVE files (*.wav)'; ...
%             '*.mp3', 'MP3 files (*.mp3)'}, ...
%             'Save the audio file');
%         if isequal(filename2,0)                                             % Return if user selects Cancel
%             return
%         end
%         
%         p = size(x,2);                                                      % Number of channels
%         x = [];
%         for k = 1:p                                                         % Loop over the channels
%             Xcqk = Xcq{k};
%             x = cat(2,x,icqt(Xcqk));
%         end
%         file = fullfile(pathname,filename2);                                % Build full file name from parts
%         audiowrite(file,x,fs)                                               % Write audio file
%         
%     end
% 
%     function parametersclickedcallback(~,~)
%         
%         prompt = {'Recovering background (b) or foreground (f):', ...
%             'Max number of repetitions:', ...
%             'Min time separation between repetitions (in seconds):', ...
%             'Min frequency separation between repetitions (in semitones):'};
%         dlg_title = 'Parameters';
%         num_lines = 1;
%         def = {background_or_foreground, ...
%             num2str(max_number_repetitions), ...
%             num2str(min_time_separation), ...
%             num2str(min_frequency_separation)};
%         answer = inputdlg(prompt,dlg_title,num_lines,def);                  % Create and open input dialog box
%         if isempty(answer)                                                  % Return if user selects Cancel
%             return
%         end
%         
%         background_or_foreground = answer{1};
%         max_number_repetitions = str2double(answer{2});
%         min_time_separation = str2double(answer{3});
%         min_frequency_separation = str2double(answer{4});
%         
%     end

end

% Read icon from Matlab
function image_data = iconread(icon_name)

% Read icon image from Matlab ([16x16x3] 16-bit PNG) and also return
% its transparency ([16x16] AND mask)
[image_data,~,image_transparency] ...
    = imread(fullfile(matlabroot,'toolbox','matlab','icons',icon_name),'PNG');

% Convert the image to double precision (in [0,1])
image_data = im2double(image_data);

% Convert the 0's to NaN's in the image using the transparency
image_data(image_transparency==0) = NaN;

end

% Create play icon
function image_data = playicon

% Create the upper-half of a black play triangle with NaN's everywhere else
image_data = [nan(2,16);[nan(6,3),kron(triu(nan(6,5)),ones(1,2)),nan(6,3)]];

% Make the whole black play triangle image
image_data = repmat([image_data;image_data(end:-1:1,:)],[1,1,3]);

end

% Create stop icon
function image_data = stopicon

% Create a black stop square with NaN's everywhere else
image_data = nan(16,16);
image_data(4:13,4:13) = 0;

% Make the black stop square an image
image_data = repmat(image_data,[1,1,3]);

end

% Create REPET icon
function image_data = urepeticon

% Create a matrix with NaN's
image_data = nan(16,16,1);

% Create black u, R, E, P, E, and T letters
image_data(4:7,2) = 0;
image_data(7:8,3) = 0;
image_data(4:8,4:5) = 0;

image_data(2:8,7:8) = 0;
image_data([2,3,5,6],9) = 0;
image_data([3:5,7:8],10) = 0;

image_data(2:8,12:13) = 0;
image_data([2,3,5,7,8],14) = 0;
image_data([2,3,7,8],15) = 0;

image_data(10:16,2:3) = 0;
image_data([10,11,13,14],4) = 0;
image_data(11:13,5) = 0;

image_data(10:16,7:8) = 0;
image_data([10,11,13,15,16],9) = 0;
image_data([10,11,15,16],10) = 0;

image_data(10:11,12:15) = 0;
image_data(12:16,13:14) = 0;

% Make the image
image_data = repmat(image_data,[1,1,3]);

end
