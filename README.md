# Bash Data Structure Methods

This grew out of some code I was working on a long time ago. I had written
a large and complicated application in Bash, and I had implemented a
number of crazy things in Bash.

After working on that, I thought -- could I generalize this to a set of tools
that allowed you to work with complex data structures in Bash?

This is the result, or part of the result. It's unfinished, but the ideas
are there. I haven't had to do anything complex in bash in many years.

Demonstration:

    $ new list $(seq 0 19)
    $ y=$REPLY
    $ $y print
    0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19

    $ $y get '::-3'
    $ z=$REPLY
    $ $z print
    19 16 13 10 7 4 1

    $ $y get '5:-5'
    $ z=$REPLY
    $ $z print
    5 6 7 8 9 10 11 12 13 14

    $ new dict
    $ d=$REPLY
    $ $d set foo bar
    $ for x in one two 3 "3 3" "3.5" "f o u r" "555 55"; do
    >     $d set "$x" "some generic value"
    > done
    $ $d print
    3 => some\ generic\ value
    3\ 3 => some\ generic\ value
    3.5 => some\ generic\ value
    555\ 55 => some\ generic\ value
    f\ o\ u\ r => some\ generic\ value
    foo => bar
    one => some\ generic\ value
    two => some\ generic\ value
