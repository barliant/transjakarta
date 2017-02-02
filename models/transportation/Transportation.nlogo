globals [ road-row rails-row bankrupt-row-max bankrupt-row-min shape-names colors used-shape-colors max-possible-codes
          road-money-collected rail-money-collected driver-speed-up driver-slow-down road-color rails-color]
breed [ drivers driver ]
breed [ rail-passengers rail-passenger ]
breed [ bankruptcies bankruptcy ]
turtles-own [ speed speed-limit speed-min user-id money salary color-name]

; ------------------------------------------------------
; Overall setup
; ------------------------------------------------------
to startup
  hubnet-set-client-interface "COMPUTER" []
  hubnet-reset
end
to setup
  set road-row 0
  set rails-row -5
  set bankrupt-row-min 5
  set bankrupt-row-max 6
  set road-color violet
  set rails-color red
  ;; The following two variables are taken from the traffic-basic model,
  ;; where they are sliders available for user modification.  Since traffic
  ;; in this model is affected much more dramatically by cars entering
  ;; the highway, I removed these from the GUI in the interest of cleaning
  ;; things up.
  set driver-speed-up 100
  set driver-slow-down 100
  set used-shape-colors []
  set shape-names ["wide wedge" "square" "car" "big boat" "pickup truck"
                   "nu" "uu" "circle" "butterfly" "sheep" "lobster" "monster"
                   "moose" "bear" "teddy bear"]
  set colors      [ gray   brown   green   lime   turquoise
                    cyan   sky   blue   violet ]
  set colors remove road-color colors
  set colors remove rails-color colors
  set max-possible-codes (length colors * length shape-names)
  ask patches [ setup-road ]
  setup-car-robots
  ask patches [ setup-rails ]
  setup-rail-robots
  ; Get rid of bankrupt robots
  ask bankruptcies with [user-id = 0] [die]
  ; Bankrupt users some money again
  ask bankruptcies with [user-id != 0] [ driver-to-onramp ]
  ask turtles [
       set money int random-normal initial-money-mean initial-money-sd
       set salary int random-normal individual-salary-mean individual-salary-sd
       if salary < 0 [ set salary 0 ]
      ]
  set-current-plot "Wealth distribution"
  histogram [ money ] of turtles
end
to setup-road
  if ( pycor = road-row ) [ set pcolor road-color ]
end
to setup-rails
  if ( pycor = rails-row ) [ set pcolor rails-color ]
end
;; pick a shape and color for the turtle
to set-unique-shape-and-color
  let code 0

  set code random max-possible-codes
  while [member? code used-shape-colors and ((count drivers + count rail-passengers) < max-possible-codes)]
  [
    set code random max-possible-codes
  ]
  set used-shape-colors (lput code used-shape-colors)
  set shape item (code mod length shape-names) shape-names
  set color item (code / length shape-names) colors
  if color = gray [set color-name "gray"]
  if color = brown [set color-name "brown"]
  if color = yellow [set color-name "yellow"]
  if color = green [set color-name "green"]
  if color = lime [set color-name "lime"]
  if color = turquoise [set color-name "turquoise"]
  if color = cyan [set color-name "cyan"]
  if color = sky [set color-name "sky"]
  if color = blue [set color-name "blue"]
  if color = violet [set color-name "violet"]
end
; ------------------------------------------------------
; Set up drivers (cars)
; ------------------------------------------------------
to setup-car-robots
  if ( initial-car-robots > world-width )
  [
    user-message (word "There are too many drivers for the amount of road.  Please decrease the INITIAL-CAR-ROBOTS slider to below " (world-width + 1) " and press the SETUP button again.  The setup has stopped.")
    stop
  ]
  ; Get rid of existing car-robots
  ask drivers with [user-id = 0] [die]
  create-drivers initial-car-robots [
    setup-generic-robot
    set ycor road-row
    separate-drivers
  ]
end
; this function is needed so when we click "Setup" we
; don't end up with any two drivers on the same patch
to separate-drivers  ; turtle procedure
  if any? other drivers-here
    [ fd 1
      separate-drivers ]
end

; this function is needed so when we click "Setup" we
; don't end up with any two drivers on the same patch
to separate-bankruptcies  ; turtle procedure
  if any? other bankruptcies-here
    [ set heading 90
      fd random 5
      separate-bankruptcies
    ]
