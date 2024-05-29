#!/bin/python3

import math
import os
import random
import re
import sys

#
# Complete the 'hourglassSum' function below.
#
# The function is expected to return an INTEGER.
# The function accepts 2D_INTEGER_ARRAY arr as parameter.
#

def hourglassSum(arr):
    largest_hourglass_sum = float('-inf')
    
    for i in range(len(arr) - 2):
        for j in range(len(arr[0]) - 2):
            top_hourglass_sum = arr[i][j] + arr[i][j+1] + arr[i][j+2]
            middle_hourglass_sum = arr[i+1][j+1]
            bottom_hourglass_sum = arr[i+2][j] + arr[i+2][j+1] + arr[i+2][j+2]
            if top_hourglass_sum + middle_hourglass_sum + bottom_hourglass_sum > largest_hourglass_sum:
                largest_hourglass_sum = top_hourglass_sum + middle_hourglass_sum + bottom_hourglass_sum
    return largest_hourglass_sum

if __name__ == '__main__':
    fptr = open(os.environ['OUTPUT_PATH'], 'w')

    arr = []

    for _ in range(6):
        arr.append(list(map(int, input().rstrip().split())))

    result = hourglassSum(arr)

    fptr.write(str(result) + '\n')

    fptr.close()
