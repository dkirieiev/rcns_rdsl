"""
$ make test
#py.test
python -m pytest tests/
============== test session starts =================================================================
rootdir: /home/dkireyev/workspace/rcns_rdsl, inifile: setup.cfg
collected 2 items

tests/test_rcns_rdsl.py .
tests/test_robot.py .

================ 2 passed in 0.82 seconds ==========================================================


$ make test-all
[...]
ERROR:   py35: commands failed
  py36: commands succeeded
  py37: commands succeeded
  flake8: commands succeeded


$ make coverage
Coverage report: 82%
TODO increase coverage, cover edge-cases.
"""
from os.path import dirname, join
from pathlib import Path

import pytest

from rcns_rdsl.robots.robot import main


@pytest.fixture
def robot():
    """Robot followed [correct] test_route.

    This robot will be using the default program.

    robot.tx contains the following route

    begin
        Initial 1, 1
        Go North 1
        Go South 1
        Go East 1
        Go West 1
        Turn right
        Turn left
        Go 3
    end
    """
    this_folder = dirname(__file__)
    prog_file = join(str(Path(this_folder).parent), "rcns_rdsl/robots/robot.tx")
    instruct_file = join(this_folder, "test_route.rbt")
    return main(prog_file, instruct_file, debug=True)


def test_robot(robot):
    assert robot.x == 1
    assert robot.y == 4
    assert robot.direction == "North"
