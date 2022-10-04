# oscoverlay

A new Flutter project.

## Getting Started

- Install the APK on your phone
- Connect the phone on the same wifi network as your computer
- Check your phone's IP in the settings
- Launch the app and check the available OSC commands with their signature
- Enter the phone's IP in your OSC software and start controlling the phone
- You can either send a /stop command or double-tap the overlay to close it 

## Commands
- /play < file.ext:string > (mp3, mp4, wav...)
- /play < url:string > ( http://192.168.1.10/file.mp4 )
- /stop
- /vibrate < time:float > ( seconds )
- /color < r:float > < g:float > < b:float > ( each channel between 0 and 1)
- /text < text > [< fontSize: float > < textColor: r g b > < bgColor: r g b >]

Local media files should be placed in the app folder shown in the main screen of the app
