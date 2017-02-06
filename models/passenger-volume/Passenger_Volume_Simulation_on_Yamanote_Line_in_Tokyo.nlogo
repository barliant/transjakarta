;;declare global variables
globals 
[
  total-length-of-tracks 
  number-of-trains 
  move-counter 
  move-counter2 
  station-volume-list 
  passengers-per-minute-list 
  total-wait-time
  emergency-on
]
;;declare breeds
breed [trains train]
breed [stations station]
breed [innerstations innerstation]
breed [passengers passenger]
stations-own
[
  station-number
  outer-loop-capacity
  how-many-expand
]
innerstations-own
[
  station-number
  inner-loop-capacity
]
passengers-own
[
  destination
  heading-direction
  boarded
  wait-time
  just-generated
]
trains-own
[
  capacity
  max-capacity
  destination-station
  have-stopped
  running-direction
  target-station
]

;setup the system
to setup
  clear-all
  ask patches 
  [
    set pcolor white
  ]
  setup-innerstations
  setup-stations
  setup-passengers
  setup-trains
  reset-ticks
end

to setup-basics
  ;;total-length-of-tracks
  set total-length-of-tracks 0
  ask links
  [
    set total-length-of-tracks total-length-of-tracks + link-length
  ]
  set total-length-of-tracks total-length-of-tracks / 2
  ;;number-of-trains
  set number-of-trains time-each-loop / interval
  ;;read input about passenger volume at each station
  set station-volume-list read-from-string station-volume 
  ;;read input about passengers per minute
  set passengers-per-minute-list read-from-string passengers-per-minute
  ;;initialize total waiting time to 0
  set total-wait-time 0
end

to setup-stations
  ask innerstations [
    hatch 1 [
      set breed stations
    ]
  ]
  ask stations
  [
    create-links-from stations with [station-number = [station-number + 1] of myself mod count stations]
    set shape "circle"
    set color blue
  ]
  setup-basics
end

to setup-innerstations
  let station-number-temp 0
  create-ordered-innerstations number-of-stations
  [
    set station-number station-number-temp
    fd 12
    set station-number-temp station-number-temp + 1
  ]
  ask innerstations
  [
    create-links-to innerstations with [station-number = [station-number + 1] of myself mod count innerstations]
    set shape "circle"
    set color blue
  ]
  layout-circle sort-on [station-number] innerstations 12
end

to setup-passengers
  generate-passengers 1
end

to generate-passengers [case]
  ask stations
  [
    ;;case 1: generate passengers initially. 
    ;;case 2: generate passengers while the model is running
    ifelse case = 1
    [
      hatcher-passenger (item station-number station-volume-list)
    ]
    [
      hatcher-passenger (random-poisson (item station-number passengers-per-minute-list))
    ]
    ;;update outer_loop capacity/inner_loop capacity
    let outer-temp 0
    let inner-temp 0
    ask passengers-here
    [
      ifelse heading-direction = 2
      [
        set outer-temp outer-temp + 1
      ]
      [
        set inner-temp inner-temp + 1
      ]
    ]
    set outer-loop-capacity outer-temp
    ask one-of innerstations-here
    [set inner-loop-capacity inner-temp]
  ]
end

to hatcher-passenger [number]
    hatch-passengers number
    [
      set boarded 0
      set wait-time 0
      set just-generated 1
      ;;assign each passenger a random station
      set destination ((random (number-of-stations - 1)) + 1)
      if destination <= [station-number] of myself
      [
        set destination destination - 1
      ]
      ;;determine the heading direction of each passenger
      let station-number-new 0
      ifelse ([station-number] of myself - destination) < 0 
      [ set station-number-new ([station-number] of myself) + number-of-stations ]
      [ set station-number-new [station-number] of myself ]
      ifelse (station-number-new - destination < number-of-stations / 2) 
      [ set heading-direction 2 ] ;;counterclockwise or outer
      [ set heading-direction 1 ] ;;clockwise or inner 
    ]
end