end
to setup-generic-robot
    set xcor random-float world-width
    set heading 90
    set speed  0.1 + random 9.9
    set speed-limit  1
    set speed-min  0
    set salary int random-normal individual-salary-mean individual-salary-sd
    if salary < 0 [ set salary 0 ]
end

; ------------------------------------------------------
; Go!
; ------------------------------------------------------
to go
  let old-shape 0
  move-cars
  move-train
  ;; ---------------------------------------
  ;; Check for bankruptcies
  ask turtles with [ money <= 0 and (ycor = road-row or ycor = rails-row) ]
   [
     set old-shape shape
     set breed bankruptcies
     set shape old-shape
     set ycor bankrupt-row-min + random (bankrupt-row-max - bankrupt-row-min + 1)
     set speed 0
     set money 0
     separate-bankruptcies ]
  ;; Pay a salary to everyone on the right side of the screen
  ask turtles with [ xcor + speed > (max-pxcor + 0.5) ]
   [ set money money + salary ]
  set-current-plot "Wealth distribution"
  histogram [ money ] of turtles
  ;; ---------------------------------------------
  while [hubnet-message-waiting?]
  [
    hubnet-fetch-message
    ifelse hubnet-enter-message?
    [ create-entering-driver ]
    [
      ifelse hubnet-exit-message?
      [
        ask turtles with [user-id = hubnet-message-source] [ die ]
      ]
      [
        if hubnet-message-tag = "method-of-transportation"
        [
          if hubnet-message = "Drive"
          [ rail-passenger-becomes-driver hubnet-message-source]
          if hubnet-message = "Take the train"
          [ driver-becomes-rail-passenger hubnet-message-source]
        ]
      ]
    ]
  ]
  tick
  ;; Send info to the client window
  hubnet-broadcast "View" "View"
  hubnet-broadcast "Cost to drive" driver-cost
  hubnet-broadcast "Cost of train" train-cost
  ask turtles with [ user-id != 0 ]
   [
    hubnet-send user-id "Your savings" money
    hubnet-send user-id "Your salary" salary
    ifelse breed = bankruptcies
      [ hubnet-send user-id "You are a" (word "bankrupt " color-name " " shape) ]
      [ hubnet-send user-id "You are a" (word color-name " " shape) ]
   ]
  if ticks mod plot-frequency = 0 and any? drivers
  [ set-current-plot "Commuters"
    set-current-plot-pen "Bankruptcies"
    plot count bankruptcies
  ]
end

;; Client Message Processing Procedures
to listen-clients
end
to create-entering-driver
    create-drivers 1 [driver-to-onramp
                             set user-id hubnet-message-source
                             set-unique-shape-and-color
                             set money int random-normal initial-money-mean initial-money-sd
                             set salary int random-normal individual-salary-mean individual-salary-sd
                             if salary < 0 [ set salary 0 ]
                             ]
end
to move-cars
  ;; Drivers have two possible headings, 90 (on the road) and 180 (waiting to get
  ;; on the road).  If you're on the road, then try to move forward.  If you're
  ;; waiting to get on the road, then you have to wait for an opening.
  ask drivers [
    ifelse (heading = 90)
     ;; If heading is 90, then we are driving.  Set the car's
     ;; speed according to the car ahead of it, speeding up if no
     ;; one is there (and slowing down to match the car's speed
     ;; if someone is there).
     [ifelse any? drivers-at 1 0
       [ set speed ([speed] of one-of drivers-at 1 0)
         slow-down-driver ]
       [ speed-up-driver ]
       if speed < speed-min  [ set speed speed-min ]
       if speed > speed-limit   [ set speed speed-limit ]
       fd speed
       ;; Charge everyone at the right side of the screen
       if xcor + speed > (max-pxcor + 0.5)
         [ set money money - driver-cost
           set road-money-collected road-money-collected + driver-cost
           ]
       ]
     ;; If heading is not 90, then it is presumably
     ;; 180, which means that it is waiting to enter the road.
     ;; If there are no cars at the entry point, then
     ;; everyone moves forward, and the bottommost turtle
     ;; turns to have a heading of 90, like other cars on the road
     [if (not any? drivers-at 0 -1)
      [fd 1
       lt 90]
      ]
     ]
  plot-drivers
