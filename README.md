# Musical Cane Game

Last updated : April 25th, 2019

## Background

This project has been initiated and maintained by Paul's students (Occam Lab, TAD)
Eric Jerman from Perkins School for the Blind is our primary partner for this project.
He works with students at Perkins School for the Blind to help them develop their orientation and mobility skills.
**Orientation and Mobility** refers to a set of skills that consists of knowing where you are in an environment, understanding how to navigate to a place of interest, and how to move about safely within an environment.While these skills are vital to the independence of Eric’s students, their motivation to practice these skills is often low.  In contrast, other elements of the Perkins curriculum (e.g., music therapy) tend to be met with more excitement and commitment.  Eric is interested in developing strategies for making his sessions more engaging and effective through the use of the concept of gamified learning, whereby elements of game design are brought to an educational context.


## Introduction

Musical Cane Game gamifies the orientation and mobility learning experience and helps an O&M instructor by
- Motivating students with sounds, music, and beep noises
- Rewarding students while preventing them from "cheating"
- Providing Real-Time feedback of a student's cane sweep through the app screen
- Enabling customized support for each individual student (cane length, sweep range, skill level)
- Introducing cool features like "Shepard's Grip"

### How to Play

This guide is for the O&M instructor who runs the training sessions with students who play this game.
To play our musical cane game,

1. Create a new profile for the student.
2. Touch 'Edit'
3. Select the student's favorite music, sounds, and beep noises from Apple Music. 
   You need to put sound files into Apple Music if you don't have any
   (The app only selects music files from Apple Music)
4. Set custom values for the student
     - Beep Count : Number of Beeps needed for the reward music to play
     - Cane Length (inches) : Length between the tip of the cane and the student's grip
     - Sweep Range (inches): Chord Length (straight line from left end to right end) of the sweep range
     - Skill Level : Determines the error tolerance (from 1 being super loose to 5 being super strict)
5. Touch 'Save'
6. Go to the side navigation and choose the game mode you would like to play
   There are three different modes available.
      - Sound Mode
      - Music Mode
      - Beep Mode
7. Touch 'Start'. With sound turned on, you should hear 'Connected, start sweeping'
8. Let the student start sweeping, refer to the screen to guide the student accordingly.
9. When the reward music plays, Touch 'Stop'. 

### Contribution Guide (for developers)

Code documentation (Jazzy) is available in `docs/`.

### Future Direction

- Tracking of a student's progress over multiple games (Generate daily, weekly, monthly development report)
- Beacons Mode (expansion of the game into learning spaces around)
- Detect Cane Velocity
