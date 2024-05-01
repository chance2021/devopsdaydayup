#!/bin/python3

import math
import os
import random
import re
import sys

#
# Complete the 'miniMaxSum' function below.
#
# The function accepts INTEGER_ARRAY arr as parameter.
#

def miniMaxSum(arr):
    sum = min = max = arr[0]
    for n in arr[1:]:
        if n < min:
            min = n
        elif n > max:
            max = n
        sum += n
    print(f"{sum-max} {sum-min}")

if __name__ == '__main__':

    arr = list(map(int, input().rstrip().split()))

    miniMaxSum(arr)