end
to move-train
  ask rail-passengers
  [ set speed (train-speed / 10)
    fd speed
    ;; Charge everyone at the right side of the screen
    if xcor + speed > (max-pxcor + 0.5)
     [ set money money - train-cost
       set rail-money-collected rail-money-collected + train-cost ]
   ]
  plot-rail-passengers
end
to slow-down-driver
  set speed speed - ( driver-slow-down / 1000 )
end
to speed-up-driver
  set speed ( speed + ( driver-speed-up / 10000 ) )
end
to plot-drivers
  if ticks mod plot-frequency = 0 and any? drivers
    [
      set-current-plot "Commuter Speed"
      set-current-plot-pen "Max Driver Speed"
      plot (10 * (max [speed] of drivers))
      set-current-plot-pen "Average Driver Speed"
      plot (10 * (mean [speed] of drivers))
      set-current-plot "Commuters"
      set-current-plot-pen "Drivers"
      plot count drivers
      set-current-plot "Money collected"
      set-current-plot-pen "Cars"
      plot road-money-collected
  ]
end
to add-car-robot
  ifelse (count drivers >= ( 2 * world-width))
    [ user-message "You have reached the max number of drivers"]
    [ create-drivers 1 [
        set money int random-normal initial-money-mean initial-money-sd
        set salary int random-normal individual-salary-mean individual-salary-sd
        if salary < 0 [set salary 0]
        driver-to-onramp
        ]
  ]
end
to driver-to-onramp  ;; turtle procedure
  let old-shape 0
  set old-shape shape
  set breed drivers
  set shape old-shape
  set heading 90
  set xcor (min-pxcor)
  set ycor 1
  set speed 0
  set speed-limit 1
  set speed-min 0
  separate-drivers
  rt 90
end
; ------------------------------------------------------
; Set up the rail-passengers
; ------------------------------------------------------
to setup-rail-robots
  if ( initial-rail-robots > world-width )
  [
    user-message (word "There are too many rail-passengers for the amount of road.  Please decrease the INITIAL-RAIL-ROBOTS slider to below " (world-width + 1) " and press the SETUP button again.  The setup has stopped.")
    stop
  ]
  ; Get rid of existing rail-robots
  ask rail-passengers with [user-id = 0] [die]
  create-rail-passengers initial-rail-robots [
    setup-generic-robot
    set ycor rails-row
    separate-rail-passengers
  ]
end
; this function is needed so when we click "Setup" we
; don't end up with any two drivers on the same patch
to separate-rail-passengers  ; turtle procedure
  if any? other rail-passengers-here
    [ fd 1
      separate-rail-passengers ]
end

to add-rail-robot
  ifelse (count rail-passengers >= world-width)
  [ user-message "You have reached the max number of rail-passengers"]
  [ create-rail-passengers 1 [
     set xcor (min-pxcor)
     set ycor rails-row
     set heading 90
     ;; We don't really care about these variables
     set speed 0
     set speed-limit  1
     set speed-min  0
     separate-rail-passengers
   ]
   ]
end
to plot-rail-passengers
  if ticks mod plot-frequency = 0 and any? rail-passengers
  [ set-current-plot "Commuter Speed"
    set-current-plot-pen "Train Speed"
    plot train-speed
    set-current-plot "Commuters"
    set-current-plot-pen "Rail Passengers"
    plot count rail-passengers
    set-current-plot "Money collected"
    set-current-plot-pen "Train"
    plot rail-money-collected
   ]
end
; ------------------------------------------------------
; Get rid of a robot driver
; ------------------------------------------------------
to remove-one-car-robot
  let car-robots 0
  set car-robots drivers with [user-id = 0]
  if (any? car-robots)
    [ ask one-of car-robots [ die ] ]
end
to remove-one-rail-robot
  let rail-robots 0
  set rail-robots rail-passengers with [user-id = 0]
  if (any? rail-robots)
    [ ask one-of rail-robots [ die ] ]
end
; ------------------------------------------------------
; Allow people to switch
; ------------------------------------------------------
to driver-becomes-rail-passenger [target-user-id]
     let old-shape 0
     ask drivers
     [ if user-id = target-user-id
      [ set old-shape shape
        set breed rail-passengers
        set shape old-shape
        set ycor rails-row
        set heading 90
        separate-rail-passengers
       ]
     ]
