# Resource Management
今天我们来介绍一下Microsoft Azure最重要的一个概念：**Resource Management** (资源管理)。如果你想要创建一个资源（比如虚拟机），除了申请一个Micrsoft账号以外，最重要的就是创建**Resource Management**相关**Groups**。
1. 第一个需要创建的**Group**就是**Subscription**。**Azure Subscription**有三类：**Free Trail** (只限首次使用用户，有200CAD credit可以使用，有效期是一年，不过我的账号里的Credit好像一个月就到期了。。)， **Pay-As-You-Go**(用多少花多少)， **Azure for Students** (给学生使用，必须用学生Email注册，有Credit，还有很多免费服务。也不知道Seneca啥时候再免费招生..)。
2. 每个**Subscription**有自己独立的账单，如果你想把账单分开，你必须创建不同的**Subscripition**。
3. 如果你有非常多**Subscription**，你可创建**Management Groups**来管理不同功能的**Subscription**，默认情况下你创建的所有**Subscriptions**都归属于同一个**Root Management Group**。
4. 在每一个**Subscription**下，在你创建具体的资源（比如虚拟机）之前，你需要创建至少一个**Resource Group**。不同的**Subscription**里可以包含多个**Resource Groups**，就好像你在一个文件夹里创建多个文件夹，有Dev"文件夹"(**Resource Group**)，就专门放Dev环境相关的资源；在QA"文件夹”(**Resource Group**)下就专门放QA相关资源。
5. 在计算花销Cost的时候，可以按照不同的**Resource Group**来统计，方便你定位哪些资源块花费最多。
6. 最后你想要创建的资源就可以在指定的**Resource Group**里创建啦。这些资源包括但是不限于：计算资源**Compute** (e.g. Azure App Service, Azure Virtual Machine, Azure Functions, Azure Kubernetes Service, Azure Batch, etc..), 网络资源**Networking**(e.g. Azure Virtual Network, Subnet, Security Group, Pairing, Virtual WAN, ExpressRoute, Azure Traffic Manager, etc..), 存储资源**Storage**(e.g. Azure Storage Account, Azure Blob, Azure Files, Azure Queues, Azure NetApp File, Data Lak Storage, etc..), 数据库**Database**, 消息事件**Message and Events**, **DevOps**, **Monitoring**, **Logging**, etc.. </br>

看到最后的这些资源，同学们是不是已经晕了。不用着急，在未来的6个月里，我们会一个一个慢慢讲，带大家慢慢熟悉Azure家族的绝大部分成员，帮助大家无论是在未来的Azure相关考试还是工作打一个好的基础。那我们下篇见啦！
