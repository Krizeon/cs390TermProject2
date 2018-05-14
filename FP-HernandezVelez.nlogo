; Kevin Hernandez and Felix Velez
; CSCI 390
; Professor Dickerson
; 5/4/2018
; TERM PROJECT - Ross Dining Hall simulation


globals [
  preference-list                ; a list of the possible food preferences to be chosen at random
  patience-list                  ; more specific variations for student patience
  grab-food-time                 ; time it takes to get a plate of food when at a station
  students-got-food-count        ; # of students that have gotten food
  students-leaving-hungry-count  ; # of students who leave without getting a full meal
  p-omnivorous

  ;easier to know which patch we're talking about
  meat
  salad
  pizza
  pasta

  ; Used for calculating the current time of day (relative to the simulation)
  hour ; current hour
  minute ; current minute
  second ; current second
  ticks-per-second

  ;Attendants that will go and refill trays when they are empty
  meat-server
  salad-server
  pizza-server
  pasta-server

  ;Will be sets of possible choices a student can make at each station
  options-entrance
  options-meat-station
  options-pasta-station
  options-salad-station

]

breed [ students student ]
breed [ servers server ]
breed [ points point ]

patches-own [
  is-exit?         ; true for the red patches agents exit through.
  is-entrance?     ; true for the blue patches agents enter from.
  is-wall?         ; true for the gray patches
  meat?            ; true if meat station
  pizza?           ; true if pizza station
  salad?           ; true if salad station
  pasta?           ; true if pasta station
  servings-left    ; countdown until a station needs to refill its tray of food
  refill-timer     ; countdown before a tray is refilled with food
]

students-own [
  patience         ; amount of time a student will wait to get food
  grab-food-timer  ; a decreasing value as the student is getting food at a station
  target           ; student's destination patch based on optional choices at each station
]

servers-own [
  home-patch  ; patch where servers are idle
  target      ; station where they will refill food
]

to setup
  ca
  reset-ticks

  setup-patches
  setup-servers

  set ticks-per-second 4
  set hour 7                            ; initialize the hour to 7am
  set p-omnivorous (1 - p-vegetarians)
  set grab-food-time 36
  set students-got-food-count 0
  set students-leaving-hungry-count 0
end


; Is asked every tick to set the current time.
;    -Resets to 7am when it reaches 1pm
to set-time
  let time ticks / ticks-per-second
  set second floor (time) mod 60
  set minute (floor (time / 60)) mod 60
  if minute = 0 and second = 0 and ticks mod ticks-per-second = 0 [set hour hour + 1]

  ; we want minutes and seconds to stay as ints, so use temp versions for this procedure
  let temp-minute minute
  let temp-second second

  if hour = 13 [set hour 7] ;loop back to the morning
  if  temp-minute < 10 [
    set temp-minute word "0" temp-minute
  ]
  if temp-second < 10 [
    set temp-second word "0" temp-second
  ]

  ask patch 6 48 [set plabel-color black set plabel (word hour ":" temp-minute ":" temp-second)]
end


;Initialize patches' instance variables
to setup-patches
  ; Initialize all necessary variables first
  ask patches[
    set is-exit? false
    set is-entrance? false
    set is-wall? false
    set pizza? false
    set salad? false
    set meat? false
    set pasta? false
    set servings-left serving-count
    set refill-timer serving-count * 4
  ]
  ; Import a picture of a simple layout of Ross food stations
  import-pcolors "ross-pixelated.png"

  ; Set each entrance, exit, station, and wall based on color
  ask patches with [pcolor = 14.9] [set is-exit? true]
  ask patches with [pcolor = 2.9] [set is-wall? true]
  ask one-of patches with [pcolor = 95.1] [set is-entrance? true]
  ask one-of patches with [pcolor = 64.9]  [set salad? true set salad self ]
  ask one-of patches with [pcolor = 125.7] [set meat? true  set meat self  ]
  ask one-of patches with [pcolor = 44.9]  [set pizza? true set pizza self ]
  ask one-of patches with [pcolor = 116.9] [set pasta? true set pasta self ]

  ; Set up the options at each station (each variable is a set of patches agents will randomly
  ;    choose from when they reach their respective station)
  set options-entrance (patch-set salad meat meat meat meat meat pizza)
  set options-meat-station (patch-set pasta pizza (one-of patches with [is-exit?]))
  set options-pasta-station (patch-set pizza (one-of patches with [is-exit?]) )
  set options-salad-station (patch-set pizza (one-of patches with [is-exit?]))

