globals
[
  interstation-d ; distance between stations (now equal)
  ideal-intertrain-d ; distance between equidistant trains
  interlight-d ; distance between lights (now equal)

  ;; patch agentsets
  stations
  lights
  tracks
  platforms
  exits
  entrances
  buffers
  station-to-monitor
  
  distances ; inter-vehicle distances
  capacities ; capacities of vehicles (%)
  data-travel-trains
  data-travel-passengers
  data-wait-trains
  data-wait-passengers
  stddevs-frequencies
  stddevs-distances
  stddevs-capacities
  
  avg-range ;; range (time steps) for averages
  passenger-avgs ;; vector for keeping averages in range
  data-passengers
  data-entrances
  data-trains
  data-exits
]

patches-own
[
  station?
  light?
  go?
  track?
  platform?
  exit?
  entrance?
  buffer?
  frequencies
  last-train
  time-since-last-train
  ticks-until-next-passenger
  antipheromone
  antipheromone2
  lambda
]

breed [trains train]
breed [passengers passenger]

trains-own
[
  speed
  acceleration
  travel-time
  delay
  station-delay ; delay at station
  distance-travelled
  #passengers
  at-station?
  descending?
  distance-to-train-ahead  
]

passengers-own
[
  travel-time
  delay
  delayst
  delaytr
  delayex
  stations-per-trip ;total number of stations travelled
  stations-to-destination ; remaining stations to travel before exiting
  in-train?
  last-station
]


to setup
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks
  
  ;globals
  set interstation-d world-width / #stations
  set ideal-intertrain-d world-width / #trains
  if #lights > 0[
    set interlight-d world-width / #lights
  ]
  set avg-range 100
  
  ;patches
  ask patches[
    set station? false
    set light? false
    set go? true
    set track? false
    set platform? false
    set exit? false
    set entrance? false
    set buffer? false
    set frequencies []
    set last-train -1
    set time-since-last-train 0
    set ticks-until-next-passenger -1
    set antipheromone 0
    set antipheromone2 0
    set lambda -1
  ]  
  set tracks patches with 
    [pycor = 0]
  ask tracks[
    set pcolor gray - 2
    set track? true
  ] 
  if init-stations = "equidistant"[
    set stations tracks with
      [(floor((pxcor + max-pxcor + floor((interstation-d / 2) - 1)) mod interstation-d) = 0)]
  ]  
  if init-stations = "random"[
    set stations n-of #stations tracks with [pxcor mod 5 = 0 and pxcor < (max-pxcor - 5)]
  ]  
  ask stations [
    set pcolor gray + 1
    set station? true
    ask patch-at 0 1[
      set pcolor green + 4
      set platform? true
    ]
    ask patch-at 0 -1[
      set pcolor green + 4
      set platform? true
    ]
    if station-buffers?[
        ask patch-at 1 -1[
        set pcolor green
        set buffer? true
        set entrance? true
      ]
    ]
  ]
  set platforms patches with ; just below and above stations
    [platform? ]
  set entrances platforms with 
    [pycor = -1]

  if #lights > 0[
    if init-lights = "equidistant"[
      set lights tracks with
        [(floor((pxcor + max-pxcor + floor((interlight-d / 8) - 1)) mod interlight-d) = 0)]
    ]  
    if init-lights = "random"[
      set lights n-of #lights tracks with [pxcor mod 5 = 0 and pxcor < (max-pxcor - 5) and not station?]
    ]  
  
    ;;;check that lights are not stations
    if any? lights with [station?][
      beep
      print "A light cannot be a station, please adjust the parameters and setup again"
       
    ]
  
    ask lights[
      set pcolor yellow
      set light? true 
      ask patch-at 0 1[
        set pcolor green
      ]
    ]
  ]
    
  update-param

  set exits platforms with 
    [pycor = 1]
  ask exits[
    set exit? true
  ]
  if station-buffers?[
    set buffers patches with ; just east of entrances
    [buffer? ]
  ]
  set station-to-monitor one-of stations
  ask station-to-monitor[
    set pcolor sky
  ]

  ;turtles
  set-default-shape trains "train passenger car"  
  set-default-shape passengers "person"  

  init  
end ; setup

to init
  do-methods true
  
  ask turtles [die]
  create-trains #trains
  [
    setup-train
  ]
  
  init-lists
  
  do-stations

end