to setup-trains
  ;;generate all of the trains at one station first
  ask stations with [station-number = 0]
  [
    hatch-trains number-of-trains
    [ 
      set capacity 0
      set max-capacity max-capacity-of-train
      set destination-station (list 0)
      let list-size number-of-stations - 1
      while [list-size != 0]
      [
        set destination-station sentence destination-station 0
        set list-size list-size - 1
      ]
      set running-direction 2
      set target-station number-of-stations - 1
    ]
    ;;get the trains move according to intervals
    let sequence number-of-trains - 1
    ask trains with [running-direction = 2]
    [
       setup-trains-move (total-length-of-tracks / number-of-trains * sequence)
       set sequence sequence - 1
    ]     
  ]
  ;;generate inner stations
  ask innerstations with [station-number = 0]
  [
    hatch-trains number-of-trains
    [ 
      set capacity 0
      set max-capacity max-capacity-of-train
      set destination-station (list 0)
      let list-size number-of-stations - 1
      while [list-size != 0]
      [
        set destination-station sentence destination-station 0
        set list-size list-size - 1
      ]
      set running-direction 1
      set target-station 1
    ]
    ;;get the trains move according to intervals
    let sequence number-of-trains - 1
    ask trains with [running-direction = 1]
    [
       setup-trains-move-inner (total-length-of-tracks / number-of-trains * sequence)
       set sequence sequence - 1
    ]     
  ]
end


to setup-trains-move [steps]
  let steps-taken 0
  let station-now 0
  let link-ahead 0
  ask stations with [station-number = station-now]
  [
    set link-ahead out-link-to one-of out-link-neighbors
  ]
  set heading [link-heading] of link-ahead
  while [steps-taken <= steps]
  [
    fd 0.2 
    set steps-taken steps-taken + 1 / 5
    if one-of stations-here != nobody and [station-number] of one-of stations-here = target-station
    [
      set xcor [xcor] of one-of stations-here
      set ycor [ycor] of one-of stations-here
      set station-now (station-now + 1) mod number-of-stations
      ask one-of stations-here
      [
        set link-ahead out-link-to one-of out-link-neighbors
      ]
      set heading [link-heading] of link-ahead
      set target-station (target-station - 1)
      if target-station < 0
      [
        set target-station target-station + number-of-stations
      ]
    ]
  ]
  set shape "train"
end

to setup-trains-move-inner [steps]
  let steps-taken 0
  let station-now 0
  let station-already 0
  let link-ahead 0
  ask innerstations with [station-number = station-now]
  [
    set link-ahead out-link-to one-of out-link-neighbors
  ]
  set heading [link-heading] of link-ahead
  while [steps-taken <= steps]
  [
    fd 0.2
    set steps-taken steps-taken + 1 / 5
    if one-of innerstations-here != nobody and [station-number] of one-of stations-here = target-station
    [
      set xcor [xcor] of one-of innerstations-here
      set ycor [ycor] of one-of innerstations-here
      set station-now (station-now + 1) mod number-of-stations
      ask one-of innerstations-here
      [
        set link-ahead out-link-to one-of out-link-neighbors
      ]
      set heading [link-heading] of link-ahead
      set target-station (target-station + 1) mod number-of-stations
    ]
  ]
  set shape "train"
end

;;running codes
to go
  ;;move-counter: makes the train move every 100 ticks. 
  ;;move-counter2: makes the passengers be generated every 1000 ticks (1 physically minute)
  set move-counter move-counter + 1
  set move-counter2 move-counter2 + 1
  ;emergency
  ;;move only when there is no emergency
  if(move-counter = 100 and emergency-on = 0)
  [
    ask trains with [running-direction = 2]
    [
        move-train
    ]
    ask trains with [running-direction = 1]
    [
      move-train-inner
    ]
    set move-counter 0
  ]
  if emergency-on = 1
  [ set move-counter 0]
  if(move-counter2 = 1000)
  [
    ask passengers with [boarded = 0 and just-generated = 0]
    [
      set wait-time wait-time + 1
    ]
    set total-wait-time 0
    ask passengers
    [
      set total-wait-time total-wait-time + wait-time
    ]
    ask passengers with [just-generated = 1] [ set just-generated 0]
    generate-running-passengers
    if represent-station-volume-on = 1
    [represent-station-volume]
    set move-counter2 0
  ]
  tick
end

