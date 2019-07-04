"""Domain-specific language for representing the following:

● Robot has start coordinates
● Robot follows instructions:
    ○ turn left
    ○ turn right
    ○ go distance x in direction N/S/E/W
    ○ go distance x (in whatever direction you are facing)
    ○ go until you reach a landmark

Text file robot.tx contains the DSL itself.
Text file program.rbt contains a sample route upload file.

$ python rcns_rdsl/robots/robot.py
Setting position to: 3, 1
Facing West
Going North for 4 step(s).
Facing North
Going West for 9 step(s).
Cannot cross the west border. Missed 6 steps.
Going South for 1 step(s).
Going East for 1 step(s).
Going North for 7 step(s).
Reached landmark 'Statue of Old Man with Large Hat' at 1, 11
Setting position to: 245, 161
Going North for 5 step(s).
Facing East
Going East for 10 step(s).
Reached landmark 'Statue of Old Man with Large Hat' at 255, 166
Going West for 25 step(s).
Facing North
Going North for 3 step(s).
Robot position is: 230, 169.
"""
import random
from operator import add, sub
from os.path import dirname, join

from textx import metamodel_from_file
from textx.export import metamodel_export, model_export


class Robot():
    """Robot DSL engine.

    Processes routes uploaded by Route planners.
    """
    def __init__(self,):
        # Initial position is (0,0)
        self.x = 0
        self.y = 0
        self.direction = "North"

    def __str__(self):
        return "Robot position is: {}, {}.".format(self.x, self.y)

    def interpret(self, model):
        """Helps robots follows route instructions.

        :param model: instance of Program. Model is a python object graph consisting of POPOs
        (Plain Old Python Objects) constructed from the input string that conforms to your DSL
        defined by the grammar and additional model and object processors.
        :return: None
        """
        for c in model.commands:

            if c.__class__.__name__ == "InitialCommand":
                print("Setting position to: {}, {}".format(c.x, c.y))
                self.x = c.x
                self.y = c.y
            if c.__class__.__name__ == "TurnCommand":
                self.turn(c.turn)
            if c.__class__.__name__ == "MoveCommand":
                self.move(c.direction, c.steps)
            if c.__class__.__name__ == "RoamCommand":
                if c.blocks:
                    self.move(self.direction, c.blocks)
                else:
                    # Handles "go until you reach a landmark" instruction
                    # TODO utilize corresponding landmark API endpoint instead of the emulation
                    # TODO move to a separate method
                    steps = random.randint(1, 30)
                    self.move(self.direction, steps)
                    print("Reached landmark '%s' at %s, %s" % (c.landmark, self.x, self.y))
        print(self)

    def turn(self, lor):
        """Interprets turn left|right instructions."""
        pointers = ["West", "North", "East", "South"]
        func = sub if lor == "left" else add
        current_idx = pointers.index(self.direction)
        new_idx = func(current_idx, 1)
        if new_idx < 0:
            new_idx = 3
        elif new_idx > 3:
            new_idx = 0
        self.direction = pointers[new_idx]
        print("Facing %s" % self.direction)

    def move(self, direction, steps):
        """Interprets the following instructions:

        ○ go distance x in direction N/S/E/W
        ○ go distance x (in whatever direction you are facing)
        """
        print("Going {} for {} step(s).".format(direction, steps))
        base_distance = {"North": (0, 1), "South": (0, -1), "West": (-1, 0), "East": (1, 0)}[
            direction
        ]
        # TODO refactor prints to logging (will be easier to control the output amount [with
        #  different logging levels])
        # print(self.x, self.y, base_distance, steps)
        # Calculate new robot position
        self.x += steps * base_distance[0]
        self.y += steps * base_distance[1]

        border_msg = "Cannot cross the %s border. Missed %s steps."
        if self.x < 0:
            print(border_msg % ("west", abs(self.x)))
            self.x = 0
        if self.y < 0:
            self.y = 0
            print(border_msg % ("south", abs(self.y)))
        # print(self.x, self.y, base_distance, steps)


def move_command_processor(move_cmd):
    """
    This is object processor for MoveCommand inst ances.
    It implements a default step of 1 in case not given
    in the program.
    """

    if move_cmd.steps == 0:
        move_cmd.steps = 1


def main(program_file, route_file, debug=False):
    """Demo."""
    # TODO Either all return statements in a function should return an expression,
    #  or none of them should. (inconsistent-return-statements)
    current_folder = dirname(__file__)
    robot_mm = metamodel_from_file(program_file, debug=debug)
    metamodel_export(robot_mm, join(current_folder, "robot_meta.dot"))

    # Register object processor for MoveCommand
    robot_mm.register_obj_processors({"MoveCommand": move_command_processor})

    robot_model = robot_mm.model_from_file(route_file)
    model_export(robot_model, join(current_folder, "program.dot"))

    robot = Robot()
    robot.interpret(robot_model)
    if debug:
        return robot


if __name__ == "__main__":
    this_folder = dirname(__file__)
    prog_file = join(this_folder, "robot.tx")
    instruct_file = join(this_folder, "program.rbt")
    main(prog_file, instruct_file)
