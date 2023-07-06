# IAM - Managed Identity
在软件开发或者运维管理中， 有一个人人都头疼的问题：**密钥管理**。如何安全的使用密钥，从而让应用软件能正常访问对应服务，这是应用部署需要考虑的第一步。在Azure中就有这么一种特殊的**AAD**，它可以让用户在不知道具体密钥的情况下，就能访问对应服务。这个特殊的AAD就叫**Managed Identity**。在实际Azure的使用过程当中，应用需要链接其他服务之前，第一个需要访问的服务可能就是**Azure Key Vault**, 因为在**Azure Key Vault**里可以存储所有你需要的所有服务密钥信息。所以我们就可以通过**Managed Identity**来连接**Azure Key Vault**, 从而获取其他所有服务需要的密钥。这样的密钥管理就能简单很多。接下来我们来看看**Managed Identity**一些主要特性吧

1. 使用**Managed Identity**后，你就不需要管理任何密钥凭证(**Credential**)。甚至这些密钥凭证你压根就访问不了。
2. 只要对应资源**支持AAD授权登入**，你就能使用Managed Identity登入。
3. Managed Identity是Azure上的**免费**服务。
4. Managed Identity有两类，一类是**System-assigned**，还有一类是**User-assigned**。
5. Azure的一些资源(Resource)支持**System-assigned**，比如虚拟机(Virtual Machine)或App Service。它和对应资源是一对一的关系，生命周期一致（即资源删除后，对应Sysem-assigned managed identity也会被删除)。开启System-assigned managed identity之后，会有一个该资源名字一样的**Service Principal**生成，这个资源就能拿着这个**Service Principal**去访问那些已授权该**Service Principal**的服务。
6. 另一个类型**User-assigned**是一个**独立的Managed Identity**。这个Managed Identity独立于其他资源（Resource)，并且可以被**多个**Resource使用。
7. 打个比方，我们的资源或应用相当于一辆汽车，对应要访问的资源相当于车库门，**System-assigned managed identity**相当于一个内置在我们汽车里的车库门钥匙，只要是这个汽车，就能开车库门，汽车销毁了，这个钥匙也作废了；而**User-assigned managed identity**相当于一个遥控钥匙，任何拥有这把钥匙的汽车，都能开启这个车库门。


# Reference
[Using Managed Identities](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)