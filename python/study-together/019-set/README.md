# 组团学Python第19期班会-集合

同学们好！欢迎大家参加我们的第19期每周一三五班会，一起来系统的学习Python。

本期学习内容： 集合（set）

上期我们介绍了第二类容器类型，元组。知道了，元组和列表就好像双胞胎一样，它们基本相同，唯二的区别，一个是元组的表达方式，用的是小括号，而不是列表的中括号，第二个就是元组是不可变的，所以无法使用列表用的增删改方法。

细心的同学可能就会注意到，小括号已经被用了，中括号也被用了，那同学就会猜测，大括号是不是也有被什么数据类型征用了呢？

聪明！确实，有这么一种数据类型就是使用了大括号来整理它的元素们，它就是集合（set）。

啥是集合呢？集合就是一种可迭代、可变的、无序、不包含重复元素的容器数据类型。这里有四个关键字要明确:“可迭代”，“可变的”，“无序”和“不包含重复元素”。我们一一来看一下。

可迭代

我们先来介绍一下如何创建集合吧。作为和列表与元组一样的可迭代类型，它的创建方式也类似，可以直接定义一个变量，然后赋值一个由大括号括起来并且由逗号分割开的元素。比如:

names = {'lily', 'tom', 'adam'}

或者你也可以使用set（）函数来把一些其他的数据类型转换为集合，比如:

a = set('hello')
print(a)

输出就是:
{'h', 'e', 'l', 'l', 'o'}

可变的

如果这个数据类型可变，我们就知道它一定有增删改的方法。在集合里，增添一个元素使用的方法是add，比如:

names = {'lily', 'tom', 'adam'}
names.add('chance')
print(names)

输出就是

{'lily', 'tom', 'adam', 'chance'}

删除的话也很简单，使用remove()方法就好，比如:

names = {'lily', 'tom', 'adam'}
names.remove('tom')
print(names)

输出就是

{'lily', 'adam'}

在以上两个增删例子里，不知道大家有没有注意到，我们在介绍add()方法的时候，既没说这个元素是被添加到最后，也没在add()方法里添加索引。这个就引出了集合和之前我们介绍的序列数据类型最大的一个区别:无序。集合是无序的，它里面的元素是没有顺序的，换句话说，就是没有索引。

无序有这么几个好处：

1. 快速查找和成员检查：由于集合是无序的，Python 使用哈希表实现集合，这使得查找和成员检查的速度非常快。无序性意味着在查找特定元素时不需要遍历整个集合，而是通过哈希函数直接找到其对应的位置。

2. 数学操作：无序性使得集合可以很方便地进行数学上的操作，如并集、交集、差集等。

3. 内存优化: 由于集合是无序的，它们通常在内存中的布局更加紧凑，这意味着对于大型数据集，使用集合可能比列表更节省内存。

第4个一个好处，就要提到我们的第四个关键词了: 不包含重复的元素。集合中的元素是唯一的，这意味着你可以确保在集合中不会出现重复的元素，这在处理需要唯一值的情况下非常有用。你可以试试看使用add方法加一个已有的元素，系统不会报错，但是输出的时候这个元素只会输出一个。

总的来说，集合的无序性使得它们成为处理唯一值和快速成员检查的理想选择，并且在许多情况下可以提供更好的性能。

哦，对了，上面提到了哈希表，这个技术大家可能偶尔也听到过，我们这里来简要的介绍一下什么是哈希吧。

哈希（Hash）是将任意长度的输入通过哈希函数（Hash Function）转换成固定长度的输出的过程。哈希函数通常会将输入映射到一个较小的固定长度的值，该值通常称为哈希值。

在Python中，集合和字典（下期班会会介绍）使用哈希表来实现。哈希表是一种数据结构，可以快速地插入、删除和查找数据。它通过将键(key 是字典的概念)的哈希值映射到内部数组中的位置来实现快速访问。当你使用集合或字典时，Python会计算每个元素的哈希值，并使用哈希值来确定元素在内部数据结构中的位置。

哈希表的效率很高，因为它允许在接近常量时间内执行插入、删除和查找操作。这是因为哈希函数将键映射到数组索引，使得在大多数情况下，只需一次哈希函数调用即可定位到元素的位置。因此，使用哈希值处理可以提高数据操作的速度，尤其是对于大型数据集来说。

以上就是关于集合的增删改方法，最后我们来介绍一下一个集合常用的运算。

关于运算，我们很早期的班会介绍了多种运算，包括赋值运算，算式运算，比较运算等等。在集合里，最常用的运算是成员运算，就是看看某个元素在集合里是否存在，比如:

names = {'lily', 'tom', 'adam'}
print('lily' in names)
print('chance' in names)

输出是
True
False

True说这个值在这个集合里有，而False是说这个值在这个集合里不存在。

那以上就是关于集合的一些重要知识点。下期班会我们会扫尾最后一个重要的数据类型:字典。我们下期再见！


今日练习:
# What will be the output of the following code snippet?

my_set = {1, 2, 3, 4, 5}
my_set.add(5)
my_set.add(6)
my_set.remove(3)

print(len(my_set))


A) 4  
B) 5  
C) 6  
D) Error: 'set' object has no attribute 'remove'

答案是 B) 5

Explanation:
- Initially, the set `my_set` contains elements: {1, 2, 3, 4, 5}.
- The `add()` method is used to add elements to the set. Since sets do not allow duplicate elements, when `my_set.add(5)` is called, it does not change the set because 5 is already present.
- Then `my_set.add(6)` is called, adding 6 to the set. Now `my_set` contains elements: {1, 2, 3, 4, 5, 6}.
- The `remove()` method is used to remove an element from the set. So `my_set.remove(3)` removes 3 from the set. Now `my_set` contains elements: {1, 2, 4, 5, 6}.
- Finally, `len(my_set)` returns the number of elements in the set, which is 5.