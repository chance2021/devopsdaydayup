# Azure App Service
这两天我们介绍了Azure两个部署容器化应用很重要的服务：**AKS(Azure Kubernetes Service)**和**ACI(Azure Container Instance)**。如果你更近一步学习了这两个服务的使用之后，你会发现它们有一个共同的特征，就是它们都是用来**部署容器**的。上一篇我们讲到，**容器的本质就是进程，部署容器需要先构建容器镜像(Container Image)**。那么问题来了，作为一个开发人员，编写程序代码是我的天职，但是我要如何把做好的代码变成可以被部署的容器镜像呢？有经验的程序员就会说：“当然是创建Dockerfile，然后`docker build`一下就好啦"。但是你要知道，能说这句话的同学一定是已经对Docker容器比较熟悉的了。那不熟的同学是不是就无法部署ta的程序到Azure上了呢？当然不会啦，Azure还是很贴心的推出了另一个不需要构建容器就能部署你代码的服务：**Azure App Service**。值得注意的是，Azure App Serivce主要是针对**网站应用**场景，包括网站网页本身和一些Web APIs。</br>

老样子，继续再熟悉一下Azure App Service有哪些特性吧
1. **支持许多编程语言**。Azure App Service支持现在市面上流行的大部分语言，比如ASP.NET, ASP.NET Core, Java, Ruby, Node.js, PHP或者Python。你也可以使用PowerShell或其他脚本作为后台服务。
2. 和我们之前说的Bastion VM一样，Azure App Serivce的底层操作系统完全由Azure托管，其中包括系统升级、维护、打补丁等，这些你都不用操心了，安心的写你的代码就好。
3. **支持容器**。如果你想的话，Azure App Service也是可以部署容器的。只是它除了容器，还是可以部署非容器的代码而已，选择更多。
4. 可以手动或自动**扩展性能**，保证你网站的高可用性。
5. 你可以和主流的SaaS平台（比如SAP/Salesforce)和本地数据相连。
6. **安全**，符合ISO, SOC, PCI等标准。
7. **认证方便**。你可以使用AAD, Google, Facebook, Twitter(X?)等你经常使用的认证平台来做你的应用认证。
8. **模版多**。你可以到Azure Marketplace里找到各种你可能会需要的模版，比如WordPress, Joomla, Drupal.
9. 最后值得一提的是在万能的**VSCode也有很好的插件支持**
  