to update-param
  ask entrances[
    set entrance? true
    ifelse homo-pass?[
      set lambda mean-passenger-interval
    ][
      set lambda random-poisson mean-passenger-interval
    ]
    if lambda < 4[;bound
      set lambda 4
    ]
    ask patch-at -1 0[
      ;set plabel [lambda] of myself
    ]
  ]

end

to init-lists
  set distances []
  set capacities []
  set data-travel-trains []
  set data-travel-passengers []
  set data-wait-trains []
  set data-wait-passengers []
  set data-passengers []
  ask station-to-monitor[
    set frequencies []
    set last-train -1
    set time-since-last-train 0
  ]
  set stddevs-frequencies []
  set stddevs-distances []
  set stddevs-capacities []
  set passenger-avgs n-values avg-range [0]
  set data-entrances []
  set data-trains []
  set data-exits []

end

to setup-train
  set speed 0
  set acceleration 1
  set travel-time 0
  set delay 0
  set station-delay 0
  set #passengers 0
  set distance-travelled 0
  set at-station? false
  set descending? false
  set heading 90
  if init-trains = "equidistant"[
    move-to patch-at ((ideal-intertrain-d * who) - max-pxcor) 0
  ]
  if init-trains = "random"[
    move-to one-of tracks with [not any? trains-on self]
  ]
  if init-trains = "aggregated"[
    move-to patch-at ((who) - max-pxcor) 0
  ]
  set color orange + who * 20
  set size 2
end  

to setup-passenger
  set travel-time 0
  set delay 0
  set delayst 0
  set delaytr 0
  set delayex 0
  set stations-per-trip 1 + (random (#stations - 1));total number of stations travelled
  set stations-to-destination stations-per-trip; remaining stations to travel before exiting
  set heading 0
  set in-train? false
  set last-station xcor
  set label-color red 
end

to go
  tick
  
  do-stations
  if #lights > 0[
    do-lights
  ]
  ask trains[
    go-train
  ]
  ask passengers[
    go-passenger
  ]

  do-methods false

  do-lists
  if plots?[
    update-plot
  ]
end

to do-stations
  ifelse station-buffers?[
    ask buffers[
      new-passengers
    ]
  ][  
    ask entrances[
      new-passengers
    ]
  ]
end

to do-lights
  if ticks mod light-period / 2 = 0[
    change-lights 
  ]
end

to change-lights
  ask lights[
    ifelse go?[
      ask patch-at 0 1[
        set pcolor red
      ]
    ][
      ask patch-at 0 1[
        set pcolor green
      ]    
    ]
    set go? (not go?)
  ]
end
to new-passengers;; patch procedure
  ifelse ticks-until-next-passenger <= 1[
    if ticks-until-next-passenger = 1 or ticks-until-next-passenger = 0[
      sprout-passengers 1 [setup-passenger]
    ]
    set ticks-until-next-passenger random-poisson lambda
  ][
    set ticks-until-next-passenger (ticks-until-next-passenger - 1)
  ]
end

to go-train
  set travel-time travel-time + 1
  set label #passengers
  set-speed
  fd speed
  set distance-travelled distance-travelled + speed
  if speed < max-speed[
    set delay (delay + max-speed - speed)
  ]
  if distance-travelled >= world-width[
    set data-travel-trains sentence data-travel-trains travel-time
    set data-wait-trains sentence data-wait-trains delay
    set travel-time 0
    set distance-travelled 0
    set delay 0
  ]
end

to set-speed
  ifelse not go? [; red light
    set speed 0
  ][  
    let i 1
    let trains-ahead? false
    while [i <= min-intertrain-d][
      if any? trains-at i 0[
        set trains-ahead? true
      ]
      set i (i + 1)
    ]
    ifelse trains-ahead? 
    [
      ifelse not pass-allowed?[
        set speed 0
      ][
      
        ;ifelse station? at patch-ahead[
         ; set speed 0 
        ;][
          set speed max-speed
        ;]
      ]
    ][   
      ifelse station?[
        ifelse not at-station? [ ;; train arriving and stopping 
          set at-station? true
          set speed 0
          set station-delay 0
        ][
          set speed 0
          set station-delay station-delay + 1       
          ifelse any? passengers-here with [stations-to-destination <= 0] [
            set descending? true
            ask one-of passengers-here with [stations-to-destination <= 0][
              exit-train
            ]
            set #passengers #passengers - 1
          ]
          [
            set descending? false
            ifelse station-delay > max-station-wait-time [
                set speed max-speed
            ][          
              ifelse method = "self-org" [
                let time-train-behind find-distance-to-train-behind
  ;              let time-train-behind find-time-to-train-behind
                let margin (count passengers-at 0 -1)
                if margin > max-margin[
                  set margin max-margin
                ]
                ifelse antipheromone >= time-train-behind + margin[
                  set speed max-speed
                  set antipheromone 0 
                ][
                  ifelse (count passengers-at 0 -1) = 0[
                    if [antipheromone] of patch-at 1 0 >= time-train-behind [
                      set speed max-speed
                      set antipheromone 0 
                    ]
                  ][
                    board-passengers
                  ]
                ]
              ][  
                ifelse method = "self-org2" [
                  let time-train-behind find-distance-to-2nd-train-behind ;find-time-to-train-behind
                  let margin (count passengers-at 0 -1)
                  if margin > max-margin[
                    set margin max-margin
                  ]
                  ifelse antipheromone > antipheromone2[
                    ifelse antipheromone >= time-train-behind + margin[
                      set speed max-speed
                      set antipheromone 0 
                    ][
                      ifelse (count passengers-at 0 -1) = 0[
                        if [antipheromone] of patch-at 1 0 >= time-train-behind [
                          set speed max-speed
                          set antipheromone 0 
                        ]
                      ][
                        board-passengers
                      ]
                    ]
                  ][;antipheromone2 >= antipheromone
                    ifelse antipheromone2 >= time-train-behind + margin[
                      set speed max-speed
                      set antipheromone2 0 
                    ][
                      ifelse (count passengers-at 0 -1) = 0[
                        if [antipheromone2] of patch-at 1 0 >= time-train-behind [
                          set speed max-speed
                          set antipheromone2 0 
                        ]
                      ][
                        board-passengers
                      ]
                    ]
                  ]
                ][  
                  ifelse (count passengers-at 0 -1) = 0[
                    if station-delay > min-station-wait-time [
                      set speed max-speed
                    ]
                  ][
                    board-passengers
                  ]
                ]
              ]
            ]  
          ]
        ]
      ][
        set at-station? false
        set speed max-speed
      ]
    ]
  ]
end

to board-passengers
  ifelse #passengers >= train-capacity[
    if station-delay > min-station-wait-time [
      set speed max-speed
    ]
  ][
    if any? passengers-at 0 -1[
      ask one-of passengers-at 0 -1[; board train
        fd 1
        hide-turtle
        create-link-from one-of trains-here [ tie ]
        set in-train? true
      ]
      set #passengers #passengers + 1
    ]
  ]  
  
