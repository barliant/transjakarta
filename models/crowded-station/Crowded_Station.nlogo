extensions [ls]

globals
[
  walls
  roads
  train
  stop-line
  stair-y-list
  stair-x
  stair-end-x
  train-x
  total-time
  total-wait-time
  total-number
  total-time-hour
  total-wait-time-hour
  total-number-hour
  neural-net-setted?
  escalator?
  elevator?
  ;escalator-speed
  ;elevator-speed
  ;real-data?
  real-flow-list
]

turtles-own
[
  entrance-path-found?
  train-path-found?
  dest-x
  dest-y
  speed
  wait-time
  on-train-time
  density-right ; density on the right side of it
  density-left  ; density on the left side of it
  density-ahead ; density in front of it
  ahead-left-bound  ; ycor of begining of left side area
  ahead-right-bound ; ycor of begining of right side area
]

patches-own
[
  dist-to-entrance
]

;;;;;;;;;;;;;;;;;;;;;
;; SETUP PROCEDURE ;;
;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  make-station
  make-train
  set total-time 0
  set total-wait-time 0
  set total-number 1
  set total-time-hour 0
  set total-wait-time-hour 0
  set total-number-hour 1
  ifelse way-to-platform = "escalators"
  [ escalators ]
  [ if way-to-platform = "elevators"
    [ elevators ]
  ]
  set real-flow-list (list 0 0 0 0 0.008 0.008 0.008 0.15 0.416 0.75 0.83 0.83 0.75 0.75 0.75 0.79 0.916 1 0.916 0.75 0.5 0.16 0 0)
  reset-ticks
end

;; setup with standard inputs (designed to simulate settings in reality)
to standard-setup
  clear-all

  ifelse way-to-platform = "stairs"
  [ set width 3 ]
  [ set width 2 ]
  set stair-spacing 16

  set height-of-floor 6
  set width-of-platform 9

  make-station
  make-train
  set total-time 0
  set total-wait-time 0
  set total-number 1
  set total-time-hour 0
  set total-wait-time-hour 0
  set total-number-hour 1

  ifelse way-to-platform = "escalators"
  [ escalators ]
  [ if way-to-platform = "elevators"
    [ elevators ]
  ]

  set turtle-base-speed 1
  set escalator-speed 2
  set elevator-speed 2

  set flow-rate 3
  set real-data? true
  ; 3 people per tick == 1
  set real-flow-list (list 0 0 0 0 0.008 0.008 0.008 0.15 0.416 0.75 0.83 0.83 0.75 0.75 0.75 0.79 0.916 1 0.916 0.75 0.5 0.16 0 0)

  set train-interval 20
  set train-stop-time 5

  reset-ticks
end

;; setup neural net model
to setup-neural-net
  if neural-net-setted? = 0 and neural-net-on? [
    ls:reset
    ls:load-headless-model "My Neural Net.nlogo"
    ls:ask ls:models [
      setup
      repeat 1000 [ train ]
    ]
    set neural-net-setted? true
  ]
end

;; create whole structure of the station
to make-station
  ;; walking area are white
  ask patches [
    set pcolor white
  ]

  let y stair-spacing / 2
  set stair-y-list []

  set stair-x -6
  set stair-end-x stair-x + height-of-floor

  ;; create walls
  ifelse width = 1
  [

    set walls patches with [
      pxcor >= stair-x and pxcor <= stair-end-x and pycor != y and pycor != (0 - y)
    ]
    set stair-y-list lput y stair-y-list
    set stair-y-list lput (0 - y) stair-y-list
  ]
  [
    ifelse width = 2
    [
      set walls patches with [
        pxcor >= stair-x and pxcor <= stair-end-x and pycor != y and pycor != (y + 1) and pycor != (0 - y) and pycor != (-1 - y)
      ]
      set stair-y-list lput y stair-y-list
      set stair-y-list lput (y + 1) stair-y-list
      set stair-y-list lput (0 - y) stair-y-list
      set stair-y-list lput (-1 - y) stair-y-list
    ]
    [
      set walls patches with [
        pxcor >= stair-x and pxcor <= stair-end-x and pycor != y and pycor != (y + 1) and pycor != (y + 2) and pycor != (0 - y) and pycor != (-1 - y) and pycor != (-2 - y)
      ]
      set stair-y-list lput y stair-y-list
      set stair-y-list lput (y + 1) stair-y-list
      set stair-y-list lput (y + 2) stair-y-list
      set stair-y-list lput (0 - y) stair-y-list
      set stair-y-list lput (-1 - y) stair-y-list
      set stair-y-list lput (-2 - y) stair-y-list
    ]
  ]

  ask walls [
    set pcolor black
    set dist-to-entrance 1000
  ]