end



; Creates the attendants for each station
to setup-servers
  ;server for pizza
  create-servers 1 [
    setxy 2 6
    set pizza-server self
    set home-patch patch 2 6
    set target pizza
    set shape "person"
    set color green - 2
    set size 2
  ]
  ;server for pasta
  create-servers 1 [
    setxy 4 43
    set pasta-server self
    set home-patch patch 4 43
    set target pasta
    set shape "person"
    set color green - 2
    set size 2
  ]
  ;server for meat
  create-servers 1 [
    setxy 35 40
    set meat-server self
    set home-patch patch 35 40
    set target meat
    set shape "person"
    set color green - 2
    set size 2
  ]
  ;server for salad
  create-servers 1 [
    setxy 37 4
    set salad-server self
    set home-patch patch 37 4
    set target salad
    set shape "person"
    set color green - 2
    set size 2
  ]
end


; Core function
to move
  if random-float 1.0 < p-student and any? patches with [is-entrance? and not any? students-here][
    spawn-student
  ]

  ask students[

    ;turtles only move if there is not a station or another person in front of them
    ;    UNLESS they are heading towards the exit
    ifelse (not any? other students in-cone 2 30 and (not any? patches with [meat? or pizza? or salad? or pasta? or is-wall?] in-cone 2 15))[
      fd 0.5
      ;ifelse target = meat or target = pasta [follow-link] [fd 0.5]
    ][
      ifelse [is-exit?] of target [
        fd .5
      ][
        update-patience
      ]
    ]

    ; Checks if an agent has reached a station and has it grab food
    if any? patches with [meat? or pizza? or pasta? or salad?] in-radius 2[
      get-food
    ]

    ; Update counts of students who were able to eat and who left hungry
    ;     kill each agent when they reach the exit.
    if [is-exit?] of patch-here [
      ifelse patience = 0[
        set students-leaving-hungry-count students-leaving-hungry-count + 1
      ][
        set students-got-food-count students-got-food-count + 1
      ]
      die
    ]
  ]

  ; update food and refill trays if food-shortage? is on
  refill-trays?

  ;wait 0.025
  tick
  set-time
  top-of-the-hour-influx
end


;updates a student's patience timer
to update-patience
  ; this statement implies the student is not moving, so decrease their patience timer
  if not any? patches in-radius 3 with [meat? or salad? or pasta? or pizza?] [ ;only decrease patience timer if not getting food
    set patience patience - 1
  ]

  ; if student reaches its patience limit, then just go to the exit and leave angrily!
  ; student color becomes red for visualization
  if patience = 0[
    set target one-of patches with [is-exit?]
    face target
    set color red
  ]
end


; If food-shortage is on, updates food left and refill times
to refill-trays?
  if food-shortage? [

    ; Servers move to refill food trys
    ask servers [
      ifelse [pcolor] of target = brown and not any? patches with [pcolor = brown] in-cone 3 10 [
        face target
        fd 0.25
      ][
        if [pcolor] of target != brown [ ; if the tray is empty, refill it!
          ifelse home-patch = patch-here [
            setxy [pxcor] of home-patch [pycor] of home-patch
          ][
            face home-patch
            fd 0.25
          ]
        ]
      ]
    ]
    ask patches with [pcolor = brown] [food-trays]
  ]
end


