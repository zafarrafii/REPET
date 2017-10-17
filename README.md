# REpeating Pattern Extraction Technique (REPET)

## REPET Matlab class (repet.m)
  
Repetition is a fundamental element in generating and perceiving structure. In audio, mixtures are often composed of structures where a repeating background signal is superimposed with a varying foreground signal (e.g., a singer overlaying varying vocals on a repeating accompaniment or a varying speech signal mixed up with a repeating background noise). On this basis, we present the REpeating Pattern Extraction Technique (REPET), a simple approach for separating the repeating background from the non-repeating foreground in an audio mixture. The basic idea is to find the repeating elements in the mixture, derive the underlying repeating models, and extract the repeating  background by comparing the models to the mixture. Unlike other separation approaches, REPET does not depend on special parameterizations, does not rely on complex frameworks, and does not require external information. Because it is only based on repetition, it has the advantage of being simple, fast, blind, and therefore completely and easily automatable.

### REPET (original)

The original REPET aims at identifying and extracting the repeating patterns in an audio mixture, by estimating a period of the underlying repeating structure and modeling a segment of the periodically repeating background.

`background_signal = repet.original(audio_signal,sample_rate);`

### REPET extended

The original REPET can be easily extended to handle varying repeating structures, by simply applying the method along time, on individual segments or via a sliding window.

`background_signal = repet.extended(audio_signal,sample_rate);`

### Adaptive REPET

The original REPET works well when the repeating background is relatively stable (e.g., a verse or the chorus in a song); however, the repeating background can also vary over time (e.g., a verse followed by the chorus in the song). The adaptive REPET is an extension of the original repet that can handle varying repeating structures, by estimating the time-varying repeating periods and extracting the repeating background locally, without the need for segmentation or windowing.

`background_signal = repet.adaptive(audio_signal,sample_rate);`

### REPET-SIM

The REPET methods work well when the repeating background has periodically repeating patterns (e.g., jackhammer noise); however, the repeating patterns can also happen intermittently or without a global or local periodicity (e.g., frogs by a pond). REPET-SIM is a generalization of repet that can also handle non-periodically repeating structures, by using a similarity matrix to identify the repeating elements.

`background_signal = repet.sim(audio_signal,sample_rate);`

### Online REPET-SIM

REPET-SIM can be easily implemented online to handle real-time computing, particularly for real-time speech enhancement. The online REPET-SIM simply processes the time frames of the mixture one after the other given a buffer that temporally stores past frames.

`background_signal = repet.simonline(audio_signal,sample_rate);`
 
### Example

```
% Read the audio file, here, corresponding to a song
[audio_signal,sample_rate] = audioread('song.wav');

% Estimate the background using repet-SIM, and derive the 
% corresponding foreground (the parameters of the algorithm can be 
% redefined if necessary, in the properties of the class)
background_signal = repet.sim(audio_signal,sample_rate);
foreground_signal = audio_signal-background_signal;

% Write the background and foreground files, here corresponding to 
% the accompaniment and vocals, respectively
audiowrite('accompaniment.wav',background_signal,sample_rate)
audiowrite('vocals.wav',foreground_signal,sample_rate)
```

## REPET Python module (repet.py)

Working on it...

## References

- Zafar Rafii, Antoine Liutkus, and Bryan Pardo. "REPET for Background/Foreground Separation in Audio," Blind Source Separation, chapter 14, pages 395-411, Springer Berlin Heidelberg, 2014.

- Zafar Rafii and Bryan Pardo. "Online REPET-SIM for Real-time Speech Enhancement," 38th International Conference on Acoustics, Speech and Signal Processing, Vancouver, BC, Canada, May 26-31, 2013.

- Zafar Rafii and Bryan Pardo. "Audio Separation System and Method," US20130064379 A1, US 13/612,413, March 14, 2013.

- Zafar Rafii and Bryan Pardo. "REpeating Pattern Extraction Technique (REPET): A Simple Method for Music/Voice Separation," IEEE Transactions on Audio, Speech, and Language Processing, volume 21, number 1, pages 71-82, January, 2013.

- Zafar Rafii and Bryan Pardo. "Music/Voice Separation using the Similarity Matrix," 13th International Society on Music Information Retrieval, Porto, Portugal, October 8-12, 2012.

- Antoine Liutkus, Zafar Rafii, Roland Badeau, Bryan Pardo, and Gaël Richard. "Adaptive Filtering for Music/Voice Separation Exploiting the Repeating Musical Structure," 37th International Conference on Acoustics, Speech and Signal Processing,Kyoto, Japan, March 25-30, 2012.

- Zafar Rafii and Bryan Pardo. "A Simple Music/Voice Separation Method based on the Extraction of the Repeating Musical Structure," 36th International Conference on Acoustics, Speech and Signal Processing, Prague, Czech Republic, May 22-27, 2011.

See also http://zafarrafii.com/repet.html
