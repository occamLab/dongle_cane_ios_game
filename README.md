# Musical Cane Game

Last updated : May 10, 2019 by Team OM-ega

## Background

This project has been initiated and maintained by Paul's students (Occam Lab, TAD). Eric Jerman from Perkins School for the Blind is our primary partner for this project. He works with students at Perkins School for the Blind to help them develop their orientation and mobility skills.
**Orientation and Mobility** refers to a set of skills that consists of knowing where you are in an environment, understanding how to navigate to a place of interest, and how to move about safely within an environment.While these skills are vital to the independence of Eric’s students, their motivation to practice these skills is often low.  In contrast, other elements of the Perkins curriculum (e.g., music therapy) tend to be met with more excitement and commitment.  Eric is interested in developing strategies for making his sessions more engaging and effective through the use of the concept of gamified learning, whereby elements of game design are brought to an educational context.

## Introduction

Musical Cane Game gamifies the orientation and mobility learning experience and helps an O&M instructor by
- Motivating students with sounds, music, and beep noises
- Rewarding students while preventing them from "cheating"
- Providing real-time feedback of a student's cane sweep through the app screen
- Enabling customized support for each individual student (cane length, sweep range, skill level)
- Introducing cool features like "Shepard's Grip"

Please take a look at our to get a quick sense of how the game works. 
- [demo video 1](https://drive.google.com/open?id=19O9A1Zl33U8vBhbvgl8cHi0ooh2F9v4x)
- [demo video 2](https://drive.google.com/open?id=1PkCNFPGI4S7V4RvfroAmBrIL4apV8vOf)

### How to Play

This guide is for the O&M instructor who runs the training sessions with students who play this game.
To play our musical cane game,

#### On the cane
Attach the bluetooth dongle to the cane using a zip tie. Orientation does not matter.
Take a paper clip, and unbend one end of it. Stick the end into the slot on the rounded side of the dongle. There is a switch inside that you must toggle. If you see a blue light on the dongle, that means the device is on! Remember to turn it back off when you are done.

![Dongle attached to a cane with a ziptie](https://raw.githubusercontent.com/occamLab/dongle_cane_ios_game/master/docs/img/setup1.jpg)
![Dongle attached to a cane with a ziptie](https://raw.githubusercontent.com/occamLab/dongle_cane_ios_game/master/docs/img/setup2.jpg)

#### On the App
1. Form the start screen, hit the menu navigation bar in the top left.
2. Select `Manage Profiles`
3. Create a new profile for the student by clicking `Create Profile` in the top right
4. Touch 'Edit'
5. Select the student's favorite music, sounds, and beep noises from Apple Music. 
   You need to put sound files into Apple Music if you don't have any
   (The app only selects music files from Apple Music)
6. Set custom values for the student
     - Beep Count : Number of Beeps needed for the reward music to play
     - Cane Length (inches) : Length between the tip of the cane and the student's grip
     - Sweep Range (inches): Chord Length (straight line from left end to right end) of the arc the cane makes
     - Skill Level : Determines the error tolerance (from 1 being super loose to 5 being super strict)
7. Touch `Save` in the top right.
8. Go to the side navigation and choose the game mode you would like to play. The student's name and other relevent information should appear on the screen when the mode is selected.
   There are three different modes available.
      - **Sound Mode**
          - **Speaking mode**: Phone says the number of sweeps
          - **Beep mode**: Phone plays the selected beep sound on each successful sweep
      - **Music Mode**: Phone plays music while there is successful sweeping
9. Touch 'Start' in the top right. With sound turned on, you should hear `Connected` and then `start sweeping`
10. Let the student start sweeping, there should be a progress bar indicating their progress on the current sweep. When students are in green zone, it means they could change directions and the sweep would be counted as valid. 
    - Remember that the app only measures the length the student is sweeping, not the orientation of the cane to the student.
    - If the green range is not representative of where you want them to be sweeping, consider changing the sweep range (for wider/shorter sweeps) or the user level (for more tolerence for bad sweeps).

11. When the reward music plays or you want to end the game, Touch `Stop` in the top right. 

### Contribution Guide (for developers)

#### Dev Environment Setup
The code is written in **Swift 4**.
When working on the app, open the workspace on Xcode.
Run `pod install` in a terminal to install the pods locally. 
(It uses an external library called [SQLite.swift](https://github.com/stephencelis/SQLite.swift) to manage the database for profile data).

#### Documentation
Code documentation (Jazzy) is available in `docs/`. The master branch automatically generates a [documentation website](https://occamlab.github.io/dongle_cane_ios_game/index.html) based on `docs/` 

To generate the documentation, you need to first install [Jazzy](https://github.com/realm/jazzy). 
Run `[sudo] gem install jazzy`.

Once the installation is done, 
Run `jazzy --min-acl internal` to build the documentation.
This command generates the website under `/docs`, and github deploys `master/docs` on every push.

Follow this [tutorial](https://www.appcoda.com/swift-markdown/) to learn how to add inline comments in markdown style so that Jazzy can parse them automatically.

### Future Dev Directions

- Tracking of a student's progress over multiple games (Generate daily, weekly, monthly development report)
- Beacons Mode (expansion of the game into learning spaces around)
- Detect Cane Velocity
- Refactor the code base (add more inline documentation in Jazzy Style)
- Fully support Apple Voiceover
