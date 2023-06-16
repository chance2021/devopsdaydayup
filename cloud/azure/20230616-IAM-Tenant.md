# IAM-Tenant（租户)
1. 今天第一篇文章，本来是打算和大家一起学习**Resource Management (e.g. Management Groups, Subscription, Resource Groups, Resources)**。因为我觉得，登入**Azure Portal**后第一个会遇到的应该就是这些吧。但是我发现，其实还有一个东西会在你遇到它们之前就会遇到的，甚至很多人都不太知道它的存在。这就是**Azure Tenant**。<br>
2. 我第一次接触**Azure Tenan**，是在我使用**Terraform部署AKS**的时候，被要求输入`tenant_id`这个选项([参考这里](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster#tenant_id))。当时我在Azure Portal找了半天才找到对应的**Tenant ID**。
3. 这两天重新再学习**Tenant ID**,又把它和其他名词混了起来，比如**Microsoft Account**, **Orgnization**, **Subscription**。真是傻傻分不清楚。接下来我们来介绍一下到底什么是**Tenant**。
4. 官方解释：一个租户(Tenant)代表一个组织(Organization)。它是组织或应用开发人员在与Microsoft建立关系之初获得的Azure AD的专用实例。([A tenant represents an organization. It's a dedicated instance of Azure AD that an organization or app developer receives at the beginning of a relationship with Microsoft.](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-create-new-tenant))
5. 通俗的说，就是你创建一个**Microsoft Account**的时候，会自动关联一个**Tenant**。一个Microsoft Account可以有**多个**Tenant,每个Tenant对应**一个Azure AD**,并且可以关联**多个Subscriptions**。一个Tenant也代表**一个Orgnization（组织）**。（是不是有点绕？)
6. 无论你是否理解，如果你使用Azure使用的服务多了，你迟早会需要使用Tenant ID。我们只要知道如何找到**Tenant ID**就好了。查找**Tenant ID**的方式是，登入[Azure Portal](https://portal.azure.com/)，然后在**搜索栏**里输入(`Tenant properties`)，这样你就能看到你的Tenant信息了，包括**Name**, **Country or region**, **Notification Language**,还有非常重要的`Tenant ID`。这个`Tenant ID`就是最开始说的Terraform需要用到的信息。
7. 当你创建一个新的Tenant的时候，你就成为这个Tenant里第一个用户(User)。换句话说，你就自动拥有一个至高的管理员权限(**Global Administrator Role**)。一般我们会建议你**再创建一个Global Administrator Role**，以防你的这个AAD被锁了。
8. 一般AAD Tenant都会有一个**起始域名(Domain)**: `<domainname>.onmicrosoft.com`.你无法改变或删除这个起始域名，但是你可以添加你的组织(Organization)名称。
9. 目前我知道的关于Tenant的信息就这些。屏幕前的同学你有什么补充的吗？可以发群里和大家分享一下。
## Reference
- [Quick Start Create New Tenant]https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-create-new-tenant
- [Active Directory Access Create New Tenant]https://learn.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-access-create-new-tenant