end

;; create train/tracks
to make-train
  set train-x stair-end-x + width-of-platform
  set train patches with [
    pxcor = train-x
  ]

  ask train [ set pcolor red ]
  set stop-line train-x - 2
end

;; set stair equipment to escalator
to escalators
  set escalator? true
  set elevator? false
end

;; set stair equipment to elevator
to elevators
  set elevator? true
  set escalator? false
end

;;;;;;;;;;;;;;;;;;;;;;
;;;; GO PROCEDURE ;;;;
;;;;;;;;;;;;;;;;;;;;;;

to go
  setup-neural-net
  create-passenger
  train-arrival
  boarding
  find-platform
  down-stairs
  find-train
  moving
  count-time
  recolor
  tick
end

;; create passengers based on real data or user inputs
to create-passenger
  ifelse real-data? = true
  [
    let percentage item ((ticks / 400) mod 24) real-flow-list
    if random-float 1 < percentage [
      create-turtle
    ]
  ]
  [ create-turtle ]
end

;; create trutles at specific locations
to create-turtle
  crt flow-rate [
    setxy random-float (stair-x - min-pxcor - 2) - max-pxcor one-of (list min-pycor max-pycor)
    set shape "circle"
    set size 0.7
    set color red + 3
    set entrance-path-found? false
    set train-path-found? false
    set speed random-float 1 + turtle-base-speed
    if any? other turtles-here [
      ask other turtles-here [ die ]
    ]
  ]
end

;; change color of train patches to show its arrival
to train-arrival
  ifelse ticks mod train-interval >= 0 and ticks mod train-interval <= train-stop-time
  [ ask train [ set pcolor green ] ]
  [ ask train [ set pcolor red ] ]
end

;; turtle procedure
;; detect obstacles in front of it
;; find new path if it can't move forward
to avoid-walls
  if not can-move? speed or [pcolor] of patch-ahead speed = black [
    find-nearest-patch
  ]
  if patch-ahead speed != nobody [
    ifelse not any? other turtles-on patch-ahead speed
    [ fd speed ]
    [
      set wait-time wait-time + 1
      move-to-neighbor
    ]
  ]
end

;; turtle procedure
;; get on the train, report time and die
to boarding
  ask turtles with [ xcor >= stop-line ] [
    if [ pcolor ] of one-of train = green [
      set total-time total-time + on-train-time
      set total-wait-time total-wait-time + wait-time
      set total-number total-number + 1

      set total-time-hour total-time-hour + on-train-time
      set total-wait-time-hour total-wait-time-hour + wait-time
      set total-number-hour total-number-hour + 1
      die
    ]
  ]
end

;; set destination of turtles outside the wall to platform
to find-platform
  ask turtles with [ pxcor < stair-x] [
    set dest-x stair-x
    set dest-y nearest-stair
    set entrance-path-found? true
    set train-path-found? false
  ]
end

;; go down by using stair equipment
to down-stairs
  ifelse escalator? = true
  [ use-escalator ]
  [ ifelse elevator? = true
    [ use-elevator ]
    [ use-stair ]
  ]
end