to move-train
  ifelse(one-of stations-here = nobody)
  [
    ;;have to move very small steps, so /10 is added
    fd total-length-of-tracks / time-each-loop / 10
  ]
  ;;if at a station
  [
  ifelse(one-of stations-here != nobody and target-station = [station-number] of one-of stations-here)
  [
    ;;if the train has stopped here. The train stops at a station for two sets of 100 ticks
    ifelse (have-stopped = 1)
    [
      set have-stopped 0
      ;;new direction once stopped at a station
      let link-ahead 0
      let station-here [station-number] of one-of stations-here
      ask one-of stations-here
      [
        set link-ahead out-link-to one-of out-link-neighbors
      ]
      set heading [link-heading] of link-ahead
      fd total-length-of-tracks / time-each-loop / 10
      set target-station target-station - 1
      if target-station < 0
      [
        set target-station target-station + number-of-stations
      ]
    ]
    ;;if the train just arrives and haven't stopped here
    [
      set xcor [xcor] of one-of stations-here
      set ycor [ycor] of one-of stations-here
      stop-at-station 2
      set have-stopped have-stopped + 1
    ]
  ]
  [ fd total-length-of-tracks / time-each-loop / 10 ]
  ]
end

to move-train-inner
  ifelse(one-of innerstations-here = nobody)
  [
    fd total-length-of-tracks / time-each-loop / 10
  ]
  [
  ifelse(one-of innerstations-here != nobody and target-station = [station-number] of one-of innerstations-here)
  [
    ifelse (have-stopped = 1)
    [
      set have-stopped 0
      ;;new direction once stopped at a station
      let link-ahead 0
      let station-here [station-number] of one-of innerstations-here
      ask one-of innerstations-here
      [
        set link-ahead out-link-to one-of out-link-neighbors
      ]
      set heading [link-heading] of link-ahead
      fd total-length-of-tracks / time-each-loop / 10
      set target-station (target-station + 1) mod number-of-stations
    ]
    [
      set xcor [xcor] of one-of innerstations-here
      set ycor [ycor] of one-of innerstations-here
      stop-at-station 1
      set have-stopped have-stopped + 1
    ]
  ] 
  [ fd total-length-of-tracks / time-each-loop / 10 ]
  ]
end

to stop-at-station [direction-arrival]
  let mylist destination-station
  let myCapacity capacity
  let disembarked2 0
  let disembarked 0
  let embarked2 0
  let embarked 0
  ;DISEMBARK
  ;get the station number
  let station-here 0
  ;;splits code based on whether it's outer loop or inner loop and update accordingly.
  ifelse direction-arrival = 2
  [
    set station-here [station-number] of one-of stations-here
    set disembarked2 item station-here destination-station
    set mylist replace-item (station-here) (mylist) (0)
    set myCapacity myCapacity - disembarked2
    ;embark
    set embarked2 0
    ask passengers-here with [boarded = 0 and heading-direction = 2]
    [ 
      if (myCapacity < [max-capacity] of myself)
      [
        let i destination
        set mylist replace-item (destination) (mylist) ((item i mylist) + 1)
        set myCapacity myCapacity + 1
        set embarked2 embarked2 + 1
        set boarded 1
        set wait-time 0
        die
      ]
    ]
  ]
  ;; inner loop
  [
    set station-here [station-number] of one-of innerstations-here
    set disembarked item station-here destination-station
    set mylist replace-item (station-here) (mylist) (0)
    set myCapacity myCapacity - disembarked
    ;embark
    set embarked 0
    ask passengers-here with [boarded = 0 and heading-direction = 1]
    [ 
      if (myCapacity < [max-capacity] of myself)
      [
        let i destination
        set mylist replace-item (destination) (mylist) ((item i mylist) + 1)
        set myCapacity myCapacity + 1
        set embarked embarked + 1
        set boarded 1
        set wait-time 0
        die
      ]
    ]
  ]
  ;update train
  set capacity myCapacity
  set destination-station mylist 
  ;update station
  ifelse direction-arrival = 2
  [
    ask one-of stations-here
    [
      set outer-loop-capacity outer-loop-capacity + disembarked2 - embarked2
    ]
  ]
  [
    ask one-of innerstations-here
    [
      set inner-loop-capacity inner-loop-capacity + disembarked - embarked
    ]
  ]
end

to generate-running-passengers
  generate-passengers 2
end

