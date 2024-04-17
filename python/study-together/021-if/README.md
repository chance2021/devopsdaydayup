# 组团学Python第21期-if条件语句

同学们好！欢迎大家参加我们的第21期每周一三五班会，一起来系统的学习Python。

本期学习内容： 程序控制流程之if条件语句

我们花了十几期的班会把Python里最重要的也是最常见的数据类型都过了一遍。如果说数据类型就像Python语言的单词，那么今天我们将要介绍的程序流程控制就相当于是Python语言的语法，它会将这些数据类型有机的组合，形成有意义的句子，让你的程序能像人脑一样有判断能力，从而帮你去做你想做的事情。换句话说，计算机之所以能做很多自动化任务，也正是因为它自己可以做条件判断。

第一个重要的程序控制流程就是条件语句，也被叫做分支语句。顾名思义，它能通过不同的条件来执行不同的任务。举个例子，我希望设计这么一个程序，让用户输入一个分数，0-100，如果分数大于80，就返回“优秀”，代码就可以这样写:

score = input(“请输入你的分数: ”)
if score > 80:
    print("优秀")

从这段代码我们可以看出来，if条件语句的格式是，第一段 if 后门跟上一个判断条件 score > 80。这个我们在之前的运算符那节班会课上介绍过，这是比较运算，结果是True 或 False。之后跟上一个冒号，然后再另起一段，用四个空格表示缩进，缩进里的语句是属于if的代码段，最后加上符合这个条件后要执行的语句，这里是print。于是，如果score的值大于80，运行程序后你就会看到屏幕输出“优秀”。

在这里要特别强调一下，冒号和缩进可是语法很重要的部分哦，漏了哪一个，程序都会报错的。缩进就是空格，一般我们是四个空格，有缩进的语句表示是上一条语句块的一部分。第一个if千万不要有空格，有的话也会报错，除非它是另一个语句块的一部分。

以上程序，如果score等于或小于80，就没有任何输出。如果你想要让程序在score大于60并且小于80的时候输出良，你可以再写一个if语句，比如:

if score > 60 and score < 80:
    print("良")

我们看到，两个比较运算之间有一个逻辑运算and，它表示，只有and两边的比较运算结果都为True的时候，这整个条件判断结果才是True，才会去执行缩进里面的print语句。

以上的if结构，程序会按从上到下的顺序执行命令，先和80比较，如果大于它就输出“优秀”，然后再去和60还有80比较，如果介于它们之间，就输出“良”。如果都不满足，就啥也不做，跳过if语句，执行其它下面的语句。

if还可以else搭配出现，意思是，如果if语句是False，就不要执行if的内容，而是跳到else里去执行其里面的内容。上面的例子也可以写成这样:

score = input(“请输入你的分数: ”)
if score > 80:
    print("优秀")
else:
    print("良")

这个if-else语句和上面分开的两个if语句，最大的区别就是，一旦开头if条件满足，后面else的条件语句压根就不去执行了。这点大家要注意了。

上面的结果，只要小于80就会输出“良”，如果条件超过了两个，比如，你还想让分数小于60的时候输出“不及格”，这个时候你可以使用if-elif-else的结构，这里的elif是else if的缩写，你想写几个就写几个。比如: 

score = input(“请输入你的分数: ”)
if score >= 80:
    print("优秀")
elif score >= 60 and score <= 80:
    print("良")
elif score <= 60 and score <= 0:
    print("不及格”)
else:
    print(“输入错误！请输入0-100范围”)

这样各个成绩段都有了相应输出，如果if和elif里的条件都不满足的话，就执行else里的内容。

有其他语言经验的同学可能会问，这elif和switch很像啊，那Python里也有swtich语句吗？

原来没有，因为Python的设计理念是简单、刚好够用，elif就够用了，不需要再添加一个相同功能的语句了。不过3.10版本引入了match语句有点像，我们简单介绍一下。

match http_response_status:
    case 400:
        print("Bad request" )
    case 404:
         print( "Not found")
    case 418:
         print( "I'm a teapot")
    case _:
        print "Something's wrong with the internet")

上面是个match语句，根据http_response_status的不同，它会匹配不同的case，从而执行不同的print语句。最后的下划线_，类似else，是个通用匹配符，如果上面的case都不满足，就来这里。

如果一个case里有多个匹配，可以使用“|”在一个模式中组合多个字面值，比如这样:

match http_response_status:
    case 400 403 | 404:
         print("4xx error" )
    case 500 | 501 | 503:
        print "5xx error")

从这两个例子就能看出，match和if最大的区别 ，就是match主要是对字符串的匹配，而if更多的是做条件判断。

以上就是条件判断语句的基本知识。下一期，我们会介绍另一个重要流程控制语句，循环语句。我们下期见！


今日练习:

What will be the output of the following code? 
if 2 == 2.0:
    print('yes')
else:
    print('no')

A : no
B: Python will show an error
C: Nothing will be printed to the output
D: yes


Answer: D
Explanation/Reference:
Python will automatically convert the into into a float, and will then do the comparison.