;; set destination of turtles on platform the train
to find-train
  ifelse neural-net-on?
  [
    ask turtles with [ train-path-found? = false and pxcor >= stair-end-x ] [
      set dest-x train-x
      calculate-ahead-bound
      calculate-density
      set dest-y best-car
      set speed random-float 1 + 1
      set train-path-found? true
    ]
  ]
  [
    ask turtles with [ train-path-found? = false and pxcor >= stair-end-x ] [
      set dest-x train-x
      set dest-y random-float (2 * max-pycor) - max-pycor
      set speed random-float 1 + 1
      set train-path-found? true
    ]
  ]
end

;; turtle procedure
;; moving towards destination
to moving
  ask turtles with [ entrance-path-found? = true or train-path-found? = true ] [
    ifelse xcor >= stair-x and xcor < stair-end-x and escalator? = true
    [ facexy dest-x dest-y fd speed ]
    [ if xcor < stop-line [
        facexy dest-x dest-y
        avoid-walls
      ]
    ]
  ]
end

;; update measurements
to count-time
  ask turtles [
    set on-train-time on-train-time + 1
  ]
  if (ticks mod 400) = 0 [
    set total-time-hour 0
    set total-wait-time-hour 0
    set total-number-hour 1
  ]
  ;ask turtles with [ wait-time > 50 ] [ die ]
end