;;the station turtles grow in size once the number of people grow here
to represent-station-volume
  ask stations
  [
    set how-many-expand int (outer-loop-capacity / level)
    let how-many-expand-temp 0
    ask one-of innerstations with [station-number = [station-number] of myself]
    [
      set how-many-expand-temp how-many-expand-temp + int (inner-loop-capacity / level)
    ]
    set how-many-expand how-many-expand + how-many-expand-temp 
    if how-many-expand > 4
    [ set how-many-expand 4]
    set size how-many-expand + 1  
    set shape "circle"
  ]
end

;handles emergency button being pressed
to emergency
  ifelse emergency-on = 0
  [set emergency-on 1]
  [set emergency-on 0]
end
@#$#@#$#@
GRAPHICS-WINDOW
370
15
809
475
16
16
13.0
1
10
1
1
1
0
1
1
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
38
83
105
116
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

INPUTBOX
9
164
276
224
station-volume
[1000 100 100 100 100 100 400 100 100 100 100 400 100 100 100 100 100 400 100 100 100 100 100 100 100 100 100 100 100]
1
0
String

INPUTBOX
9
222
164
282
number-of-stations
29
1
0
Number

INPUTBOX
8
279
163
339
interval
3
1
0
Number

INPUTBOX
9
339
164
399
time-each-loop
60
1
0
Number

INPUTBOX
9
397
164
457
max-capacity-of-train
2600
1
0
Number

BUTTON
241
95
304
128
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

INPUTBOX
8
457
223
517
passengers-per-minute
[700 30 30 30 30 230 30 30 30 30 30 30 30 30 30 230 30 30 30 30 30 30 30 30 230 30 30 30 30]
1
0
String

PLOT
857
367
1057
517
station-0-passengers
time
passengers
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot [inner-loop-capacity] of one-of innerstations with [station-number = item 0 read-from-string chose-station-to-graph] + [outer-loop-capacity] of one-of stations with [station-number = item 0 read-from-string chose-station-to-graph]"
"pen-1" 1.0 0 -7500403 true "" "plot [inner-loop-capacity] of one-of innerstations with [station-number = item 0 read-from-string chose-station-to-graph]"
"pen-2" 1.0 0 -2674135 true "" "plot [outer-loop-capacity] of one-of stations with [station-number = item 0 read-from-string chose-station-to-graph]"

INPUTBOX
23
588
178
648
level
1000
1
0
Number

INPUTBOX
856
306
1153
366
chose-station-to-graph
[0 1]
1
0
String

BUTTON
9
517
113
550
NIL
emergency
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SWITCH
23
646
267
679
represent-station-volume-on
represent-station-volume-on
0
1
-1000

PLOT
1066
368
1266
518
Average Waiting Time
Time
Waiting time
0.0
5.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "ifelse count passengers = 0\n[plot 0]\n[\nlet atxcor 0\nlet atycor 0\nask stations with [station-number = 1][set atxcor xcor set atycor ycor]\nlet waitingat 0\nlet atnumber 0\nask passengers with [xcor = atxcor and ycor = atycor] [set waitingat waitingat + wait-time\nset atnumber atnumber + 1]\nplot waitingat / atnumber\n]"

PLOT
857
518
1057
668
station-1-passengers
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
"default" 1.0 0 -16777216 true "" "plot [inner-loop-capacity] of one-of innerstations with [station-number = item 1 read-from-string chose-station-to-graph] + [outer-loop-capacity] of one-of stations with [station-number = item 1 read-from-string chose-station-to-graph]"
"pen-1" 1.0 0 -7500403 true "" "plot [inner-loop-capacity] of one-of innerstations with [station-number = item 1 read-from-string chose-station-to-graph]"
"pen-2" 1.0 0 -2674135 true "" "plot [outer-loop-capacity] of one-of stations with [station-number = item 0 read-from-string chose-station-to-graph]"

@#$#@#$#@
## WHAT IS IT?

This model provides an intuitive approach to simulate passenger flow on Yamanote Line, the busiest commute line in the world. Users are able to customize the model by setting their own parameters and see how the railway system responds. 

## HOW IT WORKS

The model is very intuitive to use. In the model, there are trains, passengers and stations. Initially, trains are distributed uniformly along the track based on user's input. Passengers are generated at each station at user-defined values for each individual station. Stations form a circular and keep an equal distance between each other. 
At each tick, passengers are generated at each station according to user's input. Trains move along the track, stop at each station to pick up passengers and letting off passengers. If the train reaches its maximum capacity predefined by the user, it no longer picks up passengers. Stations are stationary. 

