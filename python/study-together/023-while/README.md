# 组团学Python第23期-while循环语句

同学们好！欢迎大家参加我们的第23期每周一三五班会，一起来系统的学习Python。

本期学习内容： 程序控制流程之while循环语句

上一期我们介绍了循环语句里的for循环，知道了它就是那个可以帮我们遍历容器数据类型里所有元素的好帮手。但有些时候我们的程序可能并不知道具体有多少个循环要做，比如，我希望写一个程序，随时待命接收用户的输入，直到用户输入q之后才结束该程序，这时候用for就不好用了，因为理论上，只要我不输q，这就是个无限循环。这时候另一个循环语句while循环就可以粉墨登场啦！

总的来说，while是一个可以一直运行的循环语句，直至指定的条件不满足为止。举个例子:

current_number = 1
while current_number <= 5:
    print(current_number)
    current_number += 1


上面这段程序里，只要current_number小于或等于5，那while里面的语句就会一直执行，也就是先打印current_number，然后在给current_number自身加1。当current_number=6的时候，此时已经不满足current_number<=5的条件，while循环就结束了，然后程序继续while之后的语句，如果没有其他语句，就结束程序。

以上就是while的简单用法，以后我们做题的时候会再细讲。

接下来我们复习一下退出循环的方式，break，先看看这个例子:

prompt = "\nPlease enter the name of a city you have visited:"
prompt += "\n(Enter 'quit' when you are finished.) "

while True:
      city = input(prompt)
      if city == 'quit':
          break
      else:
          print(f"I'd love to go to {city.title()}!")

while True 这是个无限循环，因为True永远为True。如果要终止这个循环，只有通过break，让程序不再运行while里余下的代码，无论条件测试的结果如何。

但有时候，我们可能并不想完全退出这个while循环，只想跳过当前这次循环，那用break显然不合适。这时候就可以使用continue。看这个例子:

current_number = 0
  while current_number < 10:
      current_number += 1
      if current_number % 2 == 0:
          continue
      print(current_number)

上面if语句表示，如果current_number能被2整出，就跳过该循环，不执行后面的print语句，然后接着进行终止条件的判断，以决定是否继续循环。所以以上输出就是:

1
3
5
7
9

如果把上面的continue换成break，输出就只有1了。

再次提醒，break和continue一定不要滥用，因为这样会很容易造成代码执行逻辑分叉太多，容易出错。廖神的这篇文章可以看看: https://www.liaoxuefeng.com/wiki/1016959663602400/1017100774566304

看完了跳转语句break和continue，我们再来看一个以前讲if判断语句也遇到过的朋友: else。先看看这个例子:

count = 0
while count < 5:
    print(count, " 小于 5")
    count += 1
else:
    print(count, " 不再小于 5")

如果很熟悉if-else的同学很有可能会误认为这里的else是当while 后面count不小于5的时候才被执行。额，怎么说能，对，又不对。对的是，else子语句确实是在while正常结束的时候才被执行。不对的是，你得注意前面说的这个定语“正常结束”，就是说，如果里面有个break，非正常结束的话，那else子语句就不会被执行。

我们不推荐在循环语句里使用else，包括for和while，因为很容易让人混淆。这里提一下，只是让大家知道有这么个用法，有可能大家在读其他人的代码的时候会遇到，知道是什么意思就好了。

关于while循环我们就简单介绍到这里，以后做练习用到时候我们在展开讲吧。本期班会就到这里，我们下期再见！


今日练习:

What will happen after the following code is executed?
counter = 1
while counter < 10:
    print('x')
A. Python will print 'x' 10 times.
B. Python will show an error
C. Python will print 'x' for infinity.
D. Python will print 'x' 9 times.


Answer: C
Explanation/Reference:
The counter's value is never increased, so it will be equal to 1 all the time. This means that the loop condition will be satisfied forever.