; Agents need a few seconds to grab their food!
to get-food
  if [pcolor] of target != brown[
    set grab-food-timer grab-food-timer - 1
  ]

  if grab-food-timer < 0[

    ; If food-shortage is on, the amount of food decreases at the station each time a student gets food.
    if food-shortage? [
      ask patch [pxcor] of target [pycor] of target [
       set servings-left servings-left - 1
       if servings-left = 0 [
         set pcolor brown
        ]
      ]
    ]

    ; Student has gotten food at current stations and will choose new target patch
    new-target

    ; reset the grab-food-timer variable for next time
    set grab-food-timer grab-food-time
  ]
end


; Has agents randomly choose a new target patch when they've gotten food at a station
to new-target

    ; Check which station they are by and randomly choose a possible decision from there
    if any? patches in-cone 2 15 with [meat?] [
      set target one-of options-meat-station
      if target = pizza or [is-exit?] of target [ fd 1]
      face target
    ]
    if any? patches in-cone 2 15 with [pasta?] [
      set target one-of options-pasta-station
      face target
    ]
    if any? patches in-cone 2 15 with [salad?] [
      set target one-of options-salad-station
      face target
    ]
    if any? patches in-cone 2 15 with [pizza?] [
      set target one-of patches with [is-exit?]
      face target
    ]
end


; Spawn one student at the entrance with variables initialized
to spawn-student
  if count students < student-count [    ; at least for now, limit number of students that can be in the dining hall
    create-students 1 [
      move-to one-of patches with [is-entrance? and not any? students-here]   ;spawn at the entrance
      set grab-food-timer grab-food-time
      set size 2
      set color (blue - 1 + random-float 4) ; set varied color for nice visualization
      set shape "person"
      set patience (random max-patience) - min-patience ; randomly choose amount of time to wait until the student is fed up with waiting (between 1 minute and 15 minutes)

      let random-choice random-float 1
      ifelse random-choice < p-omnivorous[
        set target meat
      ][
        ifelse random-choice < p-vegetarians [
         set target salad
        ][
          set target pizza
        ]
      ]
      ;set target one-of options-entrance
      face target
    ]
  ]
end

; Called by patches who need trays refilled
to food-trays
  if any? turtles with [color = green - 2] in-radius 3.5 [
    set refill-timer refill-timer - 1
  ]

  if refill-timer = 0 [
    set servings-left serving-count

    if self = salad [set pcolor  64.9]
    if self = pizza [set pcolor  44.9]
    if self = meat  [set pcolor 125.7]
    if self = pasta [set pcolor 116.9]

    set refill-timer serving-count * 3
  ]
end


; dynamically increase the number of students entering the dining hall depending on the time
; as we know most students have class at roughly the top of every hour
; works best if p-student < 0.03
; NOTE: only works for one day cycle (for now)
to top-of-the-hour-influx
  if influx-students?[
    if ticks mod 4 = 0[
      if minute >= 45 [
        set p-student precision (p-student + 0.0002) 5 ; slowly increase the probability of students entering for the next 15 minutes
      ]
      if minute >= 55 [ ; dont decrease p-student at the beginning of the simulation
        set p-student precision (p-student - 0.0006) 5; rapidly decrease the number of students entering (back to original p-students)
      ]
      if hour = 12 and minute < 15[
        set p-student precision (p-student + 0.0003) 5
      ]
      if hour = 12 and minute >= 15[
        set p-student precision (p-student - 0.0001) 5
      ]
      ;set p-student abs p-student ;in case p-student ever goes negative, make sure it's positive
    ]
  ]
end





@#$#@#$#@
GRAPHICS-WINDOW
274
10
802
669
-1
-1
13.0
1
20
1
1
1
0
0
0
1
0
39
0
49
0
0
1
seconds
30.0

BUTTON
19
30
82
63
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
19
71
139
104
NIL
spawn-student
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
19
110
82
143
NIL
move
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
19
166
191
199
p-student
p-student
0.005
0.3
0.1284
0.001
1
NIL
HORIZONTAL

SLIDER
19
204
191
237
student-count
student-count
1
200
200.0
1
1
NIL
HORIZONTAL

SLIDER
19
242
191
275
min-patience
min-patience
180
360
360.0
1
1
NIL
HORIZONTAL