## HOW TO USE IT
The following parameters are set before running the model:
• STATION-VOLUME: Initial number of passengers at each station: user could input a list of numbers into a textbox. The size of the list should equal the number of stations so that each item in the list corresponds to the initial number of passengers at each station
• NUMBER-OF-STATIONS: Number of stations: Yamanote Line serves 29 stations in total. But the user working with other circular railway systems could input different values. 
• INTERVAL: Train intervals: user could set the time interval between two trains. When this number is set, trains are distributed uniformly along the line. As a result, the number of trains is also determined. 
• TIME-EACH-LOOP: Total time for each loop: A Yamanote Line train takes ~60 minutes to run a complete loop. The user could vary this value if working with another system or wanting to decrease the speed of train operations. 
• MAXIMUM-CAPACITY-OF-TRAIN: Maximum capacity of train: the maximum number of people a train could take
• PASSENGERS-PER-MINUTE: Passenger inflow rate per minute into each station: user could input a list of numbers. The size of the list should equal to the number of stations so that each number in the list corresponds to the passenger inflow rate of each station. The rate is generated using a Poisson distribution with the user input as its mean.
• REPRESENT-STATION-VOLUME-ON: by enabling this switch, each station would grow in size according its number of passengers. This helps the user to visualize the change in passenger in volume in each station
• LEVEL: User could choose the threshold at which the stations grow in size. For example, if level is set to 1000, stations at passenger volume 2000 is 2x bigger than the stations with number of passengers of 1000. 
 
The following parameters are set while the model is running
• EMERGENCY: Emergency Switch: when this button is pressed, all train movements stopped but passengers keep coming into stations. When the button is pressed again, trains start moving again. 

The following parameters are related to graphing
• CHOSE-STATION-TO-GRAPH: user could input a list consisted of two number. Each number represents the station that the user wishes to see plotted in the two graphs labelled "station-(0 or 1)-passengers". 


## THINGS TO NOTICE

The most important things to notice in this model are the graphs. Two of the graphs labeled "station-(0 or 1)-passengers" plot the passenger volume at two stations over time. The graph labeled "Average Waiting Time" gives the average waiting time of passengers who are still waiting for the train at each time instance. 

## THINGS TO TRY

Users should supply their own numbers to the initial settings of the system to make it function. Ideally, an user should have statistical results available for each station to yield the best result. 

## EXTENDING THE MODEL

The current model provides the basic framework for a railway system. It simply possesses the most fundamental characteristics of a circular railway line. Many customization and expansion are possible for future development of this model, at the need of the users. The following provides some possibilities, but it is up to the user to modify the model to their best need.
  In terms of result analysis:
• Total passenger passage over a particular section of the track
• The satisfaction level of each passengers based on the waiting time 
  In terms of model expansion:
• The distance between each station could be made customizable. Currently, it is    	assumed to be equally separated
• Additional lines and stations could be added arbitrarily by the user so that the model is expanded to cover much more complex railway systems. This expansion, however, is difficult
• Trains could be added arbitrarily to the existing system at designated location
• Addition of express trains that stop at certain stations. Planners might be interested if such service could improve the efficiency of the overall system. 
• Better way of generating passengers’ destination: the method with which the destinations of the passengers are generated could be more flexible. Currently, it is a uniform distribution where each passenger randomly chooses a station as destination. Ideally, the model could take user-defined statistical numbers for the generation process. 
• Modeling of Stations: stations could be modeled more individually as residential / business, etc so that passengers generated at each station assume more individuality
• Modeling of different scenarios: the model could have several built-in scenarios such as morning rush hour, evening rush hour and major event near a particular station. Planners might be more interested in seeing how the system responds in these particular cases. 


## NETLOGO FEATURES

The current model only supports the most basic features of NetLogo

## RELATED MODELS

Not available.

## CREDITS AND REFERENCES

This model along with the report could be found on the Modelling Commons of NetLogo. 
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

train
true
1
Rectangle -13840069 true false 150 -45 270 255
Rectangle -2064490 false false 195 60 240 105
Rectangle -2064490 false false 195 120 240 165
Rectangle -2064490 false false 150 15 255 45
Rectangle -2064490 false false 195 180 240 225

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
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
