# iOS Pitch Detector & Video Exporter
demo of pitch detection and video exporting. This guy uses an open source pitch tracker named 
dywapitchtrack (http://www.schmittmachine.com/dywapitchtrack.html) to track monophonic pitch from the microphone or 
an input file. The video exporter creates a CADisplay timer which takes a (retina!) photo of a UIView handed to it at
a regular interval of 60 Hz. This video can then be combined with an audio file.

## TO RUN

Navigate to the directory in terminal and type "pod install"

## Using the Pitch Tracking

#### File Tracker
The file tracker can be used by selecting the 'pitch' option on the segmented control and then pressing either of
the play buttons. A sinusoid audio file will then be played. The file contains the frequencies 110, 220, 330, 440,
550, 660, 770, and 880 at even increments. The pitch tracker will output to the debugger what it thinks the current
pitch is. The format for the output is 

Rec. Pitch: _pitch in hertz_

#### Microphone Tracker
The microphone tracker is always on while the application is running. You simply speak, sing, or make noise into 
the simulator or iOS device and the microphone tracker will output to the debugger what it thinks the pitch is. The
text will be formatted as follows

Live Pitch: _pitch in hertz_

### Using the Video Exporting
The video exporter is started by pressing the _Record Video_ button. Wait some time and then press the button again
to stop the recording. After the rendering has completed, a tone audio file will be added to the video created. The
video will be saved to the Documents directory of the iPad or simulator.


#### Locating the files from Simulator
~/Library/Developer/CoreSimulator/Devices/**[DEVICE UUID]**/data/Containers/Data/Application/**[APP UUID]**/Documents

where **[DEVICE UUID]** and **[APP UUID]** will be giant strings that identify your app and device. Trial and error often works
for me to find the correct folders.

The files videoTest.mov and final_videoTest.mov will be in the folder. The first file has no audio, and the second file has audio
added to the file.

#### Locating the files from Device

In XCode 6, hit Shift Command 2 to open the devices window. Alternatively hit Window->Devices in the tool bar. Select your connected 
iOS device. Select AudioAPITesting in the section _Installed Apps_. Press the gear below _Installed Apps_. Select Download Container. 
Save the container and view it in Finder. Right click the container. Select _Show Package Contents_. Navigate to AppData->Documents
and the files videoTest.mov and final_videoTest.mov should be in the folder.

## Known issues

#### Microphone Pitch Tracking
The pitch tracking algorithm does not handle audio stopping very well. It will spit report a bunch of bad values
when input to the microphone stops.