end


to go-passenger
  set travel-time travel-time + 1
  if exit? [
    set data-travel-passengers sentence data-travel-passengers travel-time
    set data-wait-passengers sentence data-wait-passengers delay
    set data-entrances sentence data-entrances delayst
    set data-trains sentence data-trains delaytr
    set data-exits sentence data-exits delayex
    die
  ]
  ifelse entrance?[
    set delay delay + 1
    set delayst delayst + 1
    set label count passengers-here
    if buffer?[
      ifelse (count passengers-at -1 0 < buffer-capacity); move to buffer if there's space 
      and (not any? trains-at -1 1)                     ; and there's no train in station 
      [                
        set pcolor green
        lt 90
        fd 1
        rt 90
      ][
        set pcolor red
      ]
    ]
  ][
    set label ""
  ]
  if in-train?[
    ifelse station?[
      ifelse last-station = pxcor [
        set delay delay + 1
        ifelse stations-to-destination = 0[
          set delayex delayex + 1
        ][
          set delaytr delaytr + 1
        ]
      ][
        set last-station pxcor
        set stations-to-destination stations-to-destination - 1
        ;ready to exit when stations-to-destination <= 0, see exit-train procedure
      ]
    ][
      ifelse any? trains-here[
        if ([speed] of one-of trains-here) < max-speed[
          set delay (delay + max-speed - ([speed] of one-of trains-here))
          set delaytr (delaytr + max-speed - ([speed] of one-of trains-here))
        ] 
      ][
        if ([speed] of one-of trains-on neighbors4) < max-speed[
          set delay (delay + max-speed - ([speed] of one-of trains-on neighbors4))
          set delaytr (delaytr + max-speed - ([speed] of one-of trains-on neighbors4))
        ] 
      ]
    ]
  ]
end

to exit-train
  ask my-in-links [ die ]
  show-turtle
  fd 1
end


