# DNS
上一篇说到IP，我们知道了在网络中我们是通过IP地址来访问我们想要的网站。但是可惜的是人类的大脑对这一连串没有意义的数字还是不容易记住的,除非你拥有最强大脑。这就好像我们日常生活中越来越少去记别人的电话号码了，都是使用电话簿，通过人名来查找对方的电话号码。在访问网站的时候，www.google.ca 肯定比142.251.32.67要来的好记。于是乎，人们就设计出了一套属于IP的“电话簿，它就是DNS。</br>

DNS是**Domain Name System**（域名系统)的缩写，它的数据库里面记录的就是IP和域名的对应关系。所谓域名(Domain)，就是我们日常打开浏览器输入的网站地址，比如www.google.ca。再加上开头的https:// 和结尾可能的path,就组成了我们经常听到的URL(Uniform Resource Locators)。在网络的世界里，路由器们是不知道www.google.ca到底是什么意思的。于是浏览器通过DNS服务器查询到了这个域名地址对应的IP地址，然后你的浏览器再通过这个IP地址去访问相应的网站资源。</br>

DNS服务器有大致有四种类型的服务器，它们分别是**Recursive DNS Server**, **Root Name Server**, **Top Leave Domain (TLD) Server**，和**Authoritative Nameserver**。现在，我们通过分析浏览器访问网站时DNS运作的全过程，来看看这四类服务器分别在其中扮演了什么样的角色。</br>

打开浏览器，输入www.google.ca，点击回车，你的浏览器首先会查询浏览器内部的DNS缓存，看看是否能找到相关记录；如果找不到，它会把这个指令发给你的操作系统，如果你是Linux系统，那系统就会查询/etc/hosts这个文件里是否有相关记录；如果这也找不到，这条指令就会从你的操作系统发向网络，发到你系统指定或者你所在的互联网运行商指定的DNS服务器，你的请求到达的第一个服务器就是**Recursive DNS Server**。这台服务器将扮演你和其他DNS服务器通信的中间人，以后所有的请求它都会帮你处理或转发。如果这台服务器的缓存里也没有相关信息，它就会把你的请求发给**Root Name Server**。Root Name Server会根据你请求域名的最后一段，比如.com或.cn，然后转发给对应的**TLD (Top Level Domain) nameserver**，TLD nameserver就会把你指向请求的最后一站：**Authoritative Nameserver**。这是你请求能到达的终点站，如果还没有相关信息，服务器就会返回查无此域名的错误，结束你的请求。以上就是一个DNS请求所要经历的全部步骤了。</br>

DNS服务器除了记录域名和IP地址的对应关系，其实还有其他很多类型的记录，最后我们就来介绍一下DNS数据库里一些常见的DNS记录(record)吧。
- **A**: 这个记录就是DNS里记录域名和IP地址的记录，并且它特指IPv4
- **AAAA**: 这个是IPv6的记录
- **PTR**：pointer record 这类记录是A record的反向，它存储的是从IP到域名的记录。这个在看Logging的时候很好用，因为大部分日志都是记录IP地址，而不是域名。你就可以通过PRT记录来看看这个IP对应的域名是什么。
- **CNAME**: canonical name record 这类型的DNS记录里没有IP地址，有的是另一个域名。访问这个域名的请求会被转发到另一个指定域名。这有个好处，就是哪怕它指定的域名的IP变了，它也不用变，只要被指到的域名地址本身不变就好。
- **MX**: 这个地址专门指向Email服务器。你发送邮件的时候会根据这类型的DNS地址去发送。
- **NS**: 它指向的是DNS服务器。有些云服务厂商有指定的DNS服务器，所以你的域名就可以通过这个记录来指定。
- **SOA**: star of authority record 这类DNS记录比较特殊，它记录的是一些和DNS管理员相关的信息，比如管理员的Email, 上次域名更新的时间，每一次DNS更新需要间隔多久，等等。
- **SRV**：service record 这是给一些比较特殊的服务提供的DNS记录，比如VoIP，即时消息(Instant Messaging)。它指向的不知是IP，还包括端口(Port)。

更多详细信息，推荐大家去Cloudflare网站看看：https://developers.cloudflare.com/learning-paths/dns-filtering/concepts/what-is-dns/#what-is-dns

其他所有Azure知识点，请查看：https://github.com/chance2021/devopsdaydayup/blob/main/cloud/azure/README.md