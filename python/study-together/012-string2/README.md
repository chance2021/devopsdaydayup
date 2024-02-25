# 组团学Python第12期班会-字符串类型（中）

同学们好！欢迎大家继续我们的第12期每周一三五班会，一起来系统的学习Python。

本期学习内容：数据类型-字符串格式化

上一期班会我们介绍了字符串三种不同类型，它们分别是普通字符串，原始字符串和长字符串。它们被用在不同的使用场景。忘了的同学赶紧回去复习一下吧。

这期我们再来介绍一个非常重要，也是很常见的字符串表示方式:字符串格式化。

上一期我们讲过如果把两个字符串拼接起来，就是直接用+号就好，像这样: '24' + str(4)。这如果字符不多，还好说，但是一旦字符串多了，这么多加号看的眼睛都会花了。那没有更好的方式来展示字符串呢？当然有，这就是字符串格式化方法。

Python里至少有三种常见的字符串格式方法，我们来一一看一下。

C语言风格

第一种格式化方式是基于百分号%语句，它和C语言很像，比如: 'Hello %s' % 'World'。其中 %s是个占位符，表示字符串替代，它的实际值是第二个%后面的World，所以这个语句输出显示的是 Hello World。

除了%s这个占位符，还有%d，表示整数替换，%f，表示替换浮点数。有几个占位符，后面就跟几个变量，并用括号括起来，像这样: 'Hi %s, you have $ %d' % ('Chance', 10),它的输出就是: Hi Chance, you have $10. 这个格式化方式历史最为悠久，不过现在很少人用了，大部分人都使用后两种格式化方式来表示。

format字符串格式化
format是2.6版本后引入的新功能。它的用法比如:'Hello {}'.format('World')。{}里会依次传入format()里的值。不过你也可以指定变量位置，比如: 'This is {1}. That is {0}'.format('first', 'second'),它会输出: This is second. That is first. {0}表示format（）里第一个参数，{1}表示第二个参数。不过这种方式也慢慢的被最后一种格式化方式替代了。


f-string字符串格式化
f-string是3.6版本以后引进的功能，越来越多人更倾向于使用它，这个必须掌握。它最特别的地方就是在{}里表示的是一个变量，比如: name = 'World'; f'Hello {name}'。输出就是Hello World。

format和f-string里还有个格式化控制符的概念大家要了解一下。比如以下表达你知道输出是什么吗？

print('{1}现在有 $ {0:0.2f}'.format(3.6666,'Chance'))

或者

money=3.6666
name='Chance
print(f'{name}现在有 ${money:.2f}')

它们都是输出:

Chance现在有3.66

在format格式化语句中，{0:0.2f}是一个占位符，分号:左边的0代表参数序列，0就是第一个参数，以此类推。分号右边的0.2f是格式控制符，其中f表示float浮点，0.2f表示精确到小数点后两位。

f-string里也是类似，只是分号左边插入的是一个变量money，分号右边的.2f也表示精确到小数点后两位的意思。这个格式化的方法同学们一定要牢记，会很有用。

除了f，格式控制符还包括d（十进制整数），s（字符串），e（科学计数法），o（八进制），x（十六进制），b（二进制）等。具体可以参考廖神的这篇文章: https://www.liaoxuefeng.com/wiki/1016959663602400/1017075323632896

相比于format, f-string 还允许在字符串中嵌入 Python 表达式。使用 f-string，你可以将变量、表达式或函数调用的结果直接插入到字符串中，使得字符串的格式化变得更加简洁和直观。

以下是使用 f-string 的常见用法的总结:

1. 插入变量：
```python
name = "Alice"
age = 30
print(f"My name is {name} and I am {age} years old.")
```

2. 插入表达式：
```python
x = 5
y = 10
print(f"The sum of {x} and {y} is {x + y}.")
```

3. 格式化数字：
```python
pi = 3.14159
print(f"The value of pi is {pi:.2f}.")
```

4. 调用函数：
```python
def greet(name):
    return f"Hello, {name}!"

print(greet("Bob"))
```

以上就是f-string的强大功能，不过有一点format有的它却没有，就是format支持用位置参数来格式化字符串，这可以实现对参数的重复使用，比如:

username='Chance'
score='100'

print('{0}: name={0} score={1}'.format(username, score))
# 输出：
# Chance: name=Chance score=100

所以我们推荐编码中优先使用f-string，然后搭配format作为补充，这基本上能满足同学们绝大部分需求。

这就是我们今天班会的所有内容，下一期班会我们会收尾字符串，介绍一下关于字符串的常见操作。我们下期见！

今日练习:  写一个换算人民币和加元的程序。假设1加元等于5.2。 如果我输入 100，程序应该输出520。如果有小数，精确到小数点后两位就好，比如我输入100.66666，输出应该是523.46，不用考虑四舍五入。



rmb = int(input("Enter the amount of RMB: "))

cad = rmb * 5.2

print(f"That is {cad:.2f}Canadian dollars.")