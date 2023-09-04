# Azure Virtual Network
我们前面花了大约两周多的时间终于大致过了一遍Azure Compute部分。我们说，电脑之所以强大，不仅是因为它单台电脑的计算性能，更重要的是，它可以通过网络手段，将无数台电脑相连。你的手上的电脑可以计算能力一般，但是只要你能让你的电脑加入互联网，你就能像使用自来水一样使用来自网络的强大算力。这也是云为什么强大的其中一个非常重要的因素。从这篇开始，我们就来介绍一下Azure下的虚拟网络(Virtual Network)。</br>

**Azure Virtual Network是一项提供Azure中私有网络的基础构建模块的服务，它使许多类型的Azure资源(包括VMs)能够安全地相互通信，无论它是在互联网，还是在本地的局域网里。** Azure Virtual Network本质上和我们传统的网络基本是一样的，唯一的区别是，它会再针对Azure自身的资源和架构来提供更具特色的网络服务，包括规模扩展，可用性和隔离。这些功能在我们之后的学习中将会一一介绍。 </br>

作为Azure基础设施中非常重要的一个概念，我们会在以下这些场景里使用到Azure Virtual Network这个服务：

- Azure资源和互联网之间的网络通讯(通过Public IP address, NAT gateway, 或者Public Load Balancer)
- Azure资源内部自己之间的网络通讯(三种通讯形式：Virtual Network, 同一个Region的Vitrual Network Service Endpoint和不同Region甚至不同Subscription下的Vritual Network Peering)
- Azure资源和本地数据中心里的资源的网络通讯(通过Point-to-site virtual private network [VPN], Site-to-site VPN和Azure ExpressRoute)
- 过滤网络流量(你可以通过这两种方式过滤不同Subnet之间的流量：Network security groups和Network virtual appliances)
- 设定网络流量的路由(可以使用任意一种或两种同时使用: Route tables和Border gateway protocol [BGP] routes)
- 和一些Azure服务集成(比如特定的PaaS服务，像是HDInsight, Batch, App Service, RedisCache等，还有Azure Private Link和Service Endpoint，这些之后会介绍)。

最后几个关于Azure Virtual Network的知识点我们再提一下：
1. Azure Virtual Network是一款免费的服务
2. Azure Virtual Network和Subnet在同一个区域(region)里跨越了所有可用性区域(availability zones)。换句话说，当你配置了VM的时候，你可以不用考虑Virtual Network的可用性区域(availability zones)。
3. 同一个Subscription的同一个Region的网络是有一定限制的，比如说，Vritual Networks数量不能超过1000，每个VNet的Subnets数量不能超过3000， 每一个VNet的Peerings不能超过500，每个VNet的VPN Gateway只能有一个，ExpressRoute gateway也只能有一个，DNS服务器不能超过20个， Network Security Groups不能超过5000个等等，具体详情请参见：https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#networking-limits。 不过这些上限是可以调的，你只要开一个工单给Azure客服，它们会帮你处理。
4. 创建一个VNet的第一步就是要申请Address Space，比如10.0.0.0/16，这样之后在这VNet里的VM的私网地址就在这个范围里面了。
5. Subnet子网的划分很重要，每个公司必须通过自己实际情况划分，不同的子网段之间是通过Network Security Groups来做过滤，所以我们一般会把相同特性的网络资源放在同一个子网段里，比如同一个部门或者同一类资源等等。还有，一定要确保不要重复使用IP，以免造成IP冲突。也不要把一个VNet全部给一个Subnet，这样很低效。
6. VNet的范围是限制在Region里，但是不同的Region里的VNet可以通过VNet Peering的功能相互通讯。



