#!/bin/python3

import math
import os
import random
import re
import sys

#
# Complete the 'timeConversion' function below.
#
# The function is expected to return a STRING.
# The function accepts STRING s as parameter.
#

def timeConversion(s):
    AM_or_PM = s[-2:]
    hour = s[:2]
    if AM_or_PM == "AM":
        if hour == "12":
            s = "00" + s[2:-2]
        else:
            s = s[:-2]
    elif AM_or_PM == "PM":
        if hour == "12":
            s = "12" + s[2:-2]
        else:
            s = str(int(hour) + 12) + s[2:-2]
    return s

if __name__ == '__main__':
    fptr = open(os.environ['OUTPUT_PATH'], 'w')

    s = input()

    result = timeConversion(s)

    fptr.write(result + '\n')

    fptr.close()
