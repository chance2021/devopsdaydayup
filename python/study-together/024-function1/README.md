# 组团学Python第24期-函数（function）基本概念

同学们好！欢迎大家参加我们的第24期每周一三五班会，一起来系统的学习Python。

本期学习内容： 函数（function）基本概念

本期班会我们来看看Python里的函数（function）这个概念。所谓的函数，就是封装一个可以多次执行的代码片段。当然，如果你只有一句代码，而且整个程序只执行一次，那这时候就没必要使用函数了。

其实我们在介绍数据类型时候就使用过很多函数，比如int（），str（），sum()这些都是Python内置的函数。函数通常用于组织代码，提高代码的可读性、可维护性和复用性。

函数通常由以下几个部分组成：

1. 函数名：函数的名称用于标识和调用函数。
2. 参数（可选）：*函数可以接受零个或多个参数作为输入，这些参数是函数执行所需的数据。
3. 函数体：函数体包含了函数的实际代码逻辑，用于完成特定的任务。
4. 返回值（可选）：函数可以返回一个或多个值作为结果输出，这些值可以被调用函数的代码使用。

Python中定义函数的基本语法如下：

def function_name(参数):
    # 函数体
    # 执行特定的任务
    return value  # 可选，返回值

注意上面的缩进哦。

以下是一个简单的Python函数示例：

def greet(name):
    return "Hello, " + name + "!"

message = greet("Alice")
print(message)  # Output: Hello, Alice!

在这个例子中，greet是一个函数，接受一个参数 name，并返回一个拼接了问候语的字符串。调用 greet("Alice")将会返回 "Hello, Alice!"。

看到没，调用函数的时候要记得在函数名后面加上小括号，至于里面有没有参数，这是可选的，看你的函数需不需要了。如没有加小括号，那只会返回函数的对象，而不会去调用这个函数，也就不会有返回值了。顺便说一下，我们所说的调用函数，也就是执行函数里面的程序的意思。

在Python里还有一个特殊的函数，叫做匿名函数（Anonymous functions），也称为lambda函数，是一种在Python中用于创建简单函数的特殊方式。

与正常的函数不同，匿名函数通常只包含一个表达式，它的语法更加简洁。匿名函数的基本语法如下：
lambda arguments: expression

其中：
- `lambda` 是关键字，用于声明一个匿名函数。
- `arguments` 是函数的参数，可以是零个或多个。
- `expression` 是函数的返回值，是一个单行表达式。

与普通函数不同，匿名函数没有函数名，也没有使用 `def` 关键字来定义，因此称为“匿名”。需要注意的是，lambda体部分不能是一个代码块，也就是不能包含多条语句，只能有一条语句，语句会计算一个结果并返回给lambda函数，它的返回值不需要用到return。总的来说匿名函数通常用于需要简单功能的场合，可以在一行代码中快速定义和使用。

以下是一个使用匿名函数的简单示例：

double = lambda x: x * 2
print(double(5))  # Output: 10

在这个例子中，我们使用lambda创建了一个匿名函数，用于将传入的参数x加倍，然后我们传入参数5调用这个匿名函数，输出结果为10。lambda函数里，分号左边的x表示参数，分号右边x*2是表达式，表达式计算后的值就是这个匿名函数的返回值。

你可以将匿名函数转换为等效的普通函数，像这样:

def double(x):
    return x * 2

print(double(5))  # Output: 10

这里，我们使用 `def` 关键字来定义了一个名为 `double` 的函数，接受一个参数 `x`，并返回 `x * 2` 的结果。这与之前的匿名函数的功能是相同的，但是使用了标准的函数定义语法。对比一下，匿名函数代码量减少了一半。

lambda函数虽然语法简单，但是增加了学习难度，刚刚开始学的同学第一眼看到一定都会懵。不过没关系，我们之后有很多练习的机会，到时候再慢慢吸收消化。

接下来我们再讲一下参数。在函数里，参数分为形参和实参。形参就是形式参数，它是在定义函数时使用的参数。实参是实际参数，它是在调用函数时传递给形参的实际参数值。它们的具体区分如下:

1.形参（Parameters）：形参是函数定义中的变量名，用于接收函数调用时传递的数据。形参在函数定义时被指定，用于定义函数的输入。还有形参相当于函数内部的局部变量，在函数体内可以被使用。

在Python中，函数的形参写在函数定义的括号内，例如：

def greet(name):
    print("Hello, " + name + "!")

在这个例子中，`name` 就是函数 `greet` 的形参。

2. 实参（Arguments）：实参是函数调用时传递给函数的具体数据，用于给函数的形参赋值。实参可以是常量、变量、表达式等。

在Python中，函数调用时传递的数据称为实参，例如：
greet("Alice")

在这个例子中，"Alice" 就是传递给函数 `greet` 的实参。

总之，形参是函数定义中用来接收数据的变量，实参是在函数调用时传递给函数的具体数据。形参用于定义函数的输入，而实参用于提供函数所需的具体数据。这下以后听到其他程序员口中形参（parameter）和实参（argument）千万不要混淆哦。

关于函数，我们还有很多要说的，时间有限，今天班会就到这里，我们下期再见！


今日练习:

What will be the output of the following code? 

def myfunc():
    print(num + 1, end=")
num = 2
myfunc()
print(num)
A. 33
B. 31
C. 32
D. 22


Answer: C
Explanation/Reference:
Inside the function, we'll print the value of num increased by 1 (2 + 1 = 3). However, we don't change the value stored in
the variable num, so when we exit the function, it's still equal to 2. As a result, we can see 3 and then 2 printed.