end
to car-robot-to-rail-robot
  let car-robots 0
  let old-shape 0

  set car-robots drivers with [user-id = 0]
  ; Choose a random driver
  if (any? car-robots)
    [ ask one-of car-robots
     [
       set old-shape shape
       set breed rail-passengers
       set shape old-shape
       set ycor rails-row
       set heading 90
       separate-rail-passengers
     ]
    ]
end
to rail-passenger-becomes-driver [target-user-id]
    ask rail-passengers
      [ if user-id = target-user-id [ driver-to-onramp ] ]
end
to rail-robot-to-car-robot
  let rail-robots 0
  set rail-robots rail-passengers with [user-id = 0]
  ; Choose a random rail-robot
  if (any? rail-robots)
    [ ask one-of rail-robots
     [ driver-to-onramp]
    ]
end
@#$#@#$#@
GRAPHICS-WINDOW
384
10
999
228
27
8
11.0
1
10
1
1
1
0
1
1
1
-27
27
-8
8
1
0
CC-WINDOW
5
616
1013
711
Command Center
0
BUTTON
205
10
291
51
Re-Run
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
BUTTON
296
10
380
50
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
SLIDER
287
252
460
285
initial-car-robots
initial-car-robots
0
41
14
1
1
NIL
HORIZONTAL
PLOT
4
262
251
440
Commuter Speed
time
speed
0.0
100.0
0.0
12.0
true
false
PENS
"Max Driver Speed" 1.0 0 -10899396 true
"Average Driver Speed" 1.0 0 -8630108 true
"Train Speed" 1.0 0 -2674135 true
SLIDER
668
251
841
284
initial-rail-robots
initial-rail-robots
0
100
22
1
1
NIL
HORIZONTAL
BUTTON
464
238
624
271
Add car robot
add-car-robot
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
SLIDER
254
167
380
200
train-speed
train-speed
0
20
1
1
1
NIL
HORIZONTAL
BUTTON
845
238
1004
271
Add rail robot
add-rail-robot
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
BUTTON
464
276
625
309
Remove car robot
remove-one-car-robot
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
BUTTON
845
274
1004
307
Remove rail robot
remove-one-rail-robot
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
PLOT
3
78
251
258
Commuters
time
number
0.0
100.0
0.0
90.0
true
false
PENS
"Drivers" 1.0 2 -8630108 true
"Rail passengers" 1.0 2 -2674135 true
"Bankruptcies" 1.0 0 -16777216 true
SLIDER
4
569
173
602
plot-frequency
plot-frequency
1
50
10
1
1
tick(s)
HORIZONTAL
SLIDER
811
366
936
399
driver-cost
driver-cost
0
100
10
1
1
$
HORIZONTAL
SLIDER
671
366
797
399
train-cost
train-cost
0
100
20
1
1
$
HORIZONTAL
SLIDER
586
462
783
495
initial-money-mean
initial-money-mean
0
100
100
1
1
$
HORIZONTAL
SLIDER
585
568
782
601
individual-salary-mean
individual-salary-mean
0
100
100
1
1
$
HORIZONTAL
PLOT
786
424
991
601
Wealth distribution
Money
People
0.0
750.0
0.0
2.0
true
false
PENS
"default" 20.0 1 -16777216 true
PLOT
3
444
251
564
Money collected
time
money
0.0
100.0
0.0
100.0
true
false
PENS
"Train" 1.0 0 -2674135 true
"Cars" 1.0 0 -8630108 true
BUTTON
114
10
198
51
Setup
ca
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
SLIDER
585
425
782
458
initial-money-sd
initial-money-sd
0
100
0
1
1
$
HORIZONTAL
SLIDER
585
530
784
563
individual-salary-sd
individual-salary-sd
0
100
0
1
1
$
HORIZONTAL
@#$#@#$#@
VERSION
-------
$Id: Transportation.nlogo 37529 2008-01-03 20:38:02Z craig $

