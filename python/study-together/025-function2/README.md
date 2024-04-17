# 组团学Python第25期-函数（function）调用

同学们好！欢迎大家参加我们的第25期每周一三五班会，一起来系统的学习Python。

本期学习内容： 函数（function）调用

上期我们开始介绍函数，知道了函数就是一个可以重复调用的代码块，还了解什么是函数的参数，以及什么是形参（parameter）和实参（argument）。今天的班会我们会继续再看一下函数的调用，也就是如何使用函数。

开始之前，先让同学们看看以下这个函数，你能理解什么意思吗？

def print_values(*args, **kwargs):
    print("Positional arguments:")
    for arg in args:
        print(arg)
    
    print("\nKeyword arguments:")
    for key, value in kwargs.items():
        print(f"{key}: {value}")

# 调用函数
print_values(1, 2, 3, name="Alice", age=25)

这是函数其中一种很常见的调用方式，我以前经常见，但是却经常忘了是啥意思。和我一样不理解的同学就跟我一起来学吧！

在Python中，函数可以以不同的方式进行调用。以下是几种常见的函数调用方式：

1. 位置参数调用。位置参数是按照函数定义中参数的顺序进行传递的，参数的位置决定了它们的值。当我们调用函数时，按照函数定义中参数的位置从左到右的顺序传递参数值。比如

   def greet(name, age):
       print("Hello, " + name + "! You are " + str(age) + " years old.")
   
   greet("Alice", 25)  # Output: Hello, Alice! You are 25 years old.


2. 关键字参数调用。关键字参数是通过参数名来指定的，可以不按照函数定义中参数的顺序传递参数值。在调用函数时，通过参数名来传递参数值，可以提高代码的可读性和可维护性。比如还是上面定义的函数，我们这样调用:
  
   greet(age=25, name="Alice")  # Output: Hello, Alice! You are 25 years old.
 
在Pythin里使用open函数打开文件的时候，就是用到关键字参数调用来指定文件的打开模式、编码方式等。以下是一个打开文件的例子：
# 打开文件并写入内容
with open("example.txt", mode="w", encoding="utf-8") as file:
    file.write("Hello, world!")

# 打开文件并读取内容
with open("example.txt", mode="r", encoding="utf-8") as file:
    content = file.read()
    print(content)  # 输出：Hello, world!


在这个例子中，open()函数使用了两个关键字参数：

- `mode`：指定文件的打开模式，这里使用了写入模式 `"w"` 和读取模式 `"r"`。
- `encoding`：指定文件的编码方式，这里使用了 UTF-8 编码。

使用关键字参数可以更清晰地指定函数的参数值，提高了代码的可读性。

3. 默认参数调用。默认参数是在函数定义中指定的具有默认值的参数，如果调用函数时不提供对应参数的值，则使用默认值。默认参数可以简化函数调用，但需要注意避免使用可变对象作为默认值。还有记得要把有默认值的参数放在最后，否则如果有其他实参也传入的话就会被按顺序先读取了。再看看下面这个例子：
   
   def greet(name, age=30):
       print("Hello, " + name + "! You are " + str(age) + " years old.")
   
   greet("Alice")  # Output: Hello, Alice! You are 30 years old.
   greet("Bob", 35)  # Output: Hello, Bob! You are 35 years old.
  
学过C语言的同学可能会了解一个叫函数重载的概念，即可以定义多个同名函数，但是参数列表不同，这样在调用函数时能传递不同实参。而在Python里却没有这个概念，因默认参数调用就能实现这个目的了。

4. 基于元组的可变参数调用(*arg)。可变参数允许传递任意数量的位置参数，这些参数会被封装成一个元组（tuple）传递给函数。在函数定义中，可变参数使用 `*args` 来表示，可以接受任意数量的位置参数。
   
   def sum_numbers(*args):
       total = 0
       for num in args:
           total += num
       return total
   
   print(sum_numbers(1, 2, 3))  # Output: 6

5. 基于字典的可变参数调用（**kwarg
），它也叫做关键字可变参数调用。关键字可变参数允许传递任意数量的关键字参数，这些参数会被封装成一个字典（dictionary）传递给函数。在函数定义中，关键字可变参数使用 `**kwargs` 来表示，可以接受任意数量的关键字参数。例如:
   
   def print_info(**kwargs):
       for key, value in kwargs.items():
           print(f"{key}: {value}")
   
   print_info(name="Alice", age=25)  # Output: name: Alice, age: 25

以上就是常见的函数调用方式。这些不同的调用方式可以根据具体的需求来选择，可以根据情况组合使用，以满足函数的不同功能和灵活性。

到这里，同学们再回头看看一开头的那个函数，就能理解什么意思了吧！

运行该代码将输出以下内容：Positional arguments:
1
2
3

Keyword arguments:
name: Alice
age: 25

这是因为在函数调用print_values(1, 2, 3, name="Alice", age=25)时，传入了三个位置参数（1、2、3）和两个关键字参数（name="Alice"、age=25），函数内部首先打印了所有的位置参数，然后打印了所有的关键字参数及其对应的值。

在Python中，作用域（Scope）指的是变量可以被访问的范围。Python中有以下几种作用域：

1. 全局作用域（Global scope）。全局作用域中定义的变量可以在程序的任何地方被访问。在模块级别定义的变量属于全局作用域，在整个模块中都可以被访问。比如:
   
   x = 10  # 全局作用域
   
   def func():
       print(x)  # 可以访问全局变量 x
   
   func()  # Output: 10

2. 局部作用域（Local scope）。局部作用域中定义的变量只能在其所在的函数内部被访问。在函数内部定义的变量属于局部作用域，在函数外部无法访问。

   def func():
       y = 20  # 局部作用域
       print(y)  # 可以访问局部变量 y
   
   func()  # Output: 20
   print(y)  # Error: NameError: name 'y' is not defined

3. 嵌套作用域（Enclosing scope）。嵌套作用域是指函数内部的函数可以访问外部函数中的变量。内部函数可以访问外部函数的局部变量，但外部函数无法访问内部函数的局部变量。

   def outer():
       z = 30  # 外部函数的局部变量
       def inner():
           print(z)  # 可以访问外部函数的局部变量 z
       inner()
   
   outer()  # Output: 30
  

4. 内置作用域（Built-in scope）。内置作用域是指Python中内置函数和模块的作用域。
Python中的内置函数和内置模块中定义的变量可以在程序的任何地方被访问。

   print(abs(-5))  # 内置函数 abs() 在内置作用域中定义


在Python中，变量的作用域由其定义的位置决定。当在函数内部访问变量时，Python会按照以下顺序搜索变量的值：局部作用域 -> 嵌套作用域 -> 全局作用域 -> 内置作用域。如果变量在局部作用域中未定义，则会向外层作用域搜索，直到找到为止。


关于函数还有很多没讲，我们留到下期班会再继续吧。我们下期再见！


今日练习:

What will be the output of the following snippet? 

def show_truth():
    global mysterious_var
    mysterious_var = 'New Surprise!'
    print(mysterious_var)
mysterious_var = 'Surprise!'
print(mysterious_var)
pront mysterious var)
A. Surprise!Surprise!Surprise!
B. Surprise!New Surprise!New Surprise!
C. Surprise!New Surprise!Surprise!
D. New Surprise!New Surprise!New Surprise!


Answer: B
Explanation/Reference:
First, we print the old value of Surprise. Then, inside the function, we modify the global variable (note the use of the keyword global). From this moment on, mysterious_var will have the new value of New Surprise, and this value will be printed twice: once from the function, once from the main code.





