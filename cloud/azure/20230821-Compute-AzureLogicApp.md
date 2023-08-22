# Azure Logic App
上一篇我们介绍了需要写最少的代码就能发布程序的**Azure Function**，似乎这个虚拟化已经到了尽头。但是Azure还有一款产品，就算你不会也代码，也能创造一个程序，它就是**Azure Logic App**。</br>

使用**Azure Logic App**的时候，你只需要通过Azure Portal的设计UI，以手动添加和拖拽的方式，就能够设计出一个属于你的程序或工作流。这有点像iPhone的Shortcut，你只要设置好触发事件以及之后的执行动作，就可以设计出一个自动化流程。比如以下场景：
1. 当一个文件上传的时候让Office 365给你发邮件通知。
2. 一旦密钥即将过期，可以自动创建一个Service Now Ticket让人来处理。
3. 重新路由并处理客户的订单从本地到云端的服务。

以下这些名词你需要了解一下：
1. **Workflow**： 这是一系列被定义的执行任务。一般**workflow**是由一个**Trigger**开始，之后执行各种定义好的**Action**.
2. **Trigger**: 这是**Workflow**的第一步，一般由某种事件触发，比如一个新的文件在Storage account里被创建出来。
3. **Action**: **Workflow**里的一系列被定义的任务，这些任务包括发送邮件，创建Service Now ticket，等等。
4. **Connector**: 一个**Connector**其实就代表着一个Operation，它可以是一个Trigger或一个Action，或者一个Trigger加Action的组合。Logica app的Connector有两种，**Build-in** connector 和 **Managed** connector。**Build-in** connector是直接在Azure Logic Apps里运行，效率比较高，但是种类不多；**Managed** connector是在Azure上部署和管理的，他主要是提供了一个代理或者API的Wrapper来帮助Azure Logic 和相关底层服务进行通讯。
5. **Integration Account**: 如果你使用了Azure B2B solutuion，你还可以创建一个Integration Account，它可以帮助你存储和管理B2B的artifacts。这个真没用过，所以也不是非常了解。
6. 对了， Logic app 还分成了两种模式，一种是Consumption还有一种是Standard。 它们的收费方式和使用方式也很不一样，感兴趣的同学可以到官网里看看。

最近我刚好接手一个Project是专门做利用Logic App来监测Azure Key Vault Secret Expiration的，有机会可以做成实验再和大家深入探讨一下。