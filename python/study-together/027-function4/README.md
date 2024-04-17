
# 组团学Python第27期-函数（function）类型（下）

同学们好！欢迎大家参加我们的第27期班会，一起来系统的学习Python。

本期学习内容： 函数（function）类型（下）

上一期班会我们介绍了四种函数类型，包括内置函数，自定义函数，匿名函数，高阶函数。这期班会我们会再介绍两个函数，递归函数和生成器函数。

5. 递归函数（Recursive Functions）：这类函数在其定义中调用自身，用于解决递归问题。

当谈到递归函数时，一个经典的例子是计算阶乘（factorial）。阶乘是一个正整数 n 的连乘，通常用符号 "!" 表示。阶乘的定义如下：n! = n * (n-1) * (n-2) * ... * 2 * 1。而且，0 的阶乘被定义为 1。

下面是一个使用递归函数来计算阶乘的示例：
def factorial(n):
    if n == 0:
        return 1
    else:
        return n * factorial(n - 1)

# 示例调用
print(factorial(5))  # 输出: 120

在这个例子中，factorial() 函数使用递归的方式计算阶乘。当 n 为 0 时，函数返回 1（根据阶乘定义）。否则，函数返回 n 与 factorial(n - 1) 的乘积，其中 factorial(n - 1) 就是对 n - 1 的递归调用。这样，函数会逐步向下计算，直到 n 的值为 0，然后开始向上返回结果。

考你一下，你会用递归函数写一个汉诺塔游戏吗？

6. 生成器函数（Generator Functions）：这类函数使用yield语句来生成一个序列的值，每次调用yield会暂停函数执行，并返回一个值给调用者，但是保留当前状态，以便下次调用时可以从上次暂停的地方继续执行，直到生成器耗尽或遇到return语句。生成器函数可以用于迭代器的创建。例如：

    def count_up_to(n):
        count = 1
        while count <= n:
            yield count
            count += 1

在上面这个示例中，count_up_to()是一个生成器函数，每次调用时会返回一个生成器对象。在每次循环迭代中，生成器函数会从上次暂停的地方继续执行，生成并返回一个新的值给迭代器，直到生成器函数结束。

这种特性使得生成器函数可以高效地处理大量的数据流，因为它不需要一次性将所有数据加载到内存中，而是可以逐个生成并处理数据。这在处理大型数据集或无限序列时非常有用。

以上这些是Python中常见的函数类型，每种类型都有其特定的用途和适用场景，同学们需要了解一下。

接下来再给大家介绍一下函数里的类型提示功能（Type Hint），它主要是起到给开发人员提示的作用，但不能作为类型检查哦。

当使用类型提示功能时，你可以在变量声明、函数参数和函数返回值上添加类型信息。以下是一个简单的例子：

# 使用类型提示声明变量的类型
x: int = 5
y: str = "Hello"

# 使用类型提示声明函数参数和返回值的类型
def add(a: int, b: int) -> int:
    return a + b

# 使用类型提示进行函数调用
result: int = add(3, 4)
print(result)  # 输出：7

在这个例子中，我们使用了int和str来声明变量x和y的类型，以及在函数add的参数和返回值上使用了类型提示。这样做有助于IDE（集成开发环境）提供更好的代码补全和静态类型检查。

对了，这个功能只有3.5以上的版本才支持哦，要小心了。很多习惯好的程序员都会使用这个，大家以后也要会看会用啊。

最后我们来介绍一下Python的文档字符串（docstring）功能。文档字符串是用来描述函数、类、模块等的用途、功能和使用方法。文档字符串是放置在函数、类或模块开头的字符串，用三重引号（单引号或双引号）括起来。

举个例子，在函数定义的开始部分添加文档字符串，如下所示：

def add(a, b):
    """
    This function takes two numbers as input and returns their sum.

    Parameters:
    a (int): The first number.
    b (int): The second number.

    Returns:
    int: The sum of the two numbers.
    """
    return a + b

你可以通过调用help(add)或print(add.__doc__)或者查看编辑器中的提示信息，就可以获得关于函数add的说明。

顺便提一下，上面提到的这个add.__doc__，还有后面的__doc__是函数的内省功能，意思就是任何函数都会默认添置的功能区。函数的内省功能还有很多，包括以后会遇到的__name__，你可以使用print(dir(add))来查看，这个以后有机会再介绍吧。

文档字符串的主要功能包括：

提供文档：文档字符串提供了对代码的解释和说明，让其他开发人员可以更容易地理解代码的作用和用法。

自动生成文档：文档字符串可以被工具和库用来自动生成文档，如Sphinx等。

内置文档查看器：Python内置了帮助函数help()，可以用来查看函数、类、模块等的文档字符串，方便了解其功能和使用方法。

好了，以上就是全部关于函数的知识点。我们下期再见！


今日练习：

What will be the output of the following code? 
def boo(x): 
    if x == 1: 
        return x
    return x * boo(x-1)
print(boo(3))

A. 1
B. 6
C. Python will show an error
D. 3


Answer: B
Explanation/Reference:
This is a recursive function because it calls itself inside its body. b00(3) = 3 *bo0(2) =3*2 *boo(1) = 3*2 * 1 = 6.