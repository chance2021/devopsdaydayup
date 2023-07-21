# Azure Bastion
昨天我们介绍了Azure Virtual Machine，一般当你部署完一个VM，你可能会使用**SSH**或**RDP**的方式来从你本地远程登入，然后才能开始使用这台新建的VM。这种情况下，你必须让你的Azure VM拥有的一个**公网IP**你才有可能够访问的到。这时候，你就是将你的VM暴露在公网下，这样会很容易受到黑客的网络攻击。于是乎你就会需要设置非常多的屏障，比如防火墙或Network Security Group之类的办法来防止VM被攻破。如果你只有一台VM，那还好，但是如果你有一百台的话，那设置起来就非常麻烦了。一般很多公司的做法可能是，先让所有VM都创建在一个私有局域网里，不对外公开，然后在这个私有局域网里接入一台可以连公网的电脑。所有的流量都得先通过这台联公网的电脑之后，再登入到局域网里的VM。这台电脑我们通常叫它跳板机(Jumper Machine)或堡垒机(Bastion Machine)。这大大减轻了管理员的工作量，只需要维护一台电脑。除此之外，Azure还提供了一个更方便且安全的方式，就是Azure Bastion。</br>

那么Azure Bastion和我们自己创建一个Bastion Machine有什么区别呢？首先你**不需要维护这个Azure Bastion**。你只要在Portal上选择创建一个Azure Bastion之后，背后Azure会为创建相应的计算资源，并且帮你维护，这个维护包括系统更新打补丁之类的运维工作。其次，Azure Bastion允许你**通过浏览器来访问在私有局域网里的VM**。对的，用浏览器。一般我们连接VM，可能需要通过本地的Terminal，然后通过SSH,或则本地的RDP remote client连接。但是Azure Bastion,你只要登入Azure portal，可以直接把浏览器当做Terminal来用，非常方便。其次，因为是通过浏览器访问，所以你会使用到TLS协议加密传输，而不是SSH/RDP网络协议，这就非常高的增加了传输安全（尤其是RDP协议，漏洞很多，很不安全）。你访问VM的所有流量都会被TLS在网络上加密传输。总结一下，**维护简单，访问安全**，可以作为Azure Bastion的两个最重要的产品亮点。</br>

Azure Bastion从一开始创建的时候就开始收费，之后如果有向外流出的流量(outbouding traffic)，会额外计费。Azure Bastion有两个等级，一个是**Basic**，一个**Standard**， Standard标准比Basic贵，它包含所有Basic有的功能，然后再加上这些额外功能：有分享链接可以用，有专门的应用软件可以用来连接VMs,可以扩展，可以下载东西等等。</br>

最后我们来描述一下使用Azure Bastion后用户的访问流程。首先用户通过浏览器登入Azure portal，验证完身份之后，打开相应的Azure Bastion。在Azure Bastion中你可以选择你要链接的VM，并且选择是用过SSH方式还是通过RDP方式连接。然后你浏览器里的所有动作，包括输入命令或者鼠标移动，这些信息都会被你本地的浏览器通过TLS加密，通过Internet，最终到达Azure Bastion的443端口，然后Azure Bastion把这些流量转发到后端对应的VM的22或3389端口。这样你就完成了一次和VM亲切交流了。如果好奇这个背后是如何实现的同学，可以参考Apache的一款开源产品**Guacamole**，它的原理和Azure Bastion很像。

## 【Reference】
[Azure Bastion](https://learn.microsoft.com/en-us/azure/bastion/bastion-overview)