clc
clear all
close all

useMic = 1; % enables mic
sb = 1; % significant bit

waveData = 0;
waveDataSize = 0;
winSize = 44100;
redordedAudioAdd = 'C:\Users\Sajjad\Desktop\projects\Matlab\recorded audio.wav';
encodedVideoAdd = 'C:\Users\Sajjad\Desktop\projects\Matlab\encoded video.avi';
outputAudioAdd = 'C:\Users\Sajjad\Desktop\projects\Matlab\output audio.wav';

% get audio
if useMic == 1
    disp('using mic to get audio.')
    recObj = audiorecorder(winSize, 16, 1);
    disp('Recording started ...')
    recordblocking(recObj, 10); % record for 10s
    disp('Recording stoped.');
    audiowrite(redordedAudioAdd, getaudiodata(recObj), winSize);
    [waveData, winSize] = audioread(redordedAudioAdd);
    waveDataSize = size(waveData);
else
    disp('using file picker to get audio.')
    [filename, filepath] = uigetfile('*.wav', 'Pick an audio file');
    [waveData, winSize] = audioread(strcat(filepath, filename));
    waveDataSize = size(waveData);
end

% convert audio data to binary
disp('converting audio to binary ...')
wavebinary = dec2bin(typecast(single(waveData(:)), 'uint8'), 8) - '0';
audioSize = size(wavebinary); % for reshape
audioNumel = numel(wavebinary);

% get video
disp('using file picker to get video.')
[filename, filepath] = uigetfile('*.mp4', 'Pick an video file');
videoData = VideoReader(strcat(filepath, filename));

% check if auido fits in the video
disp('checking if audio fits in the video ...')
frame = read(videoData, 1); % select one frame
redChannel = frame(:, :, 1); % select red channel
videoNumel = numel(redChannel) * videoData.NumberOfFrames;
if (videoNumel < audioNumel)
    disp('Audio is too big for video!')
    return
end

% geting video frames
disp('encoding started ...');
noOfSavedData = 0;
noOfRemainData = audioNumel;
noOfChangedFrames = 0;
isDone = 0;
encodedImages = cell([],1) ;
for frameAddress=1 : videoData.NumberOfFrames
    selectedFrame = read(videoData, frameAddress);
    red = selectedFrame(:, :, 1);
    green = selectedFrame(:, :, 2);
    blue = selectedFrame(:, :, 3);
    selectedFrame = red;

    binFrame = de2bi(selectedFrame, 8); % convert frame to 8bit binary
    frameLsb = binFrame(:, sb); % select significant bit
    
% encode   
    for i=1 : noOfRemainData
        if i > numel(frameLsb) 
            noOfRemainData = audioNumel - noOfSavedData;
            break % move to next frame
        else % saving data
            noOfSavedData = noOfSavedData + 1;
            frameLsb(i) = wavebinary(noOfSavedData);
        end
        
        if noOfSavedData == audioNumel % end condition
            isDone = 1;
            break
        end
    end
  
    binFrame(:, sb) = reshape(frameLsb, size(binFrame(:, sb)));
    
% generate encoded image
    stegImage = zeros(size(selectedFrame));
    for i=1 : 8
        stegData = binFrame(:, i);
        stegData = reshape(stegData, size(selectedFrame));
        stegImage = stegImage + double(stegData)*2^(i-1);
    end
    
    stegFrame = cat(3, stegImage, green, blue); % concatenate rgb channels

    figure;imshow(stegFrame, []);title('Steganographed frame')
    encodedImages{frameAddress} = stegFrame;
    
    if isDone == 1
        noOfChangedFrames = frameAddress;
        break
    end
end

% generate encoded video
disp('genarting encoded video ...')
mov(1 : videoData.NumberOfFrames) = struct('cdata', zeros(videoData.Height, videoData.width, 3, 'uint8'), 'colormap', []);
for k = 1 : videoData.NumberOfFrames % save encoded images in struct
    if k <= noOfChangedFrames
        mov(k).cdata = encodedImages{k}; % read from encoded images
    else
        mov(k).cdata = read(videoData, k); % read from orginal video
    end    
end

writerObj = VideoWriter(encodedVideoAdd, 'Uncompressed AVI');
writerObj.FrameRate = videoData.FrameRate;
open(writerObj);
for k = 1 : 1 : videoData.NumberOfFrames
    writeVideo(writerObj, mov(k));
end
close(writerObj);
implay(encodedVideoAdd);

% decode
disp('decoding started ...')
data=[];
noOfSavedData = 0;
noOfRemainData = 0;
encodedVideoData = VideoReader(encodedVideoAdd);
for i=1 : noOfChangedFrames
    encodedFrame = read(encodedVideoData, i);
    red = encodedFrame(:, :, 1);
    green = encodedFrame(:, :, 2);
    blue = encodedFrame(:, :, 3);
    
    encodedFrame = red;
    
    binFrame = de2bi(encodedFrame, 8);
    frameLsb = binFrame(:, sb); % select significant bit
    
    length = 0; % specifies how much should be read from the frame
    
    if audioNumel - noOfSavedData > numel(red)
        length = numel(red);
    else
        length = audioNumel - noOfSavedData;
    end

    for j=1 : length
        data(j+noOfRemainData) = frameLsb(j);
        noOfSavedData = noOfSavedData + 1;
    end
    noOfRemainData = noOfSavedData;
end

% convert vectorize to 8bit
data = reshape(data, audioSize);

% convert binary inforamtion to audio data
decodedAudio = reshape(typecast(uint8(bin2dec(char(data + '0'))), 'single'), waveDataSize);

% saving decoded audio
audiowrite(outputAudioAdd, decodedAudio, winSize);
disp('decoded audio generated successfully!')