;; update turtles' color
to recolor
  ask turtles [
    set color scale-color red (25 - wait-time) -10 30
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;
;;; HELPER PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

;; walk on stairs
to use-stair
  ask turtles with [ pxcor >= stair-x and pxcor < stair-end-x ] [
    set dest-x stair-end-x
    set dest-y pycor
    set train-path-found? false
  ]
end

;; stand on escalator
to use-escalator
  ask turtles with [ pxcor >= stair-x and pxcor < stair-end-x ] [
    set dest-x stair-end-x
    set dest-y pycor
    set train-path-found? false
    set speed escalator-speed
  ]
end

;; use elevator
to use-elevator
  ask turtles with [ pxcor >= stair-x and pxcor < stair-end-x ] [
    set dest-x stair-end-x
    set dest-y pycor
    set train-path-found? false
    ifelse ticks mod ((stair-end-x - stair-x) / elevator-speed * 2) = 0
    [ set speed (stair-end-x - stair-x) + 1 ]
    [ set speed 0 ]
  ]
end

;; reporter procedure
;; report the car that a turtle is going to board
to-report best-car
  ls:let i1 round density-left
  ls:let i2 round density-ahead
  ls:let i3 round density-right
  ls:ask ls:models [
    set input-1 i1
    set input-2 i2
    set input-3 i3
    test
  ]
  let choice first [ output ] ls:of ls:models
  ifelse choice = 0
  [ report random (max-pycor - ahead-left-bound) + ahead-left-bound ]
  [
    ifelse choice = 1
    [ report random (ahead-right-bound - min-pycor) + min-pycor ]
    [ report random (ahead-left-bound - ahead-right-bound) + ahead-right-bound ]
  ]
end

;; turtle procedure
;; set the bound the area that in front of it
to calculate-ahead-bound
  set ahead-left-bound ycor + ahead-range
  set ahead-right-bound ycor - ahead-range
  if ahead-left-bound > max-pycor [
    set ahead-left-bound max-pycor
  ]
  if ahead-right-bound < min-pycor [
    set ahead-right-bound min-pycor
  ]
end

;; turtle procedure
;; calculate density distribution of turtles ahead it
to calculate-density
  ifelse ahead-left-bound = max-pycor
  [ set density-left 1000 ]
  [ set density-left count turtles with [ ycor > ahead-left-bound and xcor >= [xcor] of myself ] / (max-pycor - ahead-left-bound) ]

  ifelse ahead-right-bound = min-pycor
  [ set density-right 1000 ]
  [ set density-right count turtles with [ ycor < ahead-right-bound and xcor >= [xcor] of myself ] / (ahead-right-bound - min-pycor) ]

  set density-ahead count turtles with [ ycor >= ahead-right-bound and pycor <= ahead-left-bound and xcor >= [xcor] of myself ] / (ahead-left-bound - ahead-right-bound + 1)
end

;; reporter procedure
;; report the nearest stair for a turtle
to-report nearest-stair
  let min-dist 1000
  let y 0
  foreach stair-y-list [
    let cur-dist distancexy stair-x ?
    if cur-dist < min-dist [
      set min-dist cur-dist
      set y ?
    ]
  ]
  report y
end

;; turtle procedure
;; find new nearest path to destination
to find-nearest-patch
  ask neighbors with [ pcolor != black ] [
    set dist-to-entrance distancexy [ dest-x ] of myself [ dest-y ] of myself
  ]
  let nearest-neighbor one-of min-n-of 1 neighbors [ dist-to-entrance ]
  facexy [pxcor] of nearest-neighbor [pycor] of nearest-neighbor
end

;; turtle procedure
;; move to one of neighors ahead a turtle
to move-to-neighbor
  ; allow move back
  ;let valid-neighbor one-of neighbors with [ pcolor != black and not any? other turtles-here ]

  ; never move back
  let valid-neighbor one-of neighbors with [ pcolor != black and not any? other turtles-here and (([xcor] of myself - pxcor ) * (pxcor - [dest-x] of myself) < 0) ]
  if valid-neighbor != nobody [
    move-to valid-neighbor
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
227
12
534
340
16
16
9.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
29
245
202
278
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
29
321
202
354
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
565
157
672
202
ave on-train-time
total-time / total-number
17
1
11

MONITOR
675
157
765
202
ave wait-time
total-wait-time / total-number
17
1
11

SLIDER
29
62
201
95
stair-spacing
stair-spacing
2
24
16
2
1
NIL
HORIZONTAL

SLIDER
29
98
201
131
width
width
1
3
2
1
1
NIL
HORIZONTAL

SLIDER
29
360
201
393
flow-rate
flow-rate
1
5
3
1
1
NIL
HORIZONTAL

SLIDER
563
14
728
47
train-interval
train-interval
10
60
20
2
1
NIL
HORIZONTAL

SLIDER
563
48
728
81
train-stop-time
train-stop-time
1
10
5
1
1
NIL
HORIZONTAL

PLOT
564
206
764
356
time costs
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot total-time / total-number"
"pen-1" 1.0 0 -7500403 true "" "plot total-wait-time / total-number"

SLIDER
563
83
728
116
ahead-range
ahead-range
1
6
3
1
1
NIL
HORIZONTAL

SWITCH
564
118
728
151
neural-net-on?
neural-net-on?
0
1
-1000

CHOOSER
29
15
201
60
way-to-platform
way-to-platform
"stairs" "escalators" "elevators"
1

BUTTON
29
283
202
316
NIL
standard-setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
510
365
764
515
hourly waiting time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot total-wait-time-hour / total-number-hour"

PLOT
226
365
501
515
population(entrance,stairs,platform)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [xcor < stair-x]"
"pen-1" 1.0 0 -7500403 true "" "plot count turtles with [xcor >= stair-x and xcor < stair-end-x]"
"pen-2" 1.0 0 -2674135 true "" "plot count turtles with [xcor >= stair-end-x]"

SLIDER
29
406
201
439
turtle-base-speed
turtle-base-speed
0
2
1
1
1
NIL
HORIZONTAL

SLIDER
29
444
201
477
escalator-speed
escalator-speed
0
3
2
1
1
NIL
HORIZONTAL

SLIDER
29
481
201
514
elevator-speed
elevator-speed
0
3
2
1
1
NIL
HORIZONTAL

SLIDER
29
134
201
167
height-of-floor
height-of-floor
1
10
6
1
1
NIL
HORIZONTAL

SLIDER
29
170
201
203
width-of-platform
width-of-platform
1
12
9
1
1
NIL
HORIZONTAL

SWITCH
29
207
201
240
real-data?
real-data?
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

This model simulates people flow in a subway station, specifically from ticket gate to the metro, including elevator, escalator or stairs and platform area. Each passenger starts at the ticket gate with a certain speed and finds the nearest way to the metro.

A subway station contains walking area and walls. Passengers can only walk through walking areas and will not run into walls or other passengers. When a passenger can not move forward along the path it chosen, whether because of the walls or other passengers in front of it, it will try to find another nearest path without moving back. If there is no other path that it could find, it will stay where it was and wait until it can move forward again.

 After a passenger has found the metro, it may wait outside until a metro’s arrival or get on the metro if one has arrived. This model doesn’t consider the passengers getting off from the metro and assume metro has enough room for boarding passengers. Once a passenger has got on the metro, it disappears from the model and reports the time it spent from the ticket gate to the metro, as well as the wait time, total time when it stayed on the same spot.

Passengers continually appears outside the ticket gate and do the same activity.

## HOW IT WORKS

At each tick, create a certain number passengers at random spots on the top or bottom outside the wall. Each passenger first locates itself. If it is at entrance area (outside the wall), it will find the nearest stair it can get and set the destination to this stair. If it is on stairs/escalator/elevator, it will set the destination to the end of the stairs facility. If it is on the platform, it will set the destination to a random car of the metro. If it has reached the destination (outside the metro), it will check whether the metro is here or not. If the metro is here, it will get on the metro (die) and report the wait time and whole travel time. If the metro has not arrived yet, it will stay and wait.

Then a passenger that has not reached the destination, detect whether there are obstacles (wall or other passengers) on its way to the destination. If no obstacles, it will move forward based on its speed. If there is any obstacle, it will find other nearest path starting from its neighbour patches without going back. If it found a nearest path, it will move to the neighbour that on the way to destination. If there is no path it could get to the destination from any of its neighbours, it will stay on the current patch and wait.

At each tick, patches representing train/tracks calculates the time to decide whether the metro should arrive or not. If metro should arrive, they will change their color to green showing passengers that they could board now. If not, they will set their color red.


## HOW TO USE IT

way-to-platform: one of three ways to get to platform (stairs, escalator and elevator)
stair-spacing: the distance between two stair equipments
width: width of stairs (number of turtles can get though at the same time) / capacity of escalator to elevator
flow-rate: number of passengers arriving at this station
train-interval: how long will the next metro arrive after the last one’s leaving
train-stop-time: how long will the metro stay at this station
turtle-base-speed: speed of the slowest turtle
escalator-speed: speed of escalator
elevator-speed: speed of elevator
ahead-range: a neural network parameter. Specify the area that in front of a passenger
neural-net-on?: passengers find cars randomly or based on the neural net


## RELATED MODELS

My Neural Net.nlogo
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

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

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

line half
true
0
Line -7500403 true 150 0 150 150

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 6.0-M5
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="locations" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="30000"/>
    <metric>total-wait-time / total-number</metric>
    <enumeratedValueSet variable="width">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="elevator-speed">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="width-of-platform">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neural-net-on?">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="stair-spacing" first="2" step="2" last="24"/>
    <enumeratedValueSet variable="ahead-range">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="height-of-floor">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-base-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flow-rate">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-stop-time">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-interval">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="real-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="way-to-platform">
      <value value="&quot;escalators&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="escalator-speed">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="platform" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="30000"/>
    <metric>total-wait-time / total-number</metric>
    <enumeratedValueSet variable="width">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="elevator-speed">
      <value value="2"/>
    </enumeratedValueSet>
    <steppedValueSet variable="width-of-platform" first="1" step="1" last="12"/>
    <enumeratedValueSet variable="neural-net-on?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stair-spacing">
      <value value="16"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ahead-range">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="height-of-floor">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-base-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flow-rate">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-stop-time">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-interval">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="real-data?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="way-to-platform">
      <value value="&quot;escalators&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="escalator-speed">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
