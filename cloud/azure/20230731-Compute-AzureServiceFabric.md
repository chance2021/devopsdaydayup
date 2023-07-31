# Azure Service Fabric
Google出品的Kubernetes已经在微服务领域家喻户晓，基本上可以说算的上是容器部署平台的事实标准。然而很多人却不太知道的是，微软其实也有它自己的微服务部署平台，这个平台支持着微软上许多明星产品，其中包括Azure SQL Database, Azure Costmos DB, Cortana, Microsoft Power BI, Microsoft Intune, Azure Event Hubs, Azure IoT Hub, Dynamics 365, Skype for Business等等，并且这个平台也在Azure上作为服务对外开放了，它就是**Azure Service Fabric**。</br>

**Azure Service Fabric**的知识体系和Kubernetes相似，非常庞杂，今天这篇文章主要是简单介绍一下这个服务，给同学们扩展一下知识边界，仅此而已。</br>

那我们就来快速的的过一下**Azure Service Fabric**有哪些值得我们注意的特性吧。
1. Service Fabric是微软的**容器部署工具(container orchestrator)**，它主要是用来部署管理分布在集群服务器上的微服务。
2. Service Fabric最擅长管理的服务是**Stateful Microservices服务**。我们在第二期Kubernetes班会上知道，Kubernetes一开始最弱的项目就是对Stateful Microservices服务的部署和管理了，这一问题一直到Kuberenetes Statfulset的出现才有所好转。而**Service Fabric**恰恰相反，它的Stateful Microservices的管理是最优秀的，当然Stateless服务它也能管理，只是有点大材小用了。那为啥Service Fabric没有K8s有名呢？我也不知道，谁知道可以留言和大家分享。
3. Service Fabric提供一整套应用程序生命流程的服务，包括CI/CD, 部署，监控，维护，管理。Service Fabric和Azure Pipeline, Jenkins, Octopus Deploy都有非常好的集成。
4. Serivce Fabric集群可以部署在非常多不同的环境里，包括Azure云上或者你自己线下的数据中心，操作系统支持Windows和Linux。