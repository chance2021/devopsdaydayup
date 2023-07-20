# Azure Virtual Machine
终于到了Azure Compute环节了。Azure的计算资源应该是我们大部分同学使用的最多的资源，今天我们就来一起学习一下计算资源里最常见的资源：**Azure Virtual Machine**。当你需要对你的计算环境有绝对的掌控，但是你又不想花很高的价格去买一台物理计算机的话，那**Azure Virtual Machine**就是你很好的选择。在创建**Azure Virtual Machine**的时候，你需要考虑这几个方面的信息：
1. 使用**Azure Virtual Machine**的应用的名字
2. 你的**Azure Virtual Machine**需要创建在哪个**Location**
3. 你的**Azure Virtual Machine**的性能大小（比如多少个CPU core，多少大的内存）
4. 需要多少台**Azure Virtual Machine**
5. 什么操作系统，是Windows还是Linux
6. 创建好的系统里需要安装什么应用吗
7. 这台**Azure Virtual Machine**可能需要连到外面的什么资源吗，比如网络，数据库等

刚才第2点讲到你需要考虑什么地点（**Location**）存放你的VM,这里其实指的是**Azure Virtual Machine**存放数据的Hard Disks需要创建到哪里，你可以到官网去找离你或你客户最近的地点，或者可以通过PowerShell或Azure CLI也能查询的到。</br>

关于**Azure Virtual Machine**，有两个选项你需要知道：
1. **Availability Zones**指的是在同一个地区**Region**里，分别在不同的数据中心的多个地点。数据中心不同，那么它的网络、存储啥的的物理地点也就不一样。这样就可以防止一个数据中心被毁坏后对业务的影响。
2. **Virtual Machine Scale Sets**指的是你创建了多台VM，然后通过负载均衡（**Load Balancer**）来分配流量，从而做到横向拓展你的计算能力。

另外，你得知道每个Subscription是有默认的VM数量上限的，一般每个**Region**是20个VM,如果你想创建更多**VM**，你需要写Ticket申请。</br>

最后，我们来说说**Azure Virtual Machine**不同系列之间的差别吧。
1. **A-series**：A系列的VM主要是针对入门或个人测试使用的，它的特点是功能弱但是便宜。如果你只是想做一个自己的开发或小流量的网站，你可以选择它。不过这个系列2024年8月份就停产了。且用且珍惜吧
2. **Bs-series**:Bs系列和A系列差不多，也是主打便宜性能低，不过它比起A系列，还有一个特点，就是当CPU使用量过高时，它可以在很短的时间内扩大CPU的利用率，防止你的系统因为CPU使用量过载而崩溃。所以它可以承担一些稍微高一点的计算量。
3. **D-series**:D系列属于**General purpose**通用机型，如果说前两个系列针对的是个人或小型企业，那这个系列针对的就是中型有时候甚至稍微大型一点的企业了，或者一些中型的数据库或者游戏服务器都可以使用这个系列的VM。
4. **E-series**:E系列在内存Memory上比较突出，它针对的是那些需要使用大量内存的应用，比如SAP HANA。
5. **F-series**:而F系列主要是属于CPU优先的应用服务场景，比如一些Batch processing, analytics 和 Gaming的服务器。
6. **G-series**:G系列是在E系列的基础之上，还对存储**Storage**也做了优化，主要是存储都是用的SSD。
7. **H-series**:H系列主要是给HPC(High Performanace Computing)使用的，主要场景包括fluid dynamics, finite element analysis, seismic processing, reservoir simulation, risk analysis, electronic design automation, rendering, Spark, weather modelling, quantum simulation, computational chemistry, heat transfer 
8. **Ls-series**:Ls系列优化了存储，它主要是给那些大型数据库使用的，比如 Cassandra, MongoDB, Cloudera and Redis。
9. **M-series**:如果E系列不够你用过得话， 那你可以考虑M系列，这个系列的内存Memory一定够你挥霍了
10. **Mv2-series**:如果M系列还不够，那就Mv2系列吧，这是Azure家族里内存最大的系列了，再大就没有了
11. **N-series**:N系列主要针对的是GPU消耗型应用场景，比如我们最近新鲜事里经常提起的AI相关使用，比如deep learning, graphics rendering, video editing, gaming and remote visualisation。

最后的最后，我们来说一下这些VM序列号的命名规则，方便大家从名字中就能识别一些关于这个型号VM的一些性能信息。Azure VM型号命名规则是：`[Family Series] + [Sub-family]* + [# of vCPUs] + [Constrained vCPUs]* + [Additive Features] + [Accelerator Type]* + [Version]`。举个例子吧，比如`M416ms_v2`, `M`指的是M系列，也就是上面说的内存优先系列，如果它针对的是内存需求多的场景，`416`是vCPU的个数，`m`指的是`memory intensive`内存多，`s`指的是`Premium Storage capable`，也就是SSD的硬盘, `v2`是version 2，第2版。再比如，`NV16as_v4`，`N`是指N系列，也就是针对GPU的，`V`是子系列，`4`代表4个vCPU，`a`代表`AMD-based processor`，也就是AMD芯片，那`s`和上面一样，是SSD的意思，`v4`当然就是第四版本啦。现在你会读了吗？



关于**Azure Virtual Machine**，你需要了解的就这些。如果还有什么你觉的很重要的就留言告诉我，我会再补充进去和大家分享！

# Reference
[VM Naming Convention](https://learn.microsoft.com/en-us/azure/virtual-machines/vm-naming-conventions)