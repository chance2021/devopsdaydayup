#!/bin/python3

import math
import os
import random
import re
import sys

#
# Complete the 'breakingRecords' function below.
#
# The function is expected to return an INTEGER_ARRAY.
# The function accepts INTEGER_ARRAY scores as parameter.
#

def breakingRecords(scores):
    highest_record = scores[0]
    lowest_record = scores[0]
    count_break_highest = 0
    count_break_lowest = 0
    for i in range(1, len(scores)):
        if scores[i] > highest_record:
            highest_record = scores[i]
            count_break_highest += 1
        elif scores[i] < lowest_record:
            lowest_record = scores[i]
            count_break_lowest += 1
    return count_break_highest, count_break_lowest
        

if __name__ == '__main__':
    fptr = open(os.environ['OUTPUT_PATH'], 'w')

    n = int(input().strip())

    scores = list(map(int, input().rstrip().split()))

    result = breakingRecords(scores)

    fptr.write(' '.join(map(str, result)))
    fptr.write('\n')

    fptr.close()