SLIDER
19
281
191
314
max-patience
max-patience
360
2400
1958.0
1
1
NIL
HORIZONTAL

SWITCH
20
400
161
433
food-shortage?
food-shortage?
0
1
-1000

SLIDER
19
438
191
471
serving-count
serving-count
5
50
25.0
1
1
NIL
HORIZONTAL

PLOT
7
482
224
646
students got food vs did not
seconds / 4
count students
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -11221820 true "" "plot students-got-food-count"
"pen-1" 1.0 0 -2674135 true "" "plot students-leaving-hungry-count"

SLIDER
18
345
190
378
p-vegetarians
p-vegetarians
0
1
1.0
0.01
1
NIL
HORIZONTAL

SWITCH
99
113
243
146
influx-students?
influx-students?
0
1
-1000

@#$#@#$#@
## TERM PROJECT - Ross Dining Hall simulation
We have neither given nor received any unauthorized aid on this assignment.
-Kevin Hernandez, Felix Velez


-Due to the slowness of students, we have changed one second to be equivalent to four ticks in this simulation.

This program is meant to simulate traffic in Ross Dining hall. We are keeping track of the times when the dining halls get busy and how many students are getting full meals vs how many are leaving hungry.

We attempted to recreate typical behavior in the dining halls with certain aspects simplified. For example, students cutting in line is fairly frequent, but we limited that heavily in our program. We are also only focused on the mornings and early afternoon times since those are the times when when the majority of students would be busy with classes.

We have students randomly choose stations to go to at each point. From the entrance, they can choose to go to the meat station (most popular choice), the pizza station, or the salad station.

### Overview of the interface

When you click the setup button, right away there are many elements on screen. The dark green people standing on each corner of the world are the servers, who cook and refill the food trays when they are empty. There are four distinct food stations represented as single colored patches, as follows:

-meat: represented by the magenta patch on the top right part of the world
-pasta: represented by the lavender patch on the top left part of the world
-salad: represented by the bright green patch on the bottom right part of the world
-pizza: represented by the yellow patch on the bottom left part of the world

Meat is only accessible by those that are not vegetarian. Pasta is only accessible to those who get meat, to simulate the natural line formations that exist in Ross.

The slider labeled "p-students" is the probability of a student appearing in the dining hall. It can be played with, but it will automatically update itself based on the time of day in the simulation. It is recommended that the value is fairly low, around 0.15.

The "student-count" slider limits the number of students that can exist at once in the simulation.

The "min-patience" and "max-patience" sliders are used to set the lowest and highest possible wait times for students before they leave the dining hall hungry.

"p-vegetarians" is the probability that a student is a vegetarian. If they are a vegetarian they, will not head to the meat (magenta) station and instead will head to the salad (green) station.

There is a switch called "food-shortage?" that determines whether food at each station is limited and will need to be filled occasionally. 

When the switch is turned on, each station has a serving count determined by the slider "serving-count". This count is applied only when "setup" is pressed. 

**If the user wants to check how another serving-count value affects the simulation, they will need to reset the program with the "setup" button


Lastly, there is a graph at the bottom. it records all of the students who got a full meal in green and those who did not in red.



### Agent Behavior

Besides the green servers, the other agents in the simulation are all students. They come in from the entrance (blue patches) and choose which food station to go to. They will only move forward if there is not another student in front if them (thus lines form). If there is, then their patience timer decreases (unless they are right at the station waiting for the food tray to be refill). 


The patience variable is a countdown that, when zero, the student, cannot wait any longer and leaves the dining hall without a full meal. When they leave due to impatience, they will turn red for visualization.


When a student reaches a food station, it takes a few seconds to get their serving onto their plate. There is a countdown that needs to hit zero before the student has gotten their food and moves to their next destination. 

Also, when this "grab-food" countdown reaches zero, the number of servings left at the station decreases by one.

If a student's next destination is the exit, then they will ignore the possibility of another student being in front of them. This is because we are focusing on the time it takes to actually get food. This also helps prevent a case where two students cannot move at all because they would be moving on opposite directions.




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
NetLogo 6.0.1
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
