# 组团学Python第17期班会-列表（下）

同学们好！欢迎大家参加我们的第17期每周一三五班会，一起来系统的学习Python。

本期学习内容： 列表（list）常见操作

上一期班会我们简单介绍了一下什么是列表。这里再复习一下，列表是可变的序列类型，它是由一系列按照特定顺序排列的元素所组成的容器。它的表示方式是用中括号把所有元素都括起来，然后用逗号分割各个元素。班会的最后我们还插播了一条冷知识，就是Python中方法和函数的区别，忘了的同学赶紧回去复习一下吧。

那今天这期班会我们就继续介绍一下列表常见的增删改操作以及函数类型吧。

增

列表里添加元素最简单的方法就是append（新元素），它会在列表最后加入一个元素，比如

names = ['lily', 'victor', 'adam']
names.append("chance")
print(names)

输出就是
['lily', 'victor', 'adam', 'chance']

那如果我想在开头或者任何一个中间位置插入元素要怎么办？另一个叫做insert的方法就派上了用场。insert的用法是:list.insert(索引，元素)，比如

names = ['lily', 'victor', 'adam']
names.insert(0, "chance")
print(names)

输出是
['chance', 'lily', 'victor', 'adam']

这样就能在第一个位置插入一个新的元素啦。

这里留个思考题，你能否用insert在最后一个位置添加元素呢？

还有一个添加的方法也得提一下，就是extend。很多人会把append和extend混起来，虽然它们很像，都是往列表最后插入元素，但它们还是有不一样的。它俩最大的区别，就是append是添加单个元素，而extend会把可迭代对象的所有元素都添加了。用个例子来解释一下这是什么意思:


my_list = [1, 2, 3]
nested_list = [4, 5, 6]
my_list.append(nested_list)
print(my_list)  

它的输出是：[1, 2, 3, [4, 5, 6]]

注意最后一个元素[4, 5, 6]是一个整体哦，单独一个列表。那再看看extend:

my_list = [1, 2, 3]
nested_list = [4, 5, 6]
my_list.extend(nested_list)
print(my_list)  # 输出：[1, 2, 3, 4, 5, 6]


我们可以看到和append不同，extend是把一个一个元素从列表里提出来再分别插入进主列表里的。


删

最后我们来介绍一下列表里如何删除元素。最常见的删除方法是del语句。比如:

names = ['lily', 'victor', 'adam']
del names[0]
print(names)

输出是
['victor', 'adam']

我们可以看到第一个元素lily就被删除了。

如果你漏了下标，写成了del names，很不幸，整个列表都被删除了，要注意呀！

有时候我们不仅是要删除，还想要取出这个删除的元素，方便把它打印出来，毕竟按索引删除要是删错了咋办，得看到具体删除了啥心里才放心啊。这时候你就可以使用pop方法来同时完成这两件事。比如:

names = ['lily', 'victor', 'adam']
removed_name = names.pop(0)
print(f"{removed_name} 被删除了！")

输出是
lily 被删除了！

值得注意的是，如果pop()里不带索引，那最后一个元素就会被弹射出来删除。这个功能以后我们做队列和栈的时候会用到，这里知道一下就好。

如果你感觉用索引删除还是太麻烦了，最后还有一个杀手锏方法，可以让你所见即所删，它就是remove。还是上面的例子:

names = ['lily', 'victor', 'adam']
removed_name = "lily"
names.remove(removed_name)
print(names)

输出是
['victor', 'adam']

需要注意的是，remove方法只删除第一个遇到的匹配元素，如果你的列表里同样的值有好多个，你想把它们都删除了，这就必须使用循环，这个以后讲到for的时候再说吧。

接下来我们来介绍几个列表里常用的方法或函数。

list.sort()

第一个是sort（），它能对列表进行永久的排序。比如:

names = ['lily', 'victor', 'adam']
names.sort()
print(names)

输出是
['adam', 'lily', 'victor']

我们可以看到列表已经被改变了，它里面的元素按照字母顺序进行了排序。

如果你想按照字母相反顺序排序，这个方法也支持，只要你传递reverse=True就可以了，比如:

names = ['lily', 'victor', 'adam']
names.sort(reverse=True)
print(names)

输出是
['victor', 'lily', 'adam']

sorted()
上面这个方法其实有一个问题，就是如果你不想改变列表本身的元素怎么办？好办，用sorted函数就好，你可以这样写:

names = ['lily', 'victor', 'adam']
print(sorted(names))
print(names)

输出是
['adam', 'lily', 'victor']
['lily', 'victor', 'adam']

我们可以看到原来的列表names在被sorted函数处理后本身的元素顺序其实是不变的。对了，这函数也支持倒序，只要加入reverse=True就要，这里就不多举例子了，大家自己试试吧。

list.reverse()
还有一个方法我们也会使用到，就是倒着打印列表。我们可以使用reverse方法来达到目的。比如:

names = ['lily', 'victor', 'adam']
names.reverse()
print(names)

输出是

['adam', 'victor', 'lily']

记得这个方法也会改变列表本身哦。

len(list)
最后还有一个常用的操作，就是计算列表长度，也就是列表里元素的个数，这里我们用len（）这个函数，比如:

names = ['lily', 'victor', 'adam']
print(len(names))

输出是
3

以后我们学习for循环时候会经常使用。

list.count()
我们前几期有个课后练习，就是统计一篇英文文章里的单词个数。这个放在一些其它语言，也许你需要写很多代码。但是贴心的Python直接给你一个好用的方法count()，一键搞定！例如:

a = 'hello'
print(a.count('l'))

输出就是2，表示hello里有2个l。

list.max() 和 list.min()

最后介绍两个方法，它可以帮助你找到列表里最大或最小的数，如果列表里不是可以比较大小的数字，比如字符串，这两个方法就会比较字符串第一个字符在标准字符编码表的顺序，比如z是字母里排序最大的，大写比小写排序更大。举个例子；

my_list = ['apple', 'banana', 'orange']
max_value = max(my_list)
print(max_value)  # 输出: 'orange'
min_value = min(my_list)
print(min_value)  # 输出: 'apple'

关于列表的操作还有很多，等以后我们遇到了再慢慢细讲吧。以上就是一些关于列表的基础知识，也是我们这期班会的全部内容。我们下期见！

今日练习:

What will be the sum of all elements in the list after the following operations?
numbers = [0, 1, 2]
numbers.insert(0, 1)
del numbers[1]
A. 0
B. 4
C. 3
D. 5


B

Explanation/Reference:
First: [0, 1, 21
After insert: [1, 0, 1, 2]
After deletion: [1, 1, 2]