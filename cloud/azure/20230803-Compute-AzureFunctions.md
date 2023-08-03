# Azure Functions
今天来讲一个这几天我们小项目在做的实验项目：**Azure Functions**。Azure Functions可以算是我们这几天来讲到的Azure服务中虚拟化最多的服务了，前面几个虽然已经不太需要自己去配置VM了，但是还是需要提前布置好计算资源才能运行。而Azure Functions却是可以做到只要在你需要用到的时候才运行，用完就结束，直到你下次再使用的时候再被激活。它适合的应用场景包括：当有文件上传到Blob Storage的时候你需要运行程序，捕捉并且转化事件流，以及定时跑一些清理代码程序，等等。总的说，它就是一个靠**事件驱动(event-driven)的程序代码片段**，什么时候要用，什么时候才被激活。以下是你需要知道的它的一些特点：
1. 它是一整套**无服务解决方案(serverless solution)**，帮助你可以更专心在你的业务代码上，不用担心任何基础架构，更重要的是它用多少花多少的特性让你更加省钱。
2. 它支持基本上所有主流的语言，包括C#, Java, JavaScript, PowerSHell, Python,以及Rust和Go.
3. 它分为6个等级：Consumption plan, Premium plan, Dedicated plan, App Service Environment (ASE), Azure Container Apps和Kuberetes (Direct or Azure Arc)
4. **Consumption plan**: 这个等级就是前面提到的用多少花多少的等级。这个算是初级，省钱确实省，但是这两天弄实验的时候发现了很多局限，其中一个就是它的部署方式只支持Zip包发布，其他形式的发布都不支持。坑比较多，要小心。
5. **Premium plan**: 上面的Consumption plan还有一个很大的缺点，就是它冷启动慢，也就是你每次使用的时候需要等很长时间(5分钟左右)才能运行你的代码。Premium plan弥补了这个缺点，它帮你提前**预热**好了程序运行环境，不要等太久，就能得到反应。当然，代价就是贵一点。
6. **Dedicated plan**: 这个等级是让你的Function运行在**App Service Plan**的环境里。如果你已经有了App Service Plan,并且还有剩余的计算资源，建议选择这个等级。
7. **App Service Environment**: 这个就是高级版的App Service Plan,不仅享有独有的计算资源，还能拥有一个隔离的网络环境。如果你在乎安全，那就选这个吧。
8. **Azure Container Apps**:如果你已经创建了Azure Container Apps,那你还可以把你的Function部署到Azure Container App上运行。
9. **Kubernetes**: 如果你已经创建Kubernete,无论是Azure Kubernetes Service，还是你自己On-premise Kuberenetes,你都可以把你的Function部署到Kubernetes集群上。