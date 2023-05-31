# mkdir (make directory): 创建一个新的目录
前几篇我们学习了如何在Linux里“逛街”，浏览文件系统里的文件。这一篇我们来看看如何在Linux里创建一个文件夹。<br> 

## 使用方法
`mkdir <foler_name>`

在Linux创建文件夹只需要输入`mkdir`然后跟上文件夹名称就好。如果没有带上文件完整路径，那就会在当前文件夹下创建一个新的文件夹。

## 常见参数
`-p`: 自动帮你建立多层目录 <br>
`-m`: 强制设定文件夹属性 <br>
`-v`: 打印文件名 <br>

## 使用场景
1. 如果你想建立多层文件夹，且其中有些**文件夹并不存在**，那么必须使用`-p`参数，比如
```
mkdir devops/lesson1/lab1/img
mkdir: cannot create directory ‘devops/lesson1/lab1/img’: No such file or directory

# 这时候你就需要加上-p 来帮你自动建立多层目录...
/tmp$ mkdir -p devops/lesson1/lab1/img;cd $_
osboxes@osboxes:/tmp/devops/lesson1/lab1/img$
``` 
复习一下， `cd $_` 意思是把前一个命令里的路径（mkdir 后的 路径）作为下一个命令（cd）的输入。<br>

2. 如果你想要让新建的文件**强制设定属性**，你可以使用`-m`参数，比如
```
$ mkdir -m777 newfolder
bash-3.2$ ls -trl
drwxrwxrwx  2 chance  wheel  64 31 May 08:44 newfolder
```
3. 默认情况下如果文件夹创建成功系统是不会有任何反馈的（毕竟**在Unix系统里，没有消息就是最好的消息**）。但是如果你想让系统返回一些啥，你可以带上`-v`这个参数，**系统就会返回文件夹的名字**了。
```
bash-3.2$ mkdir newfolder01
bash-3.2$ mkdir -v newfolder02
newfolder02
```
