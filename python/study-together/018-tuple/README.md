# 组团学Python第18期班会-元组

同学们好！欢迎大家参加我们的第18期每周一三五班会，一起来系统的学习Python。

本期学习内容： 元组（tuple）

上两期我们简单的介绍了列表（list），这期我们要介绍的元组更简单，基本上除了表达形式和列表略有不同之外，还有就是它是不可变的（immutable）数据类型。其它基本就和列表一样了。我们来具体看看它们的具体区别吧。

在表达形式上，不同于列表的中括号，元组用的是小括号来把元素包起来，元素之间也是用了逗号隔开，比如:

names = ('lily', 'victor', 'adam')

这里有个细节很多同学可能没有注意到，其实这个小括号是可以省略的，以上例子你这样写Python也认:

names = 'lily', 'victor', 'adam'

只是为了方便大家阅读，加上小括号以示区分。但值得注意的是，如果只有一个元素，那必须在最后加上一个逗号，比如:

names = ('lily',)

如果你写成 names = ('lily') ，Python会把它看成字符串而非元组，这点要注意一下。

第二个元组区别于列表的重要特征，就是元组是不可变的（immutable）数据类型。比如下面这个写法系统就会报错:

names = ('lily', 'victor', 'adam')
names[0] = 'chance'

运行后你就会看到如下报错:
TypeError: 'tuple' object does not support item assignment

这个特点也使得元组在内存里的存储空间明显小于列表，因为列表的可变是需要付出额外的内存代价的。因此如果你的变量不需要变化的话，请使用元组而不是列表，这将大大提升你程序的运行效率并减小存储空间。

但有些时候，人算不如天算，你一开始认为的不变，后来也有可能不得不变，那这种情况下，是不是就完全没办法改变元组里的元素了呢？ 答案是，是的:) 不过通常这种情况下人们的做法是重新定义一个元组，比如
，还是上面的例子，我想把第一个元素改成chance，那你可以这样做:

names = ('chance, 'victor', 'adam')

这基本上就是重新给变量赋值了。或者你也可以使用list()函数把元组转换成列表，修改完后再使用tuple()转换为元组。但本质上这和重新创建一个元组差不多了。

所以你在定义变量的时候一定得想清楚，这个变量里的值到底会不会经常变，会就用列表，不会才用元组。

理解了元组的不可变，那我们也能理解，为什么原本适用于列表的append，extend，insert，remove，pop等方法在元组里不奏效了，不可变的意思就是无法增删改呀！

最后关于元组，我们来介绍两个黑话:打包和拆包。

创建元组，并将多个数据放到元组中，这个过程称为元组打包。

相反的过程，将元组里的元素取出来，分别赋值给不同的变量，这个过程就叫做元组拆包。

以上就是关于元组你必须知道的事，不多，等以后做练习遇到了再慢慢展开吧。

今天的班会很短，大家早点休息吧。下期班会见！

今日练习:
What will be the output after running the following code?
tuple_first = (1, 2)
tuple_second = ('a', 'b', 3)
tuple_third = tuple _first + tuple_second * 2
print(tuple_third)
A. ('la', '2b', 6)
B. Python will show an error
C. (1, 2, 3, 'a', 'a', 'b', 'b', 6)
D. (1, 2, 'a', 'b', 3, 'a', 'b', 3)


Answer: D
Explanation/Reference:
The third tuple is the sum of the first two tuples. The second tuple is multiplied by 2, which means the elements will be repeated. The second tuple will therefore become ('a', 'b', 3, 'a', 'b', 3). Combined with the first tuple, we'll get: (1, 2, 'a',
'b', 3, a, 'b', 3).