# App Service Plan
上一篇我们介绍了**Azure App Service**，我们知道程序员们除了使用AKS,ACI之外，还可以通过Azure App Service在不使用容器技术的前提下部署自己的网站到Azure上。今天我们会延续App Service的话题，来讲讲实现App Service需要涉及到的另一个重要概念，就是：**App Service Plan**。</br>
简单来说，App Service Plan主要是定义了**一整套实现Azure App Service这个技术的计算资源**，比如说运行它的VM或Container。每次你创建一个App Service的时候，你都必须指定具体的App Service Plan来实施你的App Service部署。这个App Service Plan定义了以下一些资源：
1. 你所要使用的**操作系统**（Windows或Linux)
2. 资源所处的地区(**Region**)。这个对一些对数据归属地敏感的企业很重要。
3. 所需的**VM**(虚拟机)台数
4. VM(虚拟机)**大小**（Small, Medium, Large)
5. **价格等级**

关于价格等级（Pricing tier)，我们可以来展开一下说说。Azure App Service Plan分为了以下这么些不同的等级：
1. **Shared Compute(共享计算资源)**：其中包括Free(免费)和Shared(共享)。这两个属于最基础的等级，它们会和其他不同用户部署的应用共同分享相同的Azure VM资源。 在这个等级里，Azure会给每一个应用程序分配CPU配额，大家一起共享资源。值得注意的是，这个等级的资源**无法扩展**。如果你的计算量太大，服务就容易挂了。所以这个等级只适合程序员自己开发和测试使用，千万不要用到生产环境了。
2. **Dedicated Compute(专用计算资源)**：这个等级有这么几类划分，分别是**Basic, Standard, Premium, PremiumV2和PremiumV3** 等级。这个等级里，你部署上去的应用会在你自己专门的Azure VMs里运行，不用和其他用户去争抢资源了，只有你自己部署的应用之间才共享资源。等级越高，背后拥有的VM数量越多，并且在你资源不足的时候可以扩展资源。
3. **Isolated(隔离计算资源)**：这是三个等级里最高等级，它除了和上一个等级一样让应用程序运行在自己专用的VM上，还拥有自己**专门的网络**，可以把你的计算资源进行隔离。并且性能的拓展也是最好了，属于钻石级别的会员待遇。这个等级还有一个独有的服务，叫做**App Service Environment**。具体不展开了，以后做实验的时候再说吧。

除了上面这些等级之间不同差异之外，每一个等级都提供一些不同服务，其中包裹**自定义域名，TLS/SSL证书，自动扩展性能，Deploymetn Slots, 容灾备份，Traffic Manager Intergration**等等。等级越高，能享有的服务越多。具体请参考微软官网文档吧。</br>

最后提一下，一开始你不需要纠结选择购买哪个等级,因为你随时都可以切换不同的等级。所以最好的方法是，当你不太熟悉你的需求大小的时候，可以从Free开始，然后如果当前等级满足不了你，你再慢慢向上升级，直到找到符合你需求的等级就好啦。


