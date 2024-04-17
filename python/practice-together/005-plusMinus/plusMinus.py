#!/bin/python3

import math
import os
import random
import re
import sys

#
# Complete the 'plusMinus' function below.
#
# The function accepts INTEGER_ARRAY arr as parameter.
#

def plusMinus(arr):
    pos_num = 0
    neg_num = 0
    zero_num = 0
    for i in arr:
        if i > 0:
            pos_num += 1
        elif i < 0:
            neg_num += 1
        else:
            zero_num += 1
    pos_ratio = round(pos_num / len(arr), 6)
    neg_ratio = round(neg_num / len(arr), 6)
    zero_ratio = round(zero_num / len(arr), 6)
    print(pos_ratio)
    print(neg_ratio)
    print(zero_ratio)

if __name__ == '__main__':
    n = int(input().strip())

    arr = list(map(int, input().rstrip().split()))

    plusMinus(arr)
