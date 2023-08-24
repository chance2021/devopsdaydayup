# AVS - Azure VMware Solution
对于很多政府部门或者国营企业，它们可能对安全有非常高的要求。这也导致公有云在这样的部门或企业里也很难被推广。关注安全的公司纷纷都转向了私有云的建设。然而构建自己的私有云成本相当的高，没有实力的公司压根要不起。并且维护私有云的成本也比公有云高的多的多。那有没有这么一个解决方案，既可以让企业享受类似公有云的便利，又能拥有私有云的安全呢？秉承着什么钱都必须争取赚的原则，Azure不出意外的也提供了这样一套解决方案，它就是：**Azure VMware Solution**. </br>

看名字就知道，这是一个结合了VMware虚拟技术搭建的Azure服务。Azure VMware解决方案提供包含基于专用Bare Metal的物理服务器上的Azure基础架构构建的VMware vSphere集群的私有云。Azure VMware解决方案在Azure商业版和Azure政府版中都有提供。最小的初始部署是三个主机，但可以添加更多的主机，最多每个集群可添加16个主机。所有配置的私有云都配备有VMware vCenter Server、VMware vSAN、VMware vSphere和VMware NSX-T Data Center。因此，你可以将工作负载从本地环境迁移到这些私有云中，部署新的虚拟机（VM），并从你的私有云中使用Azure服务。</br>

目前AVS(Azure VMware Solution)的机型有AV36, AV36P, AV52。 具体的性能参数可以参考官网。鉴于并非所有的人都有机会接触AVS服务（包括我自己），我就不过多介绍了(关键我也不懂啊)。看完这篇文章，知道有这么一个技术，就够了。