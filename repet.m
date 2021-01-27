classdef repet
    % repet This Matlab class a number of functions for the REpeating 
    %   Repetition is a fundamental element in generating and perceiving 
    %   structure. In audio, mixtures are often composed of structures 
    %   where a repeating background signal is superimposed with a varying 
    %   foreground signal (e.g., a singer overlaying varying vocals on a 
    %   repeating accompaniment or a varying speech signal mixed up with a 
    %   repeating background noise). On this basis, we present the 
    %   REpeating Pattern Extraction Technique (REPET), a simple approach 
    %   for separating the repeating background from the non-repeating 
    %   foreground in an audio mixture. The basic idea is to find the 
    %   repeating elements in the mixture, derive the underlying repeating 
    %   models, and extract the repeating background by comparing the 
    %   models to the mixture. Unlike other separation approaches, REPET 
    %   does not depend on special parameterizations, does not rely on 
    %   complex frameworks, and does not require external information. 
    %   Because it is only based on repetition, it has the advantage of 
    %   being simple, fast, blind, and therefore completely and easily 
    %   automatable.
    %   
    % repet Methods:
    %   original - Compute the original REPET.
    %   extended - Compute REPET extended.
    %   adaptive - Compute the adaptive REPET.
    %   sim - Compute REPET-SIM.
    %   simonline - Compute REPET-SIM.
    % 
    % repet Other:
    %   specshow - Display an spectrogram in dB, seconds, and Hz.
    % 
    % Author:
    %   Zafar Rafii
    %   zafarrafii@gmail.com
    %   http://zafarrafii.com
    %   https://github.com/zafarrafii
    %   https://www.linkedin.com/in/zafarrafii/
    %   01/27/21
    
    % Define the properties
    properties (Access = private, Constant = true)
        
        % Define the cutoff frequency in Hz for the dual high-pass filter 
        % of the foreground (vocals are rarely below 100 Hz)
        cutoff_frequency = 100;
        
        % Define the period range in seconds for the beat spectrum (for the
        % original REPET, REPET extented, and the adaptive REPET)
        period_range = [1,10];
        
        % Define the segment length and step in seconds (for REPET extented 
        % and the adaptive REPET)
        segment_length = 10;
        segment_step = 5;
        
        % Define the filter order for the median filter (for the adaptive 
        % REPET)
        filter_order = 5;
        
        % Define the minimal threshold for two similar frames in [0,1], 
        % minimal distance between two similar frames in seconds, and 
        % maximal number of similar frames for every frame (for REPET-SIM 
        % and the online REPET-SIM)
        similarity_threshold = 0;
        similarity_distance = 1;
        similarity_number = 100;
        
        % Define the buffer length in seconds (for the online REPET-SIM)
        buffer_length = 10;
            
    end
    
    % Define the public methods
    methods (Access = public, Static = true)
        
        function background_signal = original(audio_signal,sampling_frequency)
            % original Compute the original REPET.
            %   The original REPET aims at identifying and extracting the 
            %   repeating patterns in an audio mixture, by estimating a 
            %   period of the underlying repeating structure and modeling a 
            %   segment of the periodically repeating background.
            %   
            %   background_signal = repet.original(audio_signal,sampling_frequency)
            %   
            %   Inputs:
            %       audio_signal: audio signal [number_samples,number_channels]
            %       sampling_frequency: sampling frequency in Hz
            %   Output:
            %       background_signal: background signal [number_samples,number_channels]
            %   
            %   Example: Estimate the background and foreground signals, and display their spectrograms.
            %       % Read the audio signal with its sampling frequency in Hz
            %       [audio_signal,sampling_frequency] = audioread('audio_file.wav');
            % 
            %       % Estimate the background signal, and the foreground signal
            %       background_signal = repet.original(audio_signal,sampling_frequency);
            %       foreground_signal = audio_signal-background_signal;
            % 
            %       % Write the background and foreground signals
            %       audiowrite('background_signal.wav',background_signal,sampling_frequency)
            %       audiowrite('foreground_signal.wav',foreground_signal,sampling_frequency)
            % 
            %       % Compute the mixture, background, and foreground spectrograms
            %       window_length = 2^nextpow2(0.04*sampling_frequency);
            %       window_function = hamming(window_length,'periodic');
            %       step_length = window_length/2;
            %       audio_spectrogram = abs(spectrogram(mean(audio_signal,2),window_length,window_length-step_length));
            %       background_spectrogram = abs(spectrogram(mean(background_signal,2),window_length,window_length-step_length));
            %       foreground_spectrogram = abs(spectrogram(mean(foreground_signal,2),window_length,window_length-step_length));
            % 
            %       % Display the mixture, background, and foreground spectrograms in dB, seconds, and Hz
            %       time_duration = length(audio_signal)/sampling_frequency;
            %       maximum_frequency = sampling_frequency/8;
            %       xtick_step = 1;
            %       ytick_step = 1000;
            %       figure
            %       subplot(3,1,1)
            %       repet.specshow(audio_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Audio spectrogram (dB)')
            %       subplot(3,1,2)
            %       repet.specshow(background_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Background spectrogram (dB)')
            %       subplot(3,1,3)
            %       repet.specshow(foreground_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Foreground spectrogram (dB)')

            % Get the number of samples and channels in the audio signal
            [number_samples,number_channels] = size(audio_signal);
            
            % Set the parameters for the STFT 
            % (audio stationary around 40 ms, power of 2 for fast FFT and constant overlap-add (COLA),
            % periodic Hamming window for COLA, and step equal to half the window length for COLA)
            window_length = 2^nextpow2(0.04*sampling_frequency);
            window_function = hamming(window_length,'periodic');
            step_length = window_length/2;
            
            % Derive the number of time frames
            % (given the zero-padding at the start and the end of the signal)
            number_times = ceil(((number_samples+2*floor(window_length/2))-window_length) ...
                /step_length)+1;
            
            % Initialize the STFT
            audio_stft = zeros(window_length,number_times,number_channels);
            
            % Loop over the channels
            for i = 1:number_channels
                
                % Compute the STFT of the current channel
                audio_stft(:,:,i) = repet.stft(audio_signal(:,i),window_function,step_length);
                
            end
            
            % Derive the magnitude spectrogram
            % (with the DC component and without the mirrored frequencies)
            audio_spectrogram = abs(audio_stft(1:window_length/2+1,:,:));
            
            % Compute the beat spectrum of the spectrograms averaged over the channels 
            % (take the square to emphasize peaks of periodicitiy)
            beat_spectrum = repet.beatspectrum(mean(audio_spectrogram,3).^2);
            
            % Get the period range in time frames for the beat spectrum
            period_range2 = round(repet.period_range*sampling_frequency/step_length);
            
            % Estimate the repeating period in time frames given the period range
            repeating_period = repet.periods(beat_spectrum,period_range2);
            
            % Get the cutoff frequency in frequency channels 
            % for the dual high-pass filtering of the foreground
            cutoff_frequency2 = round(repet.cutoff_frequency*window_length/sampling_frequency);
            
            % Initialize the background signal
            background_signal = zeros(number_samples,number_channels);
            
            % Loop over the channels
            for channel_index = 1:number_channels
                
                % Compute the repeating mask for the current channel given the repeating period
                repeating_mask = repet.mask(audio_spectrogram(:,:,channel_index),repeating_period);
                
                % Perform a high-pass filtering of the dual foreground
                repeating_mask(2:cutoff_frequency2+1,:) = 1;
                
                % Recover the mirrored frequencies
                repeating_mask = cat(1,repeating_mask,repeating_mask(end-1:-1:2,:));
                
                % Synthesize the repeating background for the current channel
                background_signal1 ...
                    = repet.istft(repeating_mask.*audio_stft(:,:,channel_index),window_function,step_length);
                
                % Truncate to the original number of samples
                background_signal(:,channel_index) = background_signal1(1:number_samples);
                
            end
            
        end
        
        function background_signal = extended(audio_signal,sampling_frequency)
            % extended Compute REPET extended.
            %   The original REPET can be easily extended to handle varying 
            %   repeating structures, by simply applying the method along 
            %   time, on individual segments or via a sliding window.
            %   
            %   background_signal = repet.extended(audio_signal,sampling_frequency)
            %   
            %   Inputs:
            %       audio_signal: audio signal [number_samples,number_channels]
            %       sampling_frequency: sampling frequency in Hz
            %   Output:
            %       background_signal: background signal [number_samples,number_channels]
            %   
            %   Example: Estimate the background and foreground signals, and display their spectrograms.
            %       % Read the audio signal with its sampling frequency in Hz
            %       [audio_signal,sampling_frequency] = audioread('audio_file.wav');
            % 
            %       % Estimate the background signal, and the foreground signal
            %       background_signal = repet.extended(audio_signal,sampling_frequency);
            %       foreground_signal = audio_signal-background_signal;
            % 
            %       % Write the background and foreground signals
            %       audiowrite('background_signal.wav',background_signal,sampling_frequency)
            %       audiowrite('foreground_signal.wav',foreground_signal,sampling_frequency)
            % 
            %       % Compute the mixture, background, and foreground spectrograms
            %       window_length = 2^nextpow2(0.04*sampling_frequency);
            %       window_function = hamming(window_length,'periodic');
            %       step_length = window_length/2;
            %       audio_spectrogram = abs(spectrogram(mean(audio_signal,2),window_length,window_length-step_length));
            %       background_spectrogram = abs(spectrogram(mean(background_signal,2),window_length,window_length-step_length));
            %       foreground_spectrogram = abs(spectrogram(mean(foreground_signal,2),window_length,window_length-step_length));
            % 
            %       % Display the mixture, background, and foreground spectrograms in dB, seconds, and Hz
            %       time_duration = length(audio_signal)/sampling_frequency;
            %       maximum_frequency = sampling_frequency/8;
            %       xtick_step = 1;
            %       ytick_step = 1000;
            %       figure
            %       subplot(3,1,1)
            %       repet.specshow(audio_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Audio spectrogram (dB)')
            %       subplot(3,1,2)
            %       repet.specshow(background_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Background spectrogram (dB)')
            %       subplot(3,1,3)
            %       repet.specshow(foreground_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Foreground spectrogram (dB)')
            
            % Get the number of samples and channels
            [number_samples,number_channels] = size(audio_signal);
            
            % Get the segment length, step, and overlap in samples
            segment_length2 = round(repet.segment_length*sampling_frequency);
            segment_step2 = round(repet.segment_step*sampling_frequency);
            segment_overlap2 = segment_length2-segment_step2;
            
            % Get the number of segments
            if number_samples < segment_length2+segment_step2
                
                % Use a single segment if the signal is too short
                number_segments = 1;
                
            else
                
                % Use multiple segments if the signal is long enough
                % (the last segment could be longer)
                number_segments = 1+floor((number_samples-segment_length2)/segment_step2);
                
                % Use a triangular window for the overlapping parts
                segment_window = triang(2*segment_overlap2);
                
            end
            
            % Set the parameters for the STFT 
            % (audio stationary around 40 ms, power of 2 for fast FFT and constant overlap-add (COLA),
            % periodic Hamming window for COLA, and step equal to half the window length for COLA)
            window_length = 2^nextpow2(0.04*sampling_frequency);
            window_function = hamming(window_length,'periodic');
            step_length = window_length/2;
            
            % Get the period range in time frames for the beat spectrum
            period_range2 = round(repet.period_range*sampling_frequency/step_length);
            
            % Get the cutoff frequency in frequency channels 
            % for the dual high-pass filter of the foreground
            cutoff_frequency2 = round(repet.cutoff_frequency*window_length/sampling_frequency);
            
            % Initialize the background signal
            background_signal = zeros(number_samples,number_channels);
            
            % Loop over the segments
            k = 0;
            for j = 1:number_segments
                
                % Check if there is a single segment or multiple ones
                if number_segments == 1
                    
                    % Use the whole signal as the segment
                    audio_segment = audio_signal;
                    segment_length2 = number_samples;
                    
                else
                    
                    % Check if it is one of the first segments (same length) 
                    % or the last one (could be longer)
                    if j < number_segments
                        audio_segment = audio_signal(k+1:k+segment_length2,:);
                    elseif j == number_segments
                        audio_segment = audio_signal(k+1:number_samples,:);
                        segment_length2 = length(audio_segment);
                    end
                    
                end
                
                % Get the number of time frames
                number_times = ceil((window_length-step_length+segment_length2)/step_length);
                
                % Initialize the STFT
                audio_stft = zeros(window_length,number_times,number_channels);
                
                % Loop over the channels
                for i = 1:number_channels
                    
                    % Compute the STFT of the current channel
                    audio_stft(:,:,i) = repet.stft(audio_segment(:,i),window_function,step_length);
                    
                end
                
                % Derive the magnitude spectrogram 
                % (with the DC component and without the mirrored frequencies)
                audio_spectrogram = abs(audio_stft(1:window_length/2+1,:,:));
                
                % Compute the beat spectrum of the spectrograms averaged over the channels
                % (take the square to emphasize peaks of periodicitiy)
                beat_spectrum = repet.beatspectrum(mean(audio_spectrogram,3).^2);
                
                % Repeating period in time frames given the period range
                repeating_period = repet.periods(beat_spectrum,period_range2);
                
                % Initialize the background segment
                background_segment = zeros(segment_length2,number_channels);
                
                % Loop over the channels
                for i = 1:number_channels
                    
                    % Compute the repeating mask for the current channel
                    repeating_mask = repet.mask(audio_spectrogram(:,:,i),repeating_period);
                    
                    % Perform a high-pass filtering of the dual foreground
                    repeating_mask(2:cutoff_frequency2+1,:) = 1;
                    
                    % Recover the mirrored frequencies
                    repeating_mask = cat(1,repeating_mask,repeating_mask(end-1:-1:2,:));
                    
                    % Synthesize the repeating background for the current channel
                    background_segment1 ...
                        = repet.istft(repeating_mask.*audio_stft(:,:,i),window_function,step_length);
                    
                    % Truncate to the original number of samples
                    background_segment(:,i) = background_segment1(1:segment_length2);
                    
                end
                
                % Check again if there is a single segment or multiple ones
                if number_segments == 1
                    
                    % Use the segment as the whole signal
                    background_signal = background_segment;
                    
                else
                    
                    % Check if it is the first segment or the following ones
                    if j == 1
                        
                        % Add the segment to the signal
                        background_signal(1:segment_length2,:) ...
                            = background_signal(1:segment_length2,:) ...
                            + background_segment;
                        
                    elseif j <= number_segments
                        
                        % Perform a half windowing of the overlap part 
                        % of the background signal on the right
                        background_signal(k+1:k+segment_overlap2,:) ...
                            = background_signal(k+1:k+segment_overlap2,:) ...
                            .*segment_window(segment_overlap2+1:2*segment_overlap2);
                        
                        % Perform a half windowing of the overlap part 
                        % of the background segment on the left
                        background_segment(1:segment_overlap2,:) ...
                            = background_segment(1:segment_overlap2,:) ...
                            .*segment_window(1:segment_overlap2);
                        
                        % Add the segment to the signal
                        background_signal(k+1:k+segment_length2,:) ...
                            = background_signal(k+1:k+segment_length2,:) ...
                            + background_segment;
                        
                    end
                    
                    % Update the index
                    k = k + segment_step2;
                    
                end
                
            end
            
        end
        
        function background_signal = adaptive(audio_signal,sampling_frequency)
            % adaptive Compute the adaptive REPET.
            %   The original REPET works well when the repeating background 
            %   is relatively stable (e.g., a verse or the chorus in a 
            %   song); however, the repeating background can also vary over 
            %   time (e.g., a verse followed by the chorus in the song). 
            %   The adaptive REPET is an extension of the original REPET 
            %   that can handle varying repeating structures, by estimating 
            %   the time-varying repeating periods and extracting the 
            %   repeating background locally, without the need for 
            %   segmentation or windowing.
            %   
            %   background_signal = repet.adaptive(audio_signal,sampling_frequency)
            %   
            %   Inputs:
            %       audio_signal: audio signal [number_samples,number_channels]
            %       sampling_frequency: sampling frequency in Hz
            %   Output:
            %       background_signal: background signal [number_samples,number_channels]
            %   
            %   Example: Estimate the background and foreground signals, and display their spectrograms.
            %       % Read the audio signal with its sampling frequency in Hz
            %       [audio_signal,sampling_frequency] = audioread('audio_file.wav');
            % 
            %       % Estimate the background signal, and the foreground signal
            %       background_signal = repet.adaptive(audio_signal,sampling_frequency);
            %       foreground_signal = audio_signal-background_signal;
            % 
            %       % Write the background and foreground signals
            %       audiowrite('background_signal.wav',background_signal,sampling_frequency)
            %       audiowrite('foreground_signal.wav',foreground_signal,sampling_frequency)
            % 
            %       % Compute the mixture, background, and foreground spectrograms
            %       window_length = 2^nextpow2(0.04*sampling_frequency);
            %       window_function = hamming(window_length,'periodic');
            %       step_length = window_length/2;
            %       audio_spectrogram = abs(spectrogram(mean(audio_signal,2),window_length,window_length-step_length));
            %       background_spectrogram = abs(spectrogram(mean(background_signal,2),window_length,window_length-step_length));
            %       foreground_spectrogram = abs(spectrogram(mean(foreground_signal,2),window_length,window_length-step_length));
            % 
            %       % Display the mixture, background, and foreground spectrograms in dB, seconds, and Hz
            %       time_duration = length(audio_signal)/sampling_frequency;
            %       maximum_frequency = sampling_frequency/8;
            %       xtick_step = 1;
            %       ytick_step = 1000;
            %       figure
            %       subplot(3,1,1)
            %       repet.specshow(audio_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Audio spectrogram (dB)')
            %       subplot(3,1,2)
            %       repet.specshow(background_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Background spectrogram (dB)')
            %       subplot(3,1,3)
            %       repet.specshow(foreground_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Foreground spectrogram (dB)')
            
            % Get the number of samples and channels
            [number_samples,number_channels] = size(audio_signal);
            
            % Set the parameters for the STFT 
            % (audio stationary around 40 ms, power of 2 for fast FFT and constant overlap-add (COLA),
            % periodic Hamming window for COLA, and step equal to half the window length for COLA)
            window_length = 2^nextpow2(0.04*sampling_frequency);
            window_function = hamming(window_length,'periodic');
            step_length = window_length/2;
            
            % Derive the number of time frames
            % (given the zero-padding at the start and the end of the signal)
            number_times = ceil(((number_samples+2*floor(window_length/2))-window_length) ...
                /step_length)+1;
            
            % Initialize the STFT
            audio_stft = zeros(window_length,number_times,number_channels);
            
            % Loop over the channels
            for i = 1:number_channels
                
                % STFT of the current channel
                audio_stft(:,:,i) = repet.stft(audio_signal(:,i),window_function,step_length);
                
            end
            
            % Derive the magnitude spectrogram
            % (with the DC component and without the mirrored frequencies)
            audio_spectrogram = abs(audio_stft(1:window_length/2+1,:,:));
            
            % Get the segment length and step in time frames for the beat spectrogram
            segment_length2 = round(repet.segment_length*sampling_frequency/step_length);
            segment_step2 = round(repet.segment_step*sampling_frequency/step_length);
            
            % Compute the beat spectrogram of the spectrograms averaged over the channels
            % (take the square to emphasize peaks of periodicitiy)
            beat_spectrogram = repet.beatspectrogram(mean(audio_spectrogram,3).^2,segment_length2,segment_step2);
            
            % Get the period range in time frames
            period_range2 = round(repet.period_range*sampling_frequency/step_length);
            
            % Estimate the repeating periods in time frames given the period range
            repeating_periods = repet.periods(beat_spectrogram,period_range2);
            
            % Get the cutoff frequency in frequency channels 
            % for the dual high-pass filter of the foreground
            cutoff_frequency2 = round(repet.cutoff_frequency*window_length/sampling_frequency);
            
            % Initialize the background signal
            background_signal = zeros(number_samples,number_channels);
            
            % Loop over the channels
            for i = 1:number_channels
                
                % Compute the repeating mask for the current channel given the repeating periods
                repeating_mask ...
                    = repet.adaptivemask(audio_spectrogram(:,:,i),repeating_periods,repet.filter_order);
                
                % Perform a high-pass filtering of the dual foreground
                repeating_mask(2:cutoff_frequency2+1,:) = 1;
                
                % Recover the mirrored frequencies
                repeating_mask = cat(1,repeating_mask,repeating_mask(end-1:-1:2,:));
                
                % Synthesize the repeating background for the current channel
                background_signal1 = repet.istft(repeating_mask.*audio_stft(:,:,i),window_function,step_length);
                
                % Truncate to the original number of samples
                background_signal(:,i) = background_signal1(1:number_samples);
                
            end
            
        end
        
        function background_signal = sim(audio_signal,sampling_frequency)
            % sim REPET-SIM
            %   The REPET methods work well when the repeating background 
            %   has periodically repeating patterns (e.g., jackhammer 
            %   noise); however, the repeating patterns can also happen 
            %   intermittently or without a global or local periodicity 
            %   (e.g., frogs by a pond). REPET-SIM is a generalization of 
            %   REPET that can also handle non-periodically repeating 
            %   structures, by using a similarity matrix to identify the 
            %   repeating elements.
            %   
            %   background_signal = repet.sim(audio_signal,sampling_frequency)
            %   
            %   Inputs:
            %       audio_signal: audio signal [number_samples,number_channels]
            %       sampling_frequency: sampling frequency in Hz
            %   Output:
            %       background_signal: background signal [number_samples,number_channels]
            %   
            %   Example: Estimate the background and foreground signals, and display their spectrograms.
            %       % Read the audio signal with its sampling frequency in Hz
            %       [audio_signal,sampling_frequency] = audioread('audio_file.wav');
            % 
            %       % Estimate the background signal, and the foreground signal
            %       background_signal = repet.sim(audio_signal,sampling_frequency);
            %       foreground_signal = audio_signal-background_signal;
            % 
            %       % Write the background and foreground signals
            %       audiowrite('background_signal.wav',background_signal,sampling_frequency)
            %       audiowrite('foreground_signal.wav',foreground_signal,sampling_frequency)
            % 
            %       % Compute the mixture, background, and foreground spectrograms
            %       window_length = 2^nextpow2(0.04*sampling_frequency);
            %       window_function = hamming(window_length,'periodic');
            %       step_length = window_length/2;
            %       audio_spectrogram = abs(spectrogram(mean(audio_signal,2),window_length,window_length-step_length));
            %       background_spectrogram = abs(spectrogram(mean(background_signal,2),window_length,window_length-step_length));
            %       foreground_spectrogram = abs(spectrogram(mean(foreground_signal,2),window_length,window_length-step_length));
            % 
            %       % Display the mixture, background, and foreground spectrograms in dB, seconds, and Hz
            %       time_duration = length(audio_signal)/sampling_frequency;
            %       maximum_frequency = sampling_frequency/8;
            %       xtick_step = 1;
            %       ytick_step = 1000;
            %       figure
            %       subplot(3,1,1)
            %       repet.specshow(audio_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Audio spectrogram (dB)')
            %       subplot(3,1,2)
            %       repet.specshow(background_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Background spectrogram (dB)')
            %       subplot(3,1,3)
            %       repet.specshow(foreground_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Foreground spectrogram (dB)')
            
            % Get the number of samples and channels
            [number_samples,number_channels] = size(audio_signal);
            
            % Set the parameters for the STFT 
            % (audio stationary around 40 ms, power of 2 for fast FFT and constant overlap-add (COLA),
            % periodic Hamming window for COLA, and step equal to half the window length for COLA)
            window_length = 2^nextpow2(0.04*sampling_frequency);
            window_function = hamming(window_length,'periodic');
            step_length = window_length/2;
            
            % Derive the number of time frames
            % (given the zero-padding at the start and the end of the signal)
            number_times = ceil(((number_samples+2*floor(window_length/2))-window_length) ...
                /step_length)+1;
            
            % Initialize the STFT
            audio_stft = zeros(window_length,number_times,number_channels);
            
            % Loop over the channels
            for i = 1:number_channels
                
                % STFT of the current channel
                audio_stft(:,:,i) = repet.stft(audio_signal(:,i),window_function,step_length);
                
            end
            
            % Derive the magnitude spectrogram
            % (with the DC component and without the mirrored frequencies)
            audio_spectrogram = abs(audio_stft(1:window_length/2+1,:,:));
            
            % Compute the self-similarity matrix of the spectrograms averaged over the channels
            similarity_matrix = repet.selfsimilaritymatrix(mean(audio_spectrogram,3));
            
            % Get the similarity distance in time frames
            similarity_distance2 = round(repet.similarity_distance*sampling_frequency/step_length);
            
            % Estimate the similarity indices for all the frames
            similarity_indices ...
                = repet.indices(similarity_matrix,repet.similarity_threshold,similarity_distance2,repet.similarity_number);
            
            % Get the cutoff frequency in frequency channels
            % for the dual high-pass filter of the foreground
            cutoff_frequency2 = ceil(repet.cutoff_frequency*(window_length-1)/sampling_frequency);
            
            % Initialize the background signal
            background_signal = zeros(number_samples,number_channels);
            
            % Loop over the channels
            for i = 1:number_channels
                
                % Compute the repeating mask for the current channel given the similarity indices
                repeating_mask = repet.simmask(audio_spectrogram(:,:,i),similarity_indices);
                
                % Perform a high-pass filtering of the dual foreground
                repeating_mask(2:cutoff_frequency2+1,:) = 1;
                
                % Recover the mirrored frequencies
                repeating_mask = cat(1,repeating_mask,repeating_mask(end-1:-1:2,:));
                
                % Synthesize the repeating background for the current channel
                background_signal1 = repet.istft(repeating_mask.*audio_stft(:,:,i),window_function,step_length);
                
                % Truncate to the original number of samples
                background_signal(:,i) = background_signal1(1:number_samples);
                
            end
            
        end
        
        function background_signal = simonline(audio_signal,sampling_frequency)
            % simonline Online REPET-SIM
            %   REPET-SIM can be easily implemented online to handle 
            %   real-time computing, particularly for real-time speech 
            %   enhancement. The online REPET-SIM simply processes the time 
            %   frames of the mixture one after the other given a buffer 
            %   that temporally stores past frames.
            %   
            %   background_signal = repet.simonline(audio_signal,sampling_frequency)
            %   
            %   Inputs:
            %       audio_signal: audio signal [number_samples,number_channels]
            %       sampling_frequency: sampling frequency in Hz
            %   Output:
            %       background_signal: background signal [number_samples,number_channels]
            %   
            %   Example: Estimate the background and foreground signals, and display their spectrograms.
            %       % Read the audio signal with its sampling frequency in Hz
            %       [audio_signal,sampling_frequency] = audioread('audio_file.wav');
            % 
            %       % Estimate the background signal, and the foreground signal
            %       background_signal = repet.simonline(audio_signal,sampling_frequency);
            %       foreground_signal = audio_signal-background_signal;
            % 
            %       % Write the background and foreground signals
            %       audiowrite('background_signal.wav',background_signal,sampling_frequency)
            %       audiowrite('foreground_signal.wav',foreground_signal,sampling_frequency)
            % 
            %       % Compute the mixture, background, and foreground spectrograms
            %       window_length = 2^nextpow2(0.04*sampling_frequency);
            %       window_function = hamming(window_length,'periodic');
            %       step_length = window_length/2;
            %       audio_spectrogram = abs(spectrogram(mean(audio_signal,2),window_length,window_length-step_length));
            %       background_spectrogram = abs(spectrogram(mean(background_signal,2),window_length,window_length-step_length));
            %       foreground_spectrogram = abs(spectrogram(mean(foreground_signal,2),window_length,window_length-step_length));
            % 
            %       % Display the mixture, background, and foreground spectrograms in dB, seconds, and Hz
            %       time_duration = length(audio_signal)/sampling_frequency;
            %       maximum_frequency = sampling_frequency/8;
            %       xtick_step = 1;
            %       ytick_step = 1000;
            %       figure
            %       subplot(3,1,1)
            %       repet.specshow(audio_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Audio spectrogram (dB)')
            %       subplot(3,1,2)
            %       repet.specshow(background_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Background spectrogram (dB)')
            %       subplot(3,1,3)
            %       repet.specshow(foreground_spectrogram(1:window_length/8,:),time_duration,maximum_frequency,xtick_step,ytick_step)
            %       title('Foreground spectrogram (dB)')
            
            % Get the number of samples and channels
            [number_samples,number_channels] = size(audio_signal);
            
            % Set the parameters for the STFT 
            % (audio stationary around 40 ms, power of 2 for fast FFT and constant overlap-add (COLA),
            % periodic Hamming window for COLA, and step equal to half the window length for COLA)
            window_length = 2^nextpow2(0.04*sampling_frequency);
            window_function = hamming(window_length,'periodic');
            step_length = window_length/2;
            
            % Derive the number of time frames
            number_times = ceil((number_samples-window_length)/step_length+1);
            
            % Derive the number of frequency channels
            number_frequencies = window_length/2+1;
            
            % Get the buffer length in time frames
            buffer_length2 = round((repet.buffer_length*sampling_frequency)/step_length);
            
            % Initialize the buffer spectrogram
            buffer_spectrogram = zeros(number_frequencies,buffer_length2,number_channels);
            
            % Loop over the time frames to compute the buffer spectrogram
            % (the last frame will be the frame to be processed)
            k = 0;
            for j = 1:buffer_length2-1
                
                % Loop over the channels
                for i = 1:number_channels
                    
                    % Compute the FT of the segment
                    buffer_ft = fft(audio_signal(k+1:k+window_length,i).*window_function);
                    
                    % Derive the spectrum of the frame
                    buffer_spectrogram(:,j,i) = abs(buffer_ft(1:number_frequencies));
                    
                end
                
                % Update the index
                k = k+step_length;
                
            end
            
            % Zero-pad the audio signal at the end
            audio_signal = [audio_signal;zeros((number_times-1)*step_length+window_length-number_samples,number_channels)];
            
            % Get the similarity distance in time frames
            similarity_distance2 = round(repet.similarity_distance*sampling_frequency/step_length);
            
            % Get the cutoff frequency in frequency channels 
            % for the dual high-pass filter of the foreground
            cutoff_frequency2 = ceil(repet.cutoff_frequency*window_length/sampling_frequency);
            
            % Initialize the background signal
            background_signal = zeros((number_times-1)*step_length+window_length,number_channels);

            % Loop over the time frames to compute the background signal
            for j = buffer_length2:number_times
                
                % Get the time index of the current frame
                j0 = mod(j-1,buffer_length2)+1;
                
                % Initialize the FT of the current segment
                current_ft = zeros(window_length,number_channels);
                
                % Loop over the channels
                for i = 1:number_channels
                    
                    % Compute the FT of the current segment
                    current_ft(:,i) = fft(audio_signal(k+1:k+window_length,i).*window_function);
                    
                    % Derive the magnitude spectrum and update the buffer spectrogram
                    buffer_spectrogram(:,j0,i) = abs(current_ft(1:number_frequencies,i));
                    
                end
                
                % Compute the cosine similarity between the spectrum of the current frame 
                % and the past frames, for all the channels
                similarity_vector ...
                    = repet.similaritymatrix(mean(buffer_spectrogram,3),mean(buffer_spectrogram(:,j0,:),3));
                
                % Estimate the indices of the similar frames
                [~,similarity_indices] ...
                    = repet.localmaxima(similarity_vector,repet.similarity_threshold,similarity_distance2,repet.similarity_number);
                
                % Loop over the channels
                for i = 1:number_channels
                    
                    % Compute the repeating spectrum for the current frame
                    repeating_spectrum = median(buffer_spectrogram(:,similarity_indices,i),2);
                    
                    % Refine the repeating spectrum
                    repeating_spectrum = min(repeating_spectrum,buffer_spectrogram(:,j0,i));
                    
                    % Derive the repeating mask for the current frame
                    repeating_mask = (repeating_spectrum+eps)./(buffer_spectrogram(:,j0,i)+eps);
                    
                    % Perform a high-pass filtering of the dual foreground
                    repeating_mask(2:cutoff_frequency2+1,:) = 1;
                    
                    % Recover the mirrored frequencies
                    repeating_mask = cat(1,repeating_mask,repeating_mask(end-1:-1:2));
                    
                    % Apply the mask to the FT of the current segment
                    background_ft = repeating_mask.*current_ft(:,i);
                    
                    % Take the inverse FT of the current segment
                    background_signal(k+1:k+window_length,i) ...
                        = background_signal(k+1:k+window_length,i)+real(ifft(background_ft));
                    
                end
                
                % Update the index
                k = k+step_length;
                
            end
            
            % Truncate the signal to the original length
            background_signal = background_signal(1:number_samples,:);
            
            % Normalize the signal by the gain introduced by the COLA (if any)
            background_signal = background_signal/sum(window_function(1:step_length:window_length));
            
        end
        
        function specshow(audio_spectrogram, number_samples, sampling_frequency, xtick_step, ytick_step)
            % specshow Display a spectrogram in dB, seconds, and Hz.
            %   repet.specshow(audio_spectrogram, number_samples, sampling_frequency, xtick_step, ytick_step)
            %   
            %   Inputs:
            %       audio_spectrogram: audio spectrogram (without DC and mirrored frequencies) [number_frequencies, number_times]
            %       number_samples: number of samples from the original signal
            %       sampling_frequency: sampling frequency from the original signal in Hz
            %       xtick_step: step for the x-axis ticks in seconds (default: 1 second)
            %       ytick_step: step for the y-axis ticks in Hz (default: 1000 Hz)
            
            % Set the default values for xtick_step and ytick_step
            if nargin <= 3
                xtick_step = 1;
                ytick_step = 1000;
            end
            
            % Get the number of frequency channels and time frames
            [number_frequencies,number_times] = size(audio_spectrogram);
            
            % Derive the number of Hertz and seconds
            number_hertz = sampling_frequency/2;
            number_seconds = number_samples/sampling_frequency;
            
            % Derive the number of time frames per second and the number of frequency channels per Hz
            time_resolution = number_times/number_seconds;
            frequency_resolution = number_frequencies/number_hertz;
            
            % Prepare the tick locations and labels for the x-axis
            xtick_locations = xtick_step*time_resolution:xtick_step*time_resolution:number_times;
            xtick_labels = xtick_step:xtick_step:number_seconds;
            
            % Prepare the tick locations and labels for the y-axis
            ytick_locations = ytick_step*frequency_resolution:ytick_step*frequency_resolution:number_frequencies;
            ytick_labels = ytick_step:ytick_step:number_hertz;
            
            % Display the spectrogram in dB, seconds, and Hz
            imagesc(db(audio_spectrogram))
            axis xy
            colormap(jet)
            xticks(xtick_locations)
            xticklabels(xtick_labels)
            yticks(ytick_locations)
            yticklabels(ytick_labels)
            xlabel('Time (s)')
            ylabel('Frequency (Hz)')
            
        end
        
    end
    
    % Define the private methods
    methods (Access = private, Static = true)
        
        function audio_stft = stft(audio_signal,window_function,step_length)
            %   audio_stft = repet.stft(audio_signal,window_function,step_length)
            %   
            %   Inputs:
            %       audio_signal: audio signal [number_samples,1]
            %       window_function: window function [window_length,1]
            %       step_length: step length in samples
            %   Output:
            %       audio_stft: audio STFT [window_length,number_frames]
            
            % Get the number of samples and the window length in samples
            number_samples = length(audio_signal);
            window_length = length(window_function);
            
            % Derive the zero-padding length at the start and at the end of the signal to center the windows
            padding_length = floor(window_length/2);
            
            % Compute the number of time frames given the zero-padding at the start and at the end of the signal
            number_times = ceil(((number_samples+2*padding_length)-window_length)/step_length)+1;
            
            % Zero-pad the start and the end of the signal to center the windows
            audio_signal = [zeros(padding_length,1);audio_signal; ...
                zeros((number_times*step_length+(window_length-step_length)-padding_length)-number_samples,1)];
            
            % Initialize the STFT
            audio_stft = zeros(window_length,number_times);
            
            % Loop over the time frames
            i = 0;
            for j = 1:number_times
                
                % Window the signal
                audio_stft(:,j) = audio_signal(i+1:i+window_length).*window_function;
                i = i+step_length;
                
            end
            
            % Compute the Fourier transform of the frames using the FFT
            audio_stft = fft(audio_stft);
            
        end
        
        function audio_signal = istft(audio_stft,window_function,step_length)
            % istft Compute the inverse short-time Fourier transform (STFT).
            %   audio_signal = repet.istft(audio_stft,window_function,step_length)
            %   
            %   Inputs:
            %       audio_stft: audio STFT [window_length,number_frames]
            %       window_function: window function [window_length,1]
            %       step_length: step length in samples
            %   Output:
            %       audio_signal: audio signal [number_samples,1]
            
            % Get the window length in samples and the number of time frames
            [window_length,number_times] = size(audio_stft);
            
            % Compute the number of samples for the signal
            number_samples = number_times*step_length+(window_length-step_length);
            
            % Initialize the signal
            audio_signal = zeros(number_samples,1);
            
            % Compute the inverse Fourier transform of the frames and real part to ensure real values
            audio_stft = real(ifft(audio_stft));
            
            % Loop over the time frames
            i = 0;
            for j = 1:number_times
                
                % Perform a constant overlap-add (COLA) of the signal 
                % (with proper window function and step length)
                audio_signal(i+1:i+window_length) ...
                    = audio_signal(i+1:i+window_length)+audio_stft(:,j);
                i = i+step_length;
                
            end
            
            % Remove the zero-padding at the start and at the end of the signal
            audio_signal = audio_signal(window_length-step_length+1:number_samples-(window_length-step_length));
            
            % Normalize the signal by the gain introduced by the COLA (if any)
            audio_signal = audio_signal/sum(window_function(1:step_length:window_length));
            
        end
        
        function autocorrelation_matrix = acorr(data_matrix)
            % acorr Compute the autocorrelation of the columns in a matrix using the Wiener�Khinchin theorem.
            %   autocorrelation_matrix = repet.acorr(data_matrix)
            %   
            %   Input:
            %       data_matrix: data matrix [number_rows,number_columns]
            %   Output:
            %       autocorrelation_matrix: autocorrelation matrix [number_lags,number_columns]
            
            % Get the number of rows in each column
            number_rows = size(data_matrix,1);
            
            % Compute the power spectral density (PSD) of the columns
            % (with zero-padding for proper autocorrelation)
            data_matrix = abs(fft(data_matrix,2*number_rows)).^2;
            
            % Compute the autocorrelation using the Wiener�Khinchin theorem
            % (the PSD equals the Fourier transform of the autocorrelation)
            autocorrelation_matrix = real(ifft(data_matrix)); 
            
            % Discard the symmetric part
            autocorrelation_matrix = autocorrelation_matrix(1:number_rows,:);
            
            % Derive the unbiased autocorrelation
            autocorrelation_matrix = autocorrelation_matrix./(number_rows:-1:1)';
            
        end
        
        function beat_spectrum = beatspectrum(audio_spectrogram)
            % beatspectrum Compute the beat spectrum using autocorrelation.
            %   autocorrelation_matrix = repet.acorr(data_matrix)
            %   
            %   Input:
            %       audio_spectrogram: audio spectrogram [number_frequencies,number_times]
            %   Output:
            %       beat_spectrum: beat spectrum [number_lags,1]
            
            % Compute the autocorrelation of the frequency channels
            beat_spectrum = repet.acorr(audio_spectrogram');
            
            % Take the mean over the frequency channels
            beat_spectrum = mean(beat_spectrum,2);
            
        end
        
        function beat_spectrogram = beatspectrogram(audio_spectrogram,segment_length,segment_step)
            % beatspectrogram Compute the beat spectrogram using the beat sectrum.
            %   autocorrelation_matrix = repet.acorr(data_matrix)
            %   
            %   Inputs:
            %       audio_spectrogram: audio spectrogram [number_frequencies,number_times]
            %       segment_length: segment length in seconds for the segmentation
            %       segment_step: step length in seconds for the segmentation
            %   Output:
            %       beat_spectrogram: beat spectrogram [number_lags,number_times]
            
            % Get the number of frequency channels and time frames
            [number_frequencies,number_times] = size(audio_spectrogram);
            
            % Zero-pad the audio spectrogram to center the segments
            audio_spectrogram = [zeros(number_frequencies,ceil((segment_length-1)/2)), ...
                audio_spectrogram,zeros(number_frequencies,floor((segment_length-1)/2))];
            
            % Initialize beat spectrogram
            beat_spectrogram = zeros(segment_length,number_times);
            
            % Loop over the time frames every segment step (including the last one)
            for i = 1:segment_step:number_times
                
                % Compute the beat spectrum of the centered audio spectrogram segment
                beat_spectrogram(:,i) = repet.beatspectrum(audio_spectrogram(:,i:i+segment_length-1));
                
                % Replicate the values between segment steps
                beat_spectrogram(:,i+1:min(i+segment_step-1,number_times)) ... 
                    = repmat(beat_spectrogram(:,i),[1,min(i+segment_step-1,number_times)-i]);
                
            end

        end
        
        function similarity_matrix = selfsimilaritymatrix(data_matrix)
            % selfsimilaritymatrix Compute the self-similarity between the columns of a matrix using the cosine similarity.
            %   similarity_matrix = repet.selfsimilaritymatrix(data_matrix)
            %   
            %   Input:
            %       data_matrix: data matrix [number_rows,number_columns]
            %   Output:
            %       similarity_matrix: self-similarity matrix [number_columns,number_columns]
            
            % Divide each column by its Euclidean norm
            data_matrix = data_matrix./sqrt(sum(data_matrix.^2,1));
            
            % Multiply each normalized columns with each other
            similarity_matrix = data_matrix'*data_matrix;
            
        end
        
        function similarity_matrix = similaritymatrix(data_matrix1,data_matrix2)
            % similaritymatrix Compute the similarity between the columns of two matrices using the cosine similarity.
            %   similarity_matrix = repet.similaritymatrix(data_matrix1,data_matrix2)
            %   
            %   Inputs:
            %       data_matrix1: data matrix [number_rows,number_columns1]
            %       data_matrix2: data matrix [number_rows,number_columns2]
            %   Output:
            %       similarity_matrix: similarity matrix [number_columns1,number_columns2]
            
            % Divide each column of the matrices by its Euclidean norm
            data_matrix1 = data_matrix1./sqrt(sum(data_matrix1.^2,1));
            data_matrix2 = data_matrix2./sqrt(sum(data_matrix2.^2,1));
            
            % Multiply the normalized matrices with each other
            similarity_matrix = data_matrix1'*data_matrix2;
            
        end
        
        function repeating_periods = periods(beat_spectrogram,period_range)
            % periods Compute the repeating period(s) from the beat spectrogram(spectrum) given a period range.
            %   repeating_periods = repet.periods(beat_spectrogram)
            %   
            %   Input:
            %       beat_spectrogram: beat spectrogram (or spectrum) [number_lags,number_times] (or [number_lags,1])
            %   Output:
            %       repeating_periods: repeating period(s) in lags [number_periods,1] (or scalar)
            
            % Compute the repeating periods as the argmax for all the time frames given the period range
            % (should be less than a third of the length to have at least 3 segments for the median filter)
            [~,repeating_periods] = max(beat_spectrogram(period_range(1)+1:min(period_range(2),floor(size(beat_spectrogram,1)/3)),:),[],1);
            
            % Re-adjust the indices
            repeating_periods = repeating_periods+period_range(1);
            
        end
        
        function [maximum_values,maximum_indices] = localmaxima(data_vector,minimum_value,minimum_distance,number_values)
            % localmaxima Compute the values and indices of the local maxima in a vector given a number of parameters.
            %   repeating_periods = repet.periods(beat_spectrogram)
            %   
            %   Inputs:
            %       data_vector: data vector [number_elements,1]
            %       minimum_value: minimal value for a local maximum
            %       minimum_distance: minimal distance between two local maxima
            %       number_values: maximal number of local maxima
            %   Outputs:
            %       maximum_value: values of the local maxima [number_maxima,1]
            %       maximum_index: indices of the local maxima [number_maxima,1]
        
            % Get the number of elements in the vector
            number_elements = numel(data_vector);
            
            % Initialize an array for the indices of the local maxima
            maximum_indices = [];
            
            % Loop over the elements in the vector
            for i = 1:number_elements
                
                % Make sure the local maximum is greater than the minimum value
                if data_vector(i) >= minimum_value
                    
                    % Make sure the local maximum is strictly greater 
                    % than the neighboring values within +- the minimum distance
                    if all(data_vector(i) > data_vector(max(i-minimum_distance,1):i-1)) ...
                            && all(data_vector(i) > data_vector(i+1:min(i+minimum_distance,number_elements)))
                        
                        % Save the index of the local maxima
                        maximum_indices = cat(1,maximum_indices,i);
                        
                    end
                end
            end
            
            % Get the values of the local maxima
            maximum_values = data_vector(maximum_indices);
            
            % Get the values and the corresponding indices sorted in ascending order
            [maximum_values,sort_indices] = sort(maximum_values,'descend');
            
            % Keep only the sorted indices for the top values
            number_values = min(number_values,numel(maximum_values));
            sort_indices = sort_indices(1:number_values);
            
            % Get the values and indices of the top local maxima
            maximum_values = maximum_values(1:number_values);
            maximum_indices = maximum_indices(sort_indices);
            
        end
        
        function similarity_indices = indices(similarity_matrix,similarity_threshold,similarity_distance,similarity_number)
            % indices Compute the similarity indices from the similarity matrix.
            %   repeating_periods = repet.periods(beat_spectrogram)
            %   
            %   Inputs:
            %       similarity_matrix: similarity matrix [number_frames,number_frames]
            %       similarity_threshold: minimal threshold for two frames to be considered similar in [0,1]
            %       similarity_distance: minimal distance between two frames to be considered similar in frames
            %       similarity_number: maximal number of frames to be considered similar for every frame
            %   Output:
            %       similarity_indices: list of indices of the similar frames for every frame [number_frames,1]
            
            % Get the number of time frames
           	number_times = size(similarity_matrix,1);
            
            % Initialize the similarity indices
            similarity_indices = cell(1,number_times);
            
            % Loop over the time frames
            for i = 1:number_times
                
                % Get the indices of the local maxima
                [~,maximum_indices]...
                    = repet.localmaxima(similarity_matrix(:,i),similarity_threshold,similarity_distance,similarity_number);
                
                % Store the similarity indices for the current time frame
                similarity_indices{i} = maximum_indices;
                
            end
            
        end
        
        function repeating_mask = mask(audio_spectrogram,repeating_period)
            % mask Compute the repeating mask for REPET.
            %   repeating_period = repet.mask(audio_spectrogram,repeating_period)
            %   
            %   Inputs:
            %       audio_spectrogram: audio spectrogram [number_frequencies,number_times]
            %       repeating_period: repeating period in lag
            %   Output:
            %       repeating_mask: repeating mask [number_frequencies,number_times]
            
            % Get the number of frequency channels and time frames
            [number_frequencies,number_times] = size(audio_spectrogram);
            
            % Estimate the number of segments (including the last partial one)
            number_segments = ceil(number_times/repeating_period);
            
            % Pad the end of the spectrogram to have a full last segment
            audio_spectrogram = [audio_spectrogram,nan(number_frequencies,number_segments*repeating_period-number_times)];
            
            % Reshape the padded spectrogram to a tensor of size [number_frequencies,number_times,number_segments]
            audio_spectrogram = reshape(audio_spectrogram,[number_frequencies,repeating_period,number_segments]);
            
            % Compute the repeating segment by taking the median over the segments, not accounting for the last nans
            repeating_segment = [median(audio_spectrogram(:,1:number_times-(number_segments-1)*repeating_period,:),3), ... 
                median(audio_spectrogram(:,number_times-(number_segments-1)*repeating_period+1:repeating_period,1:end-1),3)];
            
            % Derive the repeating spectrogram by ensuring 
            % it has less energy than the original spectrogram
            repeating_spectrogram = min(audio_spectrogram,repeating_segment);
            
            % Derive the repeating mask by normalizing the repeating spectrogram 
            % by the original spectrogram
            repeating_mask = (repeating_spectrogram+eps)./(audio_spectrogram+eps);
            
            % Reshape the repeating mask into [number_frequencies,number_times] 
            % and truncate to the original number of time frames
            repeating_mask = reshape(repeating_mask,[number_frequencies,number_segments*repeating_period]);
            repeating_mask = repeating_mask(:,1:number_times);
            
        end
        
        function repeating_mask = adaptivemask(audio_spectrogram,repeating_periods,filter_order)
            % adaptivemask Compute the repeating mask for the adaptive REPET.
            %   repeating_period = repet.mask(audio_spectrogram,repeating_period)
            %   
            %   Inputs:
            %       audio_spectrogram: audio spectrogram [number_frequencies,number_times]
            %       repeating_period: repeating period in lag
            %       filter_order: filter order for the median filter in number of time frames
            %   Output:
            %       repeating_mask: repeating mask [number_frequencies,number_times]
            
            % Get the number of frequency channels and time frames in the spectrogram
            [number_frequencies,number_times] = size(audio_spectrogram);
            
            % Derive the indices of the center frames for the median filter given the filter order
            % (3 => [-1, 0, 1], 4 => [-1, 0, 1, 2], etc.)
            center_indices = (1:filter_order)-ceil(filter_order/2);
            
            % Initialize the repeating spectrogram
            repeating_spectrogram = zeros(number_frequencies,number_times);
            
            % Loop over the time frames
            for i = 1:number_times
                
                % Derive the indices of all the frames for the median filter
                % given the repeating period for the current frame in the spectrogram
                all_indices = i+center_indices*repeating_periods(i);
                
                % Discard the indices that are out-of-range
                all_indices(all_indices<1 | all_indices>number_times) = [];
                
                % Compute the median filter for the current frame in the spectrogram
                repeating_spectrogram(:,i) = median(audio_spectrogram(:,all_indices),2);
                
            end
            
            % Refine the repeating spectrogram by ensuring 
            % it has less energy than the original spectrogram
            repeating_spectrogram = min(audio_spectrogram,repeating_spectrogram);
            
            % Derive the repeating mask by normalizing the repeating spectrogram 
            % by the original spectrogram
            repeating_mask = (repeating_spectrogram+eps)./(audio_spectrogram+eps);

        end
        
        function repeating_mask = simmask(audio_spectrogram,similarity_indices)
            % simmask Compute the repeating mask for REPET-SIM.
            %   repeating_period = repet.mask(audio_spectrogram,repeating_period)
            %   
            %   Input:
            %       audio_spectrogram: audio spectrogram (number_frequencies, number_times)
            %       similarity_indices: list of indices of the similar frames for every frame [number_frames,1]
            %   Output:
            %       repeating_mask: repeating mask [number_frequencies,number_times]
            
            % Get the number of frequency channels and time frames in the spectrogram
            [number_frequencies,number_times] = size(audio_spectrogram);
            
            % Initialize the repeating spectrogram
            repeating_spectrogram = zeros(number_frequencies,number_times);
            
            % Loop over the time frames
            for i = 1:number_times
                
                % Get the indices of the similar frames for the median filter
                time_indices = similarity_indices{i};
                
                % Compute the median filter for the current frame in the spectrogram
                repeating_spectrogram(:,i) = median(audio_spectrogram(:,time_indices),2);
                
            end
            
            % Refine the repeating spectrogram by ensuring 
            % it has less energy than the original spectrogram
            repeating_spectrogram = min(audio_spectrogram,repeating_spectrogram);
            
            % Derive the repeating mask by normalizing the repeating spectrogram 
            % by the original spectrogram
            repeating_mask = (repeating_spectrogram+eps)./(audio_spectrogram+eps);

        end
    
    end
    
end
