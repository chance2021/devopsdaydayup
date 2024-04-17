# 组团学Python第26期-函数（function）类型（上）

同学们好！欢迎大家参加我们的第26期每周一三五班会，一起来系统的学习Python。

本期学习内容： 函数（function）类型（上）

上期班会我们介绍了函数参数，同学们还能回忆起来带*和**的区别吗？忘了的话赶紧回去复习一下吧。

今天的班会我们来介绍一下不同的函数类型。在Python中的函数类型包括以下几种：

1. 内置函数（Built-in Functions）：这些函数是Python解释器内置的，可以直接在任何地方使用，无需额外导入模块。例如我们最常见的print()就是一个内置函数，还有、len()，list(), type()等。

2. 用户自定义函数（User-defined Functions）：这就是我们前两期班会着重介绍的函数类型，这种类函数由用户根据需求自行定义，使用def关键字进行声明。用户可以根据需要定义函数名称、参数和返回值。例如：
    def add(x, y):
        return x + y
   
3. 匿名函数（Lambda Functions）：这各类型我们两期前的班会也介绍过，这是一种简单的函数，由lambda关键字定义，通常用于在一些函数式编程场景中，例如在map()、filter()等函数中使用。例如：
add = lambda x, y: x + y

对了，你能写出她等价的用户自定义函数吗？试写写看！

4. 高阶函数（Higher-order Functions）：高阶函数是指能接受其他函数作为参数，或者能够返回一个函数作为结果的函数。这种特性使得函数可以作为一等公民在Python中被灵活地传递和使用。高阶函数在函数式编程中起着重要的作用，它们可以简化代码、提高可读性，并且常用于处理集合、数据转换、筛选和排序等任务。

前段时间看的《独角兽项目》里就大力推荐了函数式编程，有机会再去了解一下。

在Python中，一些常见的高阶函数包括：map()、filter()、reduce()（注：在Python 3中已经移到了functools模块下）、你sorted()等。下面我们来详细介绍这些函数：

map()函数：map(function, iterable)函数接受一个函数和一个可迭代对象作为参数，将该函数应用于可迭代对象的每个元素，并返回一个结果列表。例如：
   numbers = [1, 2, 3, 4, 5]
   squared = list(map(lambda x: x**2, numbers))
   print(squared)  # 输出：[1, 4, 9, 16, 25]

filter()函数：filter(function, iterable)函数用于筛选可迭代对象中满足条件的元素，返回一个由满足条件的元素组成的迭代器。在调用filter函数的时候，iterable会被遍历，它的元素会被逐一传入function函数中，function函数如果返回True，元素就被保留，如果是False，就被过滤掉，遍历完成后吧保留下的元素放到容器数据里，你可以用list()函数再把它转换成一个列表，就能使用了。举个例子:
   numbers = [1, 2, 3, 4, 5]
   even_numbers = list(filter(lambda x: x % 2 == 0, numbers))
   print(even_numbers)  # 输出：[2, 4]

sorted()函数：sorted(iterable, key=None, reverse=False)函数用于对可迭代对象进行排序，返回一个新的排序后的列表。可选的参数key可以指定一个函数来生成排序的关键字，reverse参数用于指定是否降序排序。例如：

   words = ["banana", "apple", "orange", "grape"]
   sorted_words = sorted(words, key=lambda x: len(x))
   print(sorted_words)  # 输出：['apple', 'grape', 'banana', 'orange']

4. reduce()函数：reduce(function, iterable, initializer=None)函数在Python 2中是内置函数，但在Python 3中移到了functools模块下。它接受一个函数和一个可迭代对象作为参数，将该函数应用于可迭代对象的前两个元素，然后将结果与下一个元素继续应用函数，直到处理完所有元素。它最终返回一个单一的结果值。例如：

   from functools import reduce
   numbers = [1, 2, 3, 4, 5]
   sum = reduce(lambda x, y: x + y, numbers)
   print(sum)  # 输出：15

以上就是常见的一些高阶函数。这些高阶函数可以大大简化代码，提高编程效率，并且使得代码更加具有表达力和灵活性。

关于常用的函数，我们这期先介绍到这四个，下次我们再介绍两个进阶版的函数供大家把玩。我们下期再见！

今日练习:

What will be the output of the following code? def fun(a=1, b=3):
return a * b
print(fun(b=2))
A. Python will show an error
B. 3
C. 2
D. 6


Answer: C
Explanation/Reference:
Since we don't provide a value for variable a, Python will use the default value of 1. For b, it will use our own custgom
value of 2. 1 * 2 = 2.