WHAT IS IT?
-----------
This is a model for Computer HubNet, which simulates traffic and the public policy decisions (and the ramifications of those decisions) that can result from trying to regulate that traffic.
Each participant is a citizen in a small city with one single-lane highway
(taken from the "traffic basic" model) and a train.   The train runs at constant speed, set with the TRAIN-SPEED slider.  The cars travel as quickly as they can, but will slow down to avoid collisions with cars in front of them.  As more cars get onto the highway, the traffic jams become increasingly large and frustrating.
City residents can try to remedy the situation by charging different amounts of money for drivers and rail passengers.  How much must they charge in order to reduce traffic to a normal flow, such that driving is faster than taking the train?  When this happens, will the city earn more revenue from the train, or from the cars?  And how will all of this affect the city's residents, who may not be able to afford driving or the train?

HOW TO USE IT
-------------
When the model loads, it will ask you to enter the name by which the model will be known on the network.  Enter your name (as it suggests), or perhaps something more descriptive, such as "transportation."  Once you have done this, click on the "setup" button.  Each participant should then run the "HubNet client" program on their own computer, connecting to the server that you named.
Warning: Clicking on "setup" removes the participants from the system, and forces them to re-connect.

THINGS TO NOTICE
----------------
- What is the capacity of the road vs. the train?
- What is the correlation (if any) between the city's income and traffic on the roads?
- Is the city's interest always the same as the individual's interest?  Where are they the same?  Where are they different?  How do the citizens react when faced with such dilemmas?
THINGS TO TRY
--------------
- Does the city make more money from cars, or from the train?  What settings for car and rail fare will maximize the city's income?
- Make the robots switch modes of transportation based on an algorithm

EXTENDING THE MODEL
------------
- Add a "welfare" option; when someone cannot afford to take the train or drive, they should receive a subsidy from the collected taxes.
- The current model assigns a salary to each individual.  But there's no way for people's salaries to rise or fall.  Allow individuals to invest some of their money for a potential payoff.  Perhaps there could be two kinds of investments, education (where you spend a lot over a long time, and see an increase in your salary) and stocks (where you invest any amount of money over any amount of time, and see a random return in your holdings, but not your salary.
- Add a second highway with a separate (and different) cost.  How does this affect traffic?  How does this affect the city's income?
- Make the robots intelligent, allowing them to move between driving and the train (like people do).  What rules should the robots follow?  When should they take the train?  When should they drive?

NETLOGO FEATURES
-----------------
Lots of Computer HubNet stuff
RELATED MODELS
---------------
"Traffic basic" (which comes with NetLogo)
CREDITS AND REFERENCES
-----------------------
??? What should I put here ???
Thanks to the following people for help and support: Uri Wilensky, Matthew Berland, Josh Unterman, Sharona Halevy, Dor Abrahamson.  (The order of the preceding list of names has nothing whatsoever to do with

TO DO
-----
- Don't use maps as an example in the curriculum
- Make the train stops (and wait-per-stop) adjustable
- Add a more useful info tab
- Can we reduce the information load further?
- Different background color for bankruptcies?
- ptext and ptextcolor for labeling the highway and railway?
- Ask kids to interview their parents about why they travel in a
  certain way
- Reduce the information load on the graphs
- Stack the graphs vertically, so that they line up
- Make the clear/setup buttons closer to the HubNet standard, with a
  warning if you try to setup with people attached.
- Background colors for the road
- Make train-speed an integer in the slider
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250
airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15
arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150
box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75
bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30
butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60
car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58
circle
false
0
Circle -7500403 true true 0 0 300
circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123
face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240
face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225
face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183
fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30
flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45
flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240
house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120
leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195
line
true
0
Line -7500403 true 150 0 150 300
pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120
person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90
square
false
0
Rectangle -7500403 true true 30 30 270 270
square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240
star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108
target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60
tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152
triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255
triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224
truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42
turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99
wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269
x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 4.0pre8
@#$#@#$#@
setup
repeat 150 [ drive ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
VIEW
384
10
989
197
27
8
11.0
1
10
1
1
1
0
1
1
1
-27
27
-8
8
CHOOSER
227
233
424
278
method-of-transportation
method-of-transportation
"Drive" "Take the train"
0
MONITOR
126
79
223
128
Cost to drive
NIL
0
1
MONITOR
127
142
221
191
Cost of train
NIL
0
1
MONITOR
659
233
755
282
Your savings
NIL
0
1
MONITOR
760
233
847
282
Your salary
NIL
0
1
MONITOR
433
232
648
281
You are a
NIL
0
1
@#$#@#$#@