to do-methods [init?]
  let adjustment 0
  if init? and (method = "min" or method = "max"or method = "min-max")[
    set min-station-wait-time 20
    set max-station-wait-time 20
  ]
  
  ifelse method = "default" or method = "self-org" or method = "self-org2"[
      set min-station-wait-time 0
      set max-station-wait-time 200
      ifelse method = "self-org"[
        do-self-org
      ][
      if method = "self-org2"[
        do-self-org2
      ]
      ]
  ][
    ifelse method = "min" [
        set max-station-wait-time 200
        do-min
    ][
      ifelse method = "max"[
        set min-station-wait-time 25
        do-max
      ][
        if method = "min-max"[
          do-min
          do-max
        ]
      ]
    ]
  ]

end

to do-self-org
  ask tracks[
    set antipheromone (antipheromone + 1)
    set pcolor green + 5 + (antipheromone / 10)
  ]
  ask trains[
    if speed > 0[
      set antipheromone 0 
    ]
  ]  
  if (any? passengers) and (ticks mod update-method = 0) [
    ifelse mean [(100 * #passengers / train-capacity)] of trains  >= 33[
      set max-margin max-margin + 1
    ][
      set max-margin max-margin - 1
    ]
    if max-margin > 25[
      set max-margin 25
    ]
    if max-margin < 0[
      set max-margin 0 
    ]
  ]

end

to do-self-org2
  ask tracks[
    set antipheromone (antipheromone + 1)
    set antipheromone2 (antipheromone2 + 1)
    ifelse antipheromone2 > antipheromone[
      set pcolor orange + 5 + (antipheromone2 / 20)
    ][
      set pcolor green + 5 + (antipheromone / 20)
    ]
  ]
  ask trains[
    if speed > 0[
      ifelse antipheromone2 > antipheromone[
        set antipheromone2 0
      ][ 
        set antipheromone 0 
      ]
    ]
  ]  
end


to do-min
        if (any? passengers) and (ticks mod update-method = 0) [
          if (mean passenger-avgs > train-capacity * #trains * 0.3)[
            set min-station-wait-time ( min-station-wait-time + 1)
          ]
          if (mean passenger-avgs < train-capacity * #trains * 0.015)[
            set min-station-wait-time ( min-station-wait-time - 1)
          ]
        ]
        if (min-station-wait-time < 10) [
          set min-station-wait-time 10
        ]
        if (min-station-wait-time > train-capacity) [
          set min-station-wait-time train-capacity
        ]
end

to do-max
        if (any? passengers) and (ticks mod update-method = 0) [
          if (mean passenger-avgs > train-capacity * #trains * 0.15)[
            set max-station-wait-time ( max-station-wait-time + 1)
          ]
          if (mean passenger-avgs < train-capacity * #trains * 0.03)[
            set max-station-wait-time ( max-station-wait-time - 1)
          ]
        ]
        if (max-station-wait-time < 8) [
          set max-station-wait-time 8
        ]
        if (max-station-wait-time > train-capacity) [
          set max-station-wait-time train-capacity
        ]
end

; stats and plotting functions


to do-lists
;  set data-travel-trains sentence data-travel-trains mean [travel-time] of trains
;  set data-wait-trains sentence data-wait-trains mean [delay] of trains
  
;  if any? passengers [
;    set data-wait-passengers sentence data-wait-passengers mean [delay] of passengers
;    set data-travel-passengers sentence data-travel-passengers mean [travel-time] of passengers
;    if any? (passengers-on exits)[
;      set data-entrances sentence data-entrances mean [delayst] of passengers
  ;    if any? (passengers-on trains) with [stations-to-destination > 0] [
  ;      set tra (mean [delay] of (passengers-on trains) with [stations-to-destination > 0]) - ent
  ;      set data-trains sentence data-trains tra
  ;      if any? (passengers-on trains) with [stations-to-destination = 0] [
  ;        set data-exits sentence data-exits ((mean [delay] of (passengers-on trains) with [stations-to-destination = 0]) - ent - tra)
  ;      ]
  ;    ]
;    ]
;  ]
  
  set passenger-avgs replace-item (ticks mod avg-range) passenger-avgs (count passengers-on entrances)
  set data-passengers sentence data-passengers (count passengers-on entrances)
  
  if (histogram-probe > 0)[
    ask station-to-monitor[; will work only if no passings are allowed
      ifelse any? trains-here[
        ifelse ([who] of one-of trains-here) != last-train[
          if last-train >= 0[
            set frequencies sentence frequencies time-since-last-train
          ]
          set last-train [who] of one-of trains-here
          set time-since-last-train 0
        ][
          set time-since-last-train (time-since-last-train + 1)
        ]
      ][
        set time-since-last-train (time-since-last-train + 1)
      ]
    ]
    
    set capacities sentence capacities [(100 * #passengers / train-capacity)] of trains 
  ]
  
  if (histogram-probe > 0) and (ticks mod histogram-probe = 0)[
    find-distances
    if length distances >= 2[
      set stddevs-distances sentence stddevs-distances standard-deviation distances
    ]
    if length [frequencies] of station-to-monitor >= 2[
      set stddevs-frequencies sentence stddevs-frequencies standard-deviation [frequencies] of station-to-monitor
    ]
    ;if count trains >= 2[
      set stddevs-capacities sentence stddevs-capacities standard-deviation capacities
    ;]
  ]
  
end
to find-distances
  ;set distances []; plot histogram only for current time step
  ask trains[
    find-distance-to-train-ahead
    set distances sentence distances distance-to-train-ahead
  ]
end

;;turtle procedure... checks distance to train ahead... torus-like... need to make non-torus version?
to find-distance-to-train-ahead
  let i 0 
  
  set i 1;;start measuring ahead...
  set distance-to-train-ahead -1 ;; initialize distances...
  while [i < (2 * max-pxcor)]
  [
    if ((count (trains-at i 0)) > 0)[
      set distance-to-train-ahead i
      set i (2 * max-pxcor)
    ]
  set i (i + 1)
  ]
end

to-report find-distance-to-train-behind
  let i 0
  set i 1
  while [i < (2 * max-pxcor)]
  [
    if ((count (trains-at (- i) 0)) > 0)[
      report i
      set i (2 * max-pxcor)
    ]
  set i (i + 1)
  ]
end


to-report find-distance-to-2nd-train-behind
  let i 0
  set i 1
  let first-pass false
  while [i < (2 * max-pxcor)]
  [
    if ((count (trains-at (- i) 0)) > 0)[
      ifelse first-pass[
        report i
        set i (2 * max-pxcor)
      ][
        set first-pass true
      ]
    ]
  set i (i + 1)
  ]
end


to-report find-time-to-train-behind
  let i 0
  
  set i 1;;start measuring behind...
  while [i < (2 * max-pxcor)]
  [
    if ((count (trains-at (- i) 0)) > 0)[
      ifelse i > 1[
        report [antipheromone] of patch-at (- i + 1) 0
      ][
        report [antipheromone] of patch-at (- i) 0
      ]
      set i (2 * max-pxcor)
    ]
  set i (i + 1)
  ]
end


to update-plot
  if data-travel-trains != [][
    set-current-plot "Trains"
    set-current-plot-pen "travel"
    plotxy ticks  mean data-travel-trains
    set-current-plot-pen "delay"
    plotxy ticks  mean data-wait-trains
  ]
  if data-travel-passengers != [][
    set-current-plot "Passengers"
    set-current-plot-pen "travel"
    plotxy ticks  mean data-travel-passengers
    set-current-plot-pen "delay"
    plotxy ticks  mean data-wait-passengers
    set-current-plot-pen "entrance wait" 
    plotxy ticks  mean data-entrances
    set-current-plot-pen "train wait" 
    plotxy ticks  mean data-trains
    set-current-plot-pen "exit wait" 
    plotxy ticks  mean data-exits
    set-current-plot-pen "travel"
    ;plotxy ticks  mean data-exits + mean data-trains + mean data-entrances
  ]
  
  set-current-plot "Passengers at Station Entrances"
  set-current-plot-pen "default"
  plotxy ticks mean passenger-avgs
  ;if length data-passengers > 0[
    set-current-plot-pen "avg"
    plotxy ticks  mean data-passengers
  ;]
  
  if (histogram-probe > 0) and (ticks mod histogram-probe = 0)[; plot histograms
    set-current-plot "Train Delays"
    set-current-plot-pen "default"
    histogram data-wait-trains
    set-current-plot "Passenger Delays"
    set-current-plot-pen "default"
    histogram data-wait-passengers
    set-current-plot "Intertrain Distances"
    set-current-plot-pen "default"
    histogram distances
    set-current-plot "Intertrain Frequencies"
    set-current-plot-pen "default"
    ask station-to-monitor [
      histogram frequencies
    ]
    if length distances >= 2[
      set-current-plot "Intertrain Distances Standard Deviation"
      set-current-plot-pen "default"
      plotxy ticks standard-deviation distances
      if length stddevs-distances > 0[
        set-current-plot-pen "avg"
        plotxy ticks  mean stddevs-distances
      ]
    ]
    ask station-to-monitor [
      if length frequencies >= 2[
        set-current-plot "Intertrain Frequencies Standard Deviation"
        set-current-plot-pen "default"
        plotxy ticks  standard-deviation frequencies
        if length stddevs-frequencies > 0[
          set-current-plot-pen "avg"
          plotxy ticks mean stddevs-frequencies
        ]
      ]
    ]
    set-current-plot "Train Capacities"
    set-current-plot-pen "default"
    histogram capacities
    set-current-plot "Train Capacities Standard Deviation"
    set-current-plot-pen "default"
    plotxy ticks standard-deviation capacities
    if length stddevs-capacities > 0[
      set-current-plot-pen "avg"
      plotxy ticks  mean stddevs-capacities
    ]
    
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
10
8
1794
82
60
1
14.6612
1
10
1
1
1
0
1
1
1
-60
60
-1
1
0
0
1
ticks
30.0

BUTTON
18
287
93
320
Setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
95
288
158
321
Go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

SLIDER
10
84
182
117
#trains
#trains
1
20
5
1
1
NIL
HORIZONTAL

SLIDER
13
129
185
162
#stations
#stations
1
20
5
1
1
NIL
HORIZONTAL

SLIDER
5
370
220
403
train-capacity
train-capacity
0
100
50
1
1
passengers
HORIZONTAL

SLIDER
10
250
194
283
mean-passenger-interval
mean-passenger-interval
2
50
8
1
1
NIL
HORIZONTAL

MONITOR
750
538
836
583
#passengers
count passengers
17
1
11

PLOT
313
84
630
234
Trains
timesteps
timesteps
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"travel" 1.0 0 -16777216 true "" ""
"delay" 1.0 0 -2674135 true "" ""

PLOT
631
84
948
234
Passengers
timesteps
timesteps
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"travel" 1.0 0 -16777216 true "" ""
"delay" 1.0 0 -2674135 true "" ""
"entrance wait" 1.0 0 -5825686 true "" ""
"train wait" 1.0 0 -14835848 true "" ""
"exit wait" 1.0 0 -955883 true "" ""

SLIDER
6
404
220
437
min-station-wait-time
min-station-wait-time
0
200
25
1
1
timesteps
HORIZONTAL

SLIDER
5
439
220
472
max-station-wait-time
max-station-wait-time
0
200
20
1
1
timesteps
HORIZONTAL

SWITCH
28
529
185
562
station-buffers?
station-buffers?
1
1
-1000

SLIDER
23
562
239
595
buffer-capacity
buffer-capacity
0
50
20
1
1
passengers
HORIZONTAL

CHOOSER
186
83
311
128
init-trains
init-trains
"equidistant" "random" "aggregated"
0

SLIDER
22
596
229
629
max-speed
max-speed
0
1
1
0.01
1
patches/timestep
HORIZONTAL

SLIDER
22
629
230
662
min-intertrain-d
min-intertrain-d
1
15
1
1
1
patches
HORIZONTAL

SWITCH
22
664
174
697
pass-allowed?
pass-allowed?
1
1
-1000

CHOOSER
186
129
311
174
init-stations
init-stations
"equidistant" "random"
0

PLOT
1268
84
1585
234
Intertrain Distances
distances (patches)
NIL
0.0
100.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

BUTTON
159
288
222
321
Step
go
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
986
543
1081
577
Reset lists
init-lists
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1087
542
1281
575
histogram-probe
histogram-probe
0
1000
25
1
1
timesteps
HORIZONTAL

PLOT
949
84
1267
234
Intertrain Frequencies
frequency (timesteps)
NIL
0.0
200.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
949
235
1267
385
Intertrain Frequencies Standard Deviation
timesteps
std dev
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""
"avg" 1.0 0 -13345367 true "" ""

PLOT
1268
235
1585
385
Intertrain Distances Standard Deviation
timesteps
std dev
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""
"avg" 1.0 0 -13345367 true "" ""

SWITCH
639
540
743
573
plots?
plots?
0
1
-1000

CHOOSER
8
323
100
368
method
method
"manual" "default" "min" "max" "min-max" "self-org" "self-org2"
1

MONITOR
840
538
979
583
avg.pass@entrances
mean passenger-avgs
2
1
11

SLIDER
22
699
235
732
update-method
update-method
1
100
100
1
1
timesteps
HORIZONTAL

PLOT
313
538
630
688
Train Capacities Standard Deviation
timesteps
std dev
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""
"avg" 1.0 0 -13345367 true "" ""

PLOT
313
387
630
537
Train Capacities
capacity (%)
NIL
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
631
387
947
537
Passengers at Station Entrances
timesteps
passengers
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""
"avg" 1.0 0 -13345367 false "" ""

SWITCH
104
331
220
364
homo-pass?
homo-pass?
0
1
-1000

BUTTON
220
329
304
362
UpdateParam
update-param
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
4
472
220
505
max-margin
max-margin
0
30
0
1
1
timesteps
HORIZONTAL

BUTTON
233
288
296
321
Init
init
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
313
235
630
385
Train Delays
NIL
NIL
0.0
300.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -2674135 true "" ""

PLOT
631
235
947
385
Passenger Delays
NIL
NIL
0.0
600.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -2674135 true "" ""

SLIDER
12
175
184
208
#lights
#lights
0
20
0
1
1
NIL
HORIZONTAL

CHOOSER
186
175
311
220
init-lights
init-lights
"equidistant" "random"
0

SLIDER
13
213
185
246
light-period
light-period
0
100
50
1
1
ticks
HORIZONTAL

@#$#@#$#@
## NOTES

5 trains, 5 stations, 50 passengers capacity, 0.2 inflow_p: if min-station-wait-time is <30, system collapses. If you increase it to 35, it goes on well... "idling" trains allow the system to remain in sync, so load is distributed evenly, otherwise they aggregate.

If you select a low max-station-wait-time, enough that you can serve the capacity, i.e. passengers don't accumulate, then you can reduce considerably (half) passenger waiting times (note: we use abstract times...)

For inflow 0.25, min=45 improves, max=20 really helps... (! no sense in min if max<min)

***Even if you force an anomalous sync, i.e. aggregated trains, this strategy almost recovers  equidistance. Can see it in terms of friction reduction... a train waiting too long decreases satisfaction of other trains, also of passengers...

Station buffers don't seem to help...

with slow train speed, timescales differ, but similar behavior, it just takes longer for trains to stick together, and simple control (minwait time at stations) can help there...

with min-intertrain-d: same effect as max-wait for low inflow, but for high inflow it delays everything... even more than without any modification. Forcing train spatial interdistance makes all trains go at the speed of the slowest. It seems that just keeping schedules helps keep temporal interdistances, by regulating train capacity 

problem is to adjust max-wait according to inflow (and capacity...). Need to balance friction between trains and passengers (wait times)...

Saturation point depends more on capacity than on method... this only affects delays...

Random station interdistance does not affect much performance...

*****self-org notes

trains alternate "leader" in groups (not quite platoons), i.e. maximum headway changes paris of vehicles.

self-org2 not better than self-org

traffic lights can regulate default method, depends on number of TL and crucially on period for different passenger densities

self-org can adapt to TL's

## WHAT IS IT?

This is an abstract simulation of a public transportation system. It has been used to explore the equal headway instability phenomenon (Gershenson and Pineda, 2009) and to test different methods to promote equal headways.

## HOW IT WORKS

Trains move along the cyclic tracks transporting passengers. They move unless there is a vehicle (or a red light) in front of them. At stations they stop until all passengers to descend exit. Passengers board vehicles unless the vehicles are full or another restriction forces vehicles to leave the stations.

## HOW TO USE IT

Press "Setup" to initialize the simulation with the parameters above the button.  
Press "Go" or "Step" to run the simulation.  
Press "Init" to reset the simulation with the same paramenters which were used in Setup.  
Parameters above these buttons have to be set before the simulation starts. Parameters below can be adjusted during a simulation run.

"#trains" indicates the number of vehicles in the simulation.  
Vehicles can be initialized with "init-trains" equidistant, with random positions, or aggregated.  
"#stations" indicates the number of stations in the simulation.  
Stations can be initialized with "init-stations" equidistant or with random positions  
"#lights" indicates the number of traffic lights in the simulation.  
Traffic lights can be initialized with "init-lights" equidistant or with random positions.  
"light-period" indicates the traffic lights cycle length.  
"mean-passenger-interval" indicates the average time (lambda of a Poisson distribution) between passenger arrivals at each station. If "homo-pass?" is true, this will be equal for all stations. Otherwise, each station will choose from a Poisson distribution with mean "mean-passenger-interval" their own lambda.  
Press "UpdateParam" to update the values of mean passenger intervals for stations, e.g. "homo-pass?" was changed or the intervals (shown at bottom left of stations) are not desired ones.

"method" selects the headway regulation method:
	manual allows user to use parameters below.
	default has no restrictions (always leads to unstable headways)
	min adaptively adjusts "min-station-wait-time" (Gershenson and Pineda, 2009)
	max adaptively adjusts "max-station-wait-time" (Gershenson and Pineda, 2009)
	min-max adaptively adjusts "min-station-wait-time" and "max-station-wait-time"
	self-org uses antipheromones to self-organize headways of neighboring trains
		(Gershenson, 2011).
	self-org2 uses antipheromones to self-organize headways of alternating trains
		(with one train in between).

"train-capacity" sets the maximum number of passengers that can fit in a vehicle.  
"min-station-wait-time" restricts departure of vehicles only after they have spent a minimum time at stations.  
"max-station-wait-time" forces deprture of vehicles (only if all exiting passengers descended) after a maximum time at stations.  
"max-margin" parameter for self-org method (Gershenson, 2011).

"station-buffers?" creates buffers at station entrances.  
Only a "buffer-capacity" number of passengers are allowed into the station entrance, the rest arrive to its right.  
"max-speed" regulates the maximum speed of vehicles.  
"min-intertrain-d" forces vehicles to stop when they are at this distance from a vehicle ahead.  
"pass-allowed?" lets vehicles to go on top of each other.  
"update-method" parameter for min, max, and min-max methods (Gershenson and Pineda, 2009).

"plots?" Switches data plotting.  
Press "Reset lists" to initialize data measuring and plotting.  
"histogram-probe" determines the update frequency of histograms.

## CREDITS AND REFERENCES

URL: http://turing.iimas.unam.mx/~cgg/NetLogo/4.1/metro.html 

Gershenson, C. and L. A. Pineda (2009). Why Does Public Transport Not Arrive on Time? The Pervasiveness of Equal Headway Instability. PLoS ONE 4(10): e7292  
Gershenson, C. (2011) Self-organization leads to supraoptimal performance in public transportation systems. Submitted. 
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

train passenger car
false
0
Polygon -7500403 true true 15 206 15 150 15 135 30 120 270 120 285 135 285 150 285 206 270 210 30 210
Circle -16777216 true false 240 195 30
Circle -16777216 true false 210 195 30
Circle -16777216 true false 60 195 30
Circle -16777216 true false 30 195 30
Rectangle -16777216 true false 30 140 268 165
Line -7500403 true 60 135 60 165
Line -7500403 true 60 135 60 165
Line -7500403 true 90 135 90 165
Line -7500403 true 120 135 120 165
Line -7500403 true 150 135 150 165
Line -7500403 true 180 135 180 165
Line -7500403 true 210 135 210 165
Line -7500403 true 240 135 240 165
Rectangle -16777216 true false 5 195 19 207
Rectangle -16777216 true false 281 195 295 207
Rectangle -13345367 true false 15 165 285 173
Rectangle -2674135 true false 15 180 285 188

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
NetLogo 5.0.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="min-wait" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count passengers &gt; 1000</exitCondition>
    <metric>count passengers</metric>
    <metric>ticks</metric>
    <metric>mean data-wait-trains</metric>
    <metric>mean data-wait-passengers</metric>
    <metric>mean stddevs-distances</metric>
    <metric>mean stddevs-frequencies</metric>
    <enumeratedValueSet variable="#stations">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#trains">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-stations">
      <value value="&quot;equidistant&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="buffer-capacity">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-trains">
      <value value="&quot;equidistant&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pass-allowed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="histogram-probe">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-intertrain-d">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="inflow-p" first="0.1" step="0.1" last="0.4"/>
    <steppedValueSet variable="min-station-wait-time" first="0" step="10" last="50"/>
    <enumeratedValueSet variable="max-station-wait-time">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="station-buffers?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="max-wait" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count passengers &gt; 1000</exitCondition>
    <metric>count passengers</metric>
    <metric>ticks</metric>
    <metric>mean data-wait-trains</metric>
    <metric>mean data-wait-passengers</metric>
    <metric>mean stddevs-distances</metric>
    <metric>mean stddevs-frequencies</metric>
    <enumeratedValueSet variable="#stations">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="#trains">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-stations">
      <value value="&quot;equidistant&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="buffer-capacity">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-speed">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-trains">
      <value value="&quot;equidistant&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pass-allowed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="histogram-probe">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-intertrain-d">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="inflow-p" first="0.1" step="0.1" last="0.4"/>
    <enumeratedValueSet variable="min-station-wait-time">
      <value value="200"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-station-wait-time" first="10" step="10" last="50"/>
    <enumeratedValueSet variable="station-buffers?">
      <value value="false"/>
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
