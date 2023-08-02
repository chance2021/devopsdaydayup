# Azure Spring Apps
上一篇介绍了一个特定场景的服务**Azure Static Web App**，这一篇我们来介绍一个特定编程语言的服务**Azure Sprint Apps**。看名字就知道，这个服务是专门针对Java应用的。如果你的应用是使用Spring Boot架构编写的，那么你不需要修改代码，就能直接使用这个服务把你的应用程序部署到Azure上去。在Azure上，它还提供全套应用生命周期管理服务，包括监控，排错，配置管理，服务发现，CICD集成，以及蓝绿部署等等。以下几个重要特征知道一下就好啦

1. 你可以非常高效的把你现有的Spring应用代码直接迁移到Azure上，并且在Azure上可以非常轻松的扩展并监控日常开销

2. 你可以结合Azure的监控服务，比如Azure Monitor, Azure Log Analytics来对你的应用进行监控和日志收集，也可以使用第三方服务，比如New Relic, Data Dog, ELK来监控和收集日志。

3. 它支持市面上大部分CICD相关构建部署服务，比如Azure DevOps, GitHub Action, Jenkins, Terraform, Gradle, Maven等等

4. 它有两种服务等级，一种是**Standard consumption**,还有一种是**Dedicated Plan**。前者是用多少花多少，后者是使用创建好的专门的计算资源来运行你的应用，就是前几篇我们说的App Service Plan。

5. 它还有企业级服务Enterprise plan。这个等级提供了VMWare Tanzu支持的服务，保证你的服务高可用。当然花销